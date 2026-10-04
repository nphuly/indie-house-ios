import Foundation

enum Format {
    /// `3:07`
    static func clock(_ seconds: Double) -> String {
        let value = Int(max(0, seconds.isFinite ? seconds : 0))
        return String(format: "%d:%02d", value / 60, value % 60)
    }

    /// "45 giây", "32 phút", "1 giờ 4 phút".
    static func length(_ seconds: Int) -> String {
        if seconds < 60 { return L("duration.seconds", seconds) }
        let minutes = (seconds + 30) / 60
        if minutes < 60 { return L("duration.minutes", minutes) }
        return L("duration.hours_minutes", minutes / 60, minutes % 60)
    }

    /// "vừa xong", "5 phút trước"…; from 30 days on, `dd/MM/yyyy`.
    static func relative(_ iso: String?) -> String {
        guard let iso, let date = parse(iso) else { return L("time.unknown") }
        let minutes = Int(Date().timeIntervalSince(date) / 60)
        if minutes < 1 { return L("time.now") }
        if minutes < 60 { return plural("time.minutes", minutes) }
        if minutes < 60 * 24 { return plural("time.hours", minutes / 60) }
        if minutes < 60 * 24 * 30 { return plural("time.days", minutes / (60 * 24)) }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }

    private static func parse(_ iso: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: iso) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: iso)
    }

    /// Accent- and case-insensitive text for matching, with `đ` as `d`.
    static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "đ", with: "d").replacingOccurrences(of: "Đ", with: "d").lowercased()
    }
}
