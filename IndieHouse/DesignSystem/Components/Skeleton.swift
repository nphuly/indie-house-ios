import SwiftUI

struct SkeletonBlock: View {
    var width: CGFloat? = nil
    let height: CGFloat
    @State private var dim = false

    var body: some View {
        Block()
            .fill(Theme.raised)
            .frame(width: width, height: height)
            .opacity(dim ? 0.45 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { dim = true }
            }
    }
}

struct SkeletonRows: View {
    var count = 6

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { index in
                HStack(spacing: 12) {
                    SkeletonBlock(width: 46, height: 46)
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock(width: CGFloat(150 - index % 3 * 24), height: 12)
                        SkeletonBlock(width: CGFloat(96 - index % 2 * 20), height: 10)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
            }
        }
        .accessibilityHidden(true)
    }
}

/// First load of a page: the shape of a first page or of a detail page, then six rows.
struct PageSkeleton: View {
    var detail = false

    var body: some View {
        VStack(alignment: detail ? .center : .leading, spacing: 0) {
            if detail {
                SkeletonBlock(width: 184, height: 184)
                SkeletonBlock(width: 80, height: 12).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 20)
                SkeletonBlock(width: 220, height: 30).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 10)
            } else {
                SkeletonBlock(width: 120, height: 12)
                SkeletonBlock(width: 240, height: 30).padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        SkeletonRows().padding(.top, 24)
    }
}
