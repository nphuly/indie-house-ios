import AVFoundation
import Foundation
import UniformTypeIdentifiers

/// Supplies AVPlayer with byte ranges from the authenticated stream gateway.
final class AuthenticatedAudioLoader: NSObject, AVAssetResourceLoaderDelegate {
    private let track: Track
    private let quality: String
    private let api: IndieAPI
    private let initialChunk: IndieAPI.StreamChunk
    private let onError: @MainActor (Error) -> Void
    private var tasks: [ObjectIdentifier: Task<Void, Never>] = [:]

    init(track: Track, quality: String, api: IndieAPI, initialChunk: IndieAPI.StreamChunk,
         onError: @escaping @MainActor (Error) -> Void) {
        self.track = track
        self.quality = quality
        self.api = api
        self.initialChunk = initialChunk
        self.onError = onError
    }

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard loadingRequest.request.url?.scheme == "indiehouse-stream" else { return false }
        let key = ObjectIdentifier(loadingRequest)
        tasks[key] = Task { @MainActor [weak self] in
            await self?.serve(loadingRequest)
        }
        return true
    }

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                        didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        let key = ObjectIdentifier(loadingRequest)
        tasks.removeValue(forKey: key)?.cancel()
    }

    @MainActor private func serve(_ request: AVAssetResourceLoadingRequest) async {
        defer { tasks.removeValue(forKey: ObjectIdentifier(request)) }
        do {
            let dataRequest = request.dataRequest
            var offset = max(dataRequest?.requestedOffset ?? 0, dataRequest?.currentOffset ?? 0)
            let requestedEnd = dataRequest.map { $0.requestedOffset + Int64($0.requestedLength) } ?? 1
            let total = initialChunk.totalLength

            if let information = request.contentInformationRequest {
                information.contentType = initialChunk.contentType == "audio/flac"
                    ? (UTType(filenameExtension: "flac")?.identifier ?? "org.xiph.flac")
                    : AVFileType.mp3.rawValue
                information.contentLength = total
                information.isByteRangeAccessSupported = true
            }

            guard let dataRequest else {
                request.finishLoading()
                return
            }

            while offset < total &&
                    (dataRequest.requestsAllDataToEndOfResource || offset < requestedEnd) {
                try Task.checkCancellation()
                if offset < Int64(initialChunk.data.count) {
                    let available = min(Int64(initialChunk.data.count) - offset,
                                        dataRequest.requestsAllDataToEndOfResource ? Int64.max : requestedEnd - offset)
                    if available > 0 {
                        let start = Int(offset)
                        dataRequest.respond(with: initialChunk.data.subdata(in: start..<(start + Int(available))))
                        offset += available
                        continue
                    }
                }
                let remaining = dataRequest.requestsAllDataToEndOfResource ? 512 * 1024 :
                    max(1, Int(min(512 * 1024, requestedEnd - offset)))
                let chunk = try await api.streamChunk(for: track, quality: quality,
                                                       from: offset, length: remaining)
                guard chunk.totalLength == total else {
                    throw IndieError.message(L("error.audio_length"))
                }
                dataRequest.respond(with: chunk.data)
                offset += Int64(chunk.data.count)
            }

            if !Task.isCancelled { request.finishLoading() }
        } catch {
            if !Task.isCancelled {
                onError(error)
                request.finishLoading(with: error)
            }
        }
    }
}
