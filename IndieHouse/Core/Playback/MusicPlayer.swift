import AVFoundation
import MediaPlayer
import Network
import SwiftUI

enum RepeatMode: Int {
    case off, all, one
}

/// Position and length, published apart from the player state so rows and
/// pages do not redraw twice a second.
@MainActor final class PlaybackClock: ObservableObject {
    @Published fileprivate(set) var position: Double = 0
    @Published fileprivate(set) var duration: Double = 0

    var fraction: Double { duration > 0 ? min(1, max(0, position / duration)) : 0 }
}

/// Playback queue around AVPlayer with the web player's rules
/// (indie-house-server/docs/en/design-system.md, "Player behaviour"): the queue is the
/// whole list a song was started from, shuffle reorders what is left, repeat
/// cycles off/all/one, and one listen is logged per playback once it passes
/// ten seconds or ends.
@MainActor final class MusicPlayer: ObservableObject {
    @Published private(set) var queue: [Track] = []
    @Published private(set) var index = -1
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoading = false
    @Published private(set) var failed = false
    @Published private(set) var shuffle: Bool
    @Published private(set) var repeatMode: RepeatMode
    @Published private(set) var contextId: String?
    @Published private(set) var contextLabel: String?
    let clock = PlaybackClock()

    var autoplay = true
    var recordHistory = true
    var quality = "auto"
    /// "FLAC" or "MP3": what the current song streams as.
    @Published private(set) var format = "MP3"
    /// Shown as a toast when a song cannot play.
    var onError: ((String) -> Void)?

    var current: Track? { queue.indices.contains(index) ? queue[index] : nil }
    var hasNext: Bool { current != nil && (index + 1 < queue.count || repeatMode == .all) }

    private let player = AVPlayer()
    private var source: [Track] = []
    private var api: IndieAPI?
    private var playbackID = UUID().uuidString
    private var logged = false
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var failedObserver: NSObjectProtocol?
    private var statusObserver: NSKeyValueObservation?
    private var rateObserver: NSKeyValueObservation?
    private var audioLoader: AuthenticatedAudioLoader?
    private var loadRevision = UUID()
    private var artwork: MPMediaItemArtwork?
    /// Where a failed song stopped; trying it again carries on from there.
    private var resumePoint: Double?
    /// Set while a resumed song loads; it starts playing once it has sought here.
    private var pendingSeek: Double?
    /// A song that failed while playing starts again by itself when the network comes back.
    private var resumeWhenOnline = false
    private let pathMonitor = NWPathMonitor()
    /// AVPlayer failed to play a FLAC this session, so lossless plays 320 kbps.
    private var flacFailed = false
    private var loaderFailed = false

    private var streamQuality: String { quality == "lossless" && flacFailed ? "high" : quality }

