import SwiftUI
import UIKit
import zlib

/// "Biển hiệu" design tokens, shared with the web (`--ih-*` in
/// indie-house-server/src/control-plane/resources/css/app.css) and the Leap (`Theme.java`).
/// See indie-house-server/docs/en/design-system.md.
enum Theme {
    static let bg = Color(hex: 0x07090E)
    static let surface = Color(hex: 0x0E1118)
    static let raised = Color(hex: 0x151A25)
    static let hover = Color(hex: 0x1D2432)
    static let field = Color(hex: 0x0B0E14)
    static let text = Color(hex: 0xEEF1F6)
    static let soft = Color(hex: 0xBCC3D0)
    static let muted = Color(hex: 0x858EA0)
    static let faint = Color(hex: 0x566074)
    /// Sign yellow: play, progress, the current item and selected state only.
    static let accent = Color(hex: 0xF7E23B)
    static let accentBright = Color(hex: 0xFFF07A)
    static let ink = Color(hex: 0x0A0B0F)
    /// Karaoke pink: the account avatar and the "Most played" tag.
    static let pink = Color(hex: 0xFF3D81)
    static let cyan = Color(hex: 0x27E3EC)
    static let danger = Color(hex: 0xFF5A4F)
    static let line = text.opacity(0.12)
    static let lineSoft = text.opacity(0.07)
    static let pressed = text.opacity(0.08)
    static let accentWash = accent.opacity(0.14)
    static let dangerWash = danger.opacity(0.16)
    static let scrim = Color(hex: 0x030408).opacity(0.7)

    /// Blocks stay nearly square; the old 8–14 radii are capped like the Leap does.
    static let radius: CGFloat = 3

    // MARK: Placeholder tones

    /// `{accent, base}` pairs, picked by `crc32(seed) % 6` as on the web and the Leap.
    private static let tones: [(accent: UInt32, base: UInt32)] = [
        (0xF7E23B, 0x23200A), (0xFF3D81, 0x2C0F1C), (0x27E3EC, 0x0A2628),
        (0x9D7CFF, 0x1D1638), (0xFF8A3D, 0x2C170A), (0x5B8CFF, 0x0E1A33),
    ]

    static func tone(_ seed: String?) -> Int {
        let bytes = Array((seed ?? "indie-house").utf8)
        let value = bytes.withUnsafeBufferPointer { crc32(0, $0.baseAddress, uInt($0.count)) }
        return Int(value % UInt(tones.count))
    }

    static func toneAccent(_ tone: Int) -> RGB { RGB(hex: tones[tone].accent) }
    static func toneBase(_ tone: Int) -> RGB { RGB(hex: tones[tone].base) }

    /// The tint a placeholder gives the page before its artwork arrives.
    static func ambient(tone: Int) -> Color { toneBase(tone).mix(toneAccent(tone), 0.18).color }

    /// A dark tint taken from artwork: the average colour, saturation ≤ 0.55,
    /// value clamped to 0.28–0.38.
    static func ambient(of image: UIImage) -> Color {
        AmbientCache.shared.color(for: image)
    }
}

/// Plain RGB values for the colour maths that `Color` does not offer.
struct RGB: Equatable {
    var r: Double, g: Double, b: Double

    init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }
    init(hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }

    var color: Color { Color(red: r, green: g, blue: b) }

    func mix(_ other: RGB, _ amount: Double) -> RGB {
        RGB(r: r + (other.r - r) * amount, g: g + (other.g - g) * amount, b: b + (other.b - b) * amount)
    }
}

extension Color {
    init(hex: UInt32) { self = RGB(hex: hex).color }
}

private final class AmbientCache {
    static let shared = AmbientCache()
    private let cache = NSCache<UIImage, UIColor>()
    private let context = CIContext(options: [.workingColorSpace: NSNull()])

    func color(for image: UIImage) -> Color {
        if let cached = cache.object(forKey: image) { return Color(uiColor: cached) }
        var result = UIColor(Theme.bg)
        if let input = CIImage(image: image),
           let filter = CIFilter(name: "CIAreaAverage",
                                 parameters: [kCIInputImageKey: input,
                                              kCIInputExtentKey: CIVector(cgRect: input.extent)]),
           let output = filter.outputImage {
            var pixel = [UInt8](repeating: 0, count: 4)
            context.render(output, toBitmap: &pixel, rowBytes: 4,
                           bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
            let average = UIColor(red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255,
                                  blue: CGFloat(pixel[2]) / 255, alpha: 1)
            var hue: CGFloat = 0, saturation: CGFloat = 0, value: CGFloat = 0, alpha: CGFloat = 0
            average.getHue(&hue, saturation: &saturation, brightness: &value, alpha: &alpha)
            result = UIColor(hue: hue, saturation: min(saturation, 0.55),
                             brightness: min(max(value, 0.28), 0.38), alpha: 1)
        }
        cache.setObject(result, forKey: image)
        return Color(uiColor: result)
    }
}

extension RGB {
    static func of(_ color: Color) -> RGB {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return RGB(r: Double(r), g: Double(g), b: Double(b))
    }
}
