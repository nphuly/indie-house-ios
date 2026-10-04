import SwiftUI

/// Artwork frame: square with the top-right corner cut (14% of the side, at most 18).
struct ArtShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = min(rect.width * 0.14, 18)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - c, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + c))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Artists and the account avatar: an octagon cut 22% of the side.
struct OctagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = min(rect.width, rect.height) * 0.22
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + c, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - c, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + c))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - c))
        path.addLine(to: CGPoint(x: rect.maxX - c, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + c, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - c))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + c))
        path.closeSubpath()
        return path
    }
}

/// Play buttons, pills and empty-state badges: top-right and bottom-left corners cut.
/// `fixed` sets the cut in points (pills: 9); otherwise it is 28% of the shorter side.
struct CutShape: InsettableShape {
    var fixed: CGFloat?
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: inset, dy: inset)
        let side = min(rect.width, rect.height)
        let c = fixed.map { min($0, side / 2) } ?? side * 0.28
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - c, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + c))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + c, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - c))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> CutShape { CutShape(fixed: fixed, inset: inset + amount) }
}

struct Block: InsettableShape {
    var inset: CGFloat = 0
    func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: Theme.radius).path(in: rect.insetBy(dx: inset, dy: inset))
    }
    func inset(by amount: CGFloat) -> Block { Block(inset: inset + amount) }
}