    init() {
        let defaults = UserDefaults.standard
        shuffle = defaults.bool(forKey: "player.shuffle")
        repeatMode = RepeatMode(rawValue: defaults.integer(forKey: "player.repeat")) ?? .off
        do { try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default) } catch { }
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor [weak self] in self?.networkReturned() }
        }
        pathMonitor.start(queue: .main)
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
                                                      queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in self?.tick(time) }
        }
        rateObserver = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            let status = player.timeControlStatus
            Task { @MainActor [weak self] in self?.statusChanged(status) }
        }
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in if self?.isPlaying == false { self?.toggle() } }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in if self?.isPlaying == true { self?.toggle() } }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.toggle() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.next() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.previous() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor [weak self] in self?.seek(to: event.positionTime) }
            return .success
        }
    }

    // MARK: Queue

    /// Starts a list from one song. `shuffled` turns shuffle on and picks a random start, like the shuffle button.
    func start(_ tracks: [Track], at startIndex: Int, context: String?, label: String?,
               shuffled: Bool = false, using api: IndieAPI) {
        guard !tracks.isEmpty else { return }
        self.api = api
        source = tracks
        contextId = context
        contextLabel = label
        var first = min(max(0, startIndex), tracks.count - 1)
        if shuffled {
            setShuffleFlag(true)
            first = Int.random(in: tracks.indices)
        }
        arrange(around: tracks[first])
        play(at: index)
    }

    /// Pauses or resumes; after a failure it tries the same song again from where it stopped. Ignored while loading.
    func toggle() {
        guard current != nil, !isLoading else { return }
        if failed || player.currentItem == nil { play(at: index, resumingAt: resumePoint); return }
        if isPlaying { player.pause() } else {
            // A song left at its end (repeat off) starts again.
            if clock.duration > 0 && clock.position >= clock.duration - 0.5 {
                playbackID = UUID().uuidString
                logged = false
                player.seek(to: .zero)
            }
            player.play()
        }
        isPlaying.toggle()
        updateNowPlaying()
    }

    func next() { advance() }

    /// Past three seconds, or on the first song without repeat-all, goes back to the start.
    func previous() {
        guard current != nil else { return }
        if clock.position > 3 || (index == 0 && repeatMode != .all) {
            seek(to: 0)
            return
        }
        play(at: index > 0 ? index - 1 : queue.count - 1)
    }

    func jump(to queueIndex: Int) {
        guard queue.indices.contains(queueIndex) else { return }
        play(at: queueIndex)
    }

    func seek(to seconds: Double) {
        guard seconds.isFinite, player.currentItem != nil else { return }
        let target = max(0, min(seconds, clock.duration))
        clock.position = target
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        updateNowPlaying()
    }

    /// On: keeps the current song first and shuffles the rest. Off: back to the original order.
    func setShuffle(_ value: Bool) {
        setShuffleFlag(value)
        if let playing = current { arrange(around: playing) }
    }

    func cycleRepeat() {
        repeatMode = RepeatMode(rawValue: (repeatMode.rawValue + 1) % 3) ?? .off
        UserDefaults.standard.set(repeatMode.rawValue, forKey: "player.repeat")
    }

    /// Queues a song right after the current one, or plays it now under "Queue".
    func playNext(_ track: Track, using api: IndieAPI) {
        guard current != nil else {
            start([track], at: 0, context: nil, label: L("player.queue"), using: api)
            return
        }
        queue.insert(track, at: index + 1)
        let at = source.firstIndex(of: queue[index]).map { $0 + 1 } ?? source.count
        source.insert(track, at: at)
    }

    func stop() {
        record(completed: false)
        loadRevision = UUID()
        player.pause()
        player.replaceCurrentItem(with: nil)
        clearObservers()
        queue = []
        source = []
        index = -1
        contextId = nil
        contextLabel = nil
        isPlaying = false
        isLoading = false
        failed = false
        clock.position = 0
        clock.duration = 0
        artwork = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    /// Lock Screen artwork for the current song.
    func setArtwork(_ image: UIImage, for trackId: String) {
        guard current?.id == trackId else { return }
        artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        updateNowPlaying()
    }

    private func setShuffleFlag(_ value: Bool) {
        shuffle = value
        UserDefaults.standard.set(value, forKey: "player.shuffle")
    }

    private func arrange(around first: Track) {
        if shuffle {
            var rest = source
            if let at = rest.firstIndex(of: first) { rest.remove(at: at) }
            queue = [first] + rest.shuffled()
            index = 0
        } else {
            queue = source
            index = max(0, source.firstIndex(of: first) ?? 0)
        }
    }

    /// At the end of the queue the last song stays loaded unless repeat-all wraps around.
    private func advance() {
        guard current != nil else { return }
        if index + 1 < queue.count {
            play(at: index + 1)
        } else if repeatMode == .all {
            if shuffle, let pick = queue.randomElement() { arrange(around: pick) } else { index = 0 }
            play(at: index)
        }
    }

    // MARK: Loading

    /// `start` picks a failed song up where it stopped. That is still the same listen, so it
    /// keeps its playback ID and history state.
    private func play(at position: Int, resumingAt start: Double? = nil) {
        if start == nil { record(completed: false) }
        index = position
        guard let track = current, let api else { return }
        if start == nil {
            playbackID = UUID().uuidString
            logged = false
            artwork = nil
        }
        pendingSeek = start
        resumePoint = nil
        resumeWhenOnline = false
        clock.position = start ?? 0
        clock.duration = Double(track.durationSeconds ?? 0)
        player.pause()
        player.replaceCurrentItem(with: nil)
        clearObservers()
        isPlaying = false
        isLoading = true
        failed = false
        let revision = UUID()
        loadRevision = revision
        updateNowPlaying()
        Task { await load(track, using: api, revision: revision) }
    }

    private func load(_ track: Track, using api: IndieAPI, revision: UUID) async {
        let initialChunk: IndieAPI.StreamChunk
        do {
            initialChunk = try await api.streamChunk(for: track, quality: streamQuality, from: 0, length: 64 * 1024)
        } catch {
            if loadRevision == revision { fail() }
            return
        }
        guard loadRevision == revision else { return }
        let flac = initialChunk.contentType == "audio/flac"
        format = flac ? "FLAC" : "MP3"
        loaderFailed = false
        let asset = AVURLAsset(url: URL(string: "indiehouse-stream://audio/\(track.id).\(flac ? "flac" : "mp3")")!)
        let loader = AuthenticatedAudioLoader(track: track, quality: streamQuality, api: api,
                                              initialChunk: initialChunk) { [weak self] _ in
            guard let self, self.loadRevision == revision else { return }
            self.loaderFailed = true
            self.fail()
        }
        audioLoader = loader
        asset.resourceLoader.setDelegate(loader, queue: .main)
        let item = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: item)
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                                              object: item, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.loadRevision == revision else { return }
                self.finished()
            }
        }
        failedObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime,
                                                                 object: item, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.loadRevision == revision else { return }
                self.fail()
            }
        }
        // `.initial` too: a resumed song waits for readyToPlay before it plays, so it must not be missed.
        statusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            let status = item.status
            Task { @MainActor [weak self] in
                guard let self, self.loadRevision == revision else { return }
                if status == .failed {
                    // The bytes arrived but AVPlayer could not decode them.
                    if flac && !self.loaderFailed { self.fallBackFromLossless() } else { self.fail() }
                }
                else if status == .readyToPlay {
                    self.isLoading = false
                    self.seekToResumePoint()
                }
            }
        }
        if pendingSeek == nil { player.play() }
        isPlaying = true
        updateNowPlaying()
    }

    /// A resumed song starts only after the seek, so it does not play a moment from the start.
    private func seekToResumePoint() {
        guard let target = pendingSeek else { return }
        pendingSeek = nil
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600)) { [weak self] _ in
            Task { @MainActor [weak self] in
                // The listener may have paused while it sought.
                guard let self, self.isPlaying else { return }
                self.player.play()
            }
        }
    }

    /// The FLAC would not play: this session streams 320 kbps instead and says so once.
    private func fallBackFromLossless() {
        flacFailed = true
        onError?(L("player.lossless_unsupported"))
        play(at: index, resumingAt: clock.position >= 1 ? clock.position : nil)
    }

    private func networkReturned() {
        guard failed, resumeWhenOnline else { return }
        toggle()
    }

    private func finished() {
        record(completed: true)
        switch repeatMode {
        case .one:
            // A repeat is a new listen.
            playbackID = UUID().uuidString
            logged = false
            player.seek(to: .zero)
            player.play()
        case .all:
            advance()
        case .off:
            if autoplay && index + 1 < queue.count { advance() } else {
                player.pause()
                isPlaying = false
                updateNowPlaying()
            }
        }
    }

    private func fail() {
        guard !failed else { return }
        resumePoint = clock.position >= 1 ? clock.position : nil
        resumeWhenOnline = isPlaying || isLoading
        pendingSeek = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        clearObservers()
        isLoading = false
        isPlaying = false
        failed = true
        updateNowPlaying()
        onError?(L("player.failed_network"))
    }

    private func tick(_ time: CMTime) {
        guard current != nil else { return }
        let seconds = max(0, time.seconds.isFinite ? time.seconds : 0)
        if player.currentItem != nil { clock.position = seconds }
        let length = player.currentItem?.duration.seconds ?? 0
        let duration = length.isFinite && length > 0 ? length : Double(current?.durationSeconds ?? 0)
        if clock.duration != duration { clock.duration = duration }
        updateNowPlaying()
    }

    private func statusChanged(_ status: AVPlayer.TimeControlStatus) {
        guard player.currentItem != nil else { return }
        if status == .playing {
            if isLoading { isLoading = false }
            if !isPlaying { isPlaying = true }
        } else if status == .paused, isPlaying, !isLoading {
            // Paused by the system, e.g. an interruption.
            isPlaying = false
        }
    }

    /// One log per playback, after ten seconds or at the end. History is best effort.
    private func record(completed: Bool) {
        guard let track = current, let api, !logged, recordHistory else { return }
        let seconds = completed ? max(1, Int(clock.duration)) : Int(clock.position)
        guard seconds >= (completed ? 1 : 10) else { return }
        logged = true
        let body: [String: Any] = ["track_id": track.id, "played_duration_seconds": seconds,
                                   "completed": completed, "playback_id": playbackID]
        Task { try? await api.post("play-logs", body: body) }
    }

    private func updateNowPlaying() {
        guard let current else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: current.displayTitle,
            MPMediaItemPropertyArtist: current.artistName,
            MPMediaItemPropertyPlaybackDuration: clock.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: clock.position,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if let album = current.firstAlbum?.title { info[MPMediaItemPropertyAlbumTitle] = album }
        if let artwork { info[MPMediaItemPropertyArtwork] = artwork }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        let center = MPRemoteCommandCenter.shared()
        center.nextTrackCommand.isEnabled = hasNext
    }

    private func clearObservers() {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let failedObserver { NotificationCenter.default.removeObserver(failedObserver) }
        endObserver = nil
        failedObserver = nil
        statusObserver = nil
        audioLoader = nil
    }
}
