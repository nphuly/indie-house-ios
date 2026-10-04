import SwiftUI

struct StartupView: View {
    let problem: String?
    let retry: () -> Void
    let change: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Image("BrandMark").resizable().scaledToFit().frame(width: 76, height: 76).accessibilityHidden(true)
            Text("INDIE HOUSE").font(.ih(.bold, 24)).tracking(2.4).padding(.top, 14)
            if let problem {
                Icon("signal", size: 24)
                    .foregroundStyle(Theme.danger)
                    .frame(width: 52, height: 52)
                    .background(CutShape().fill(Theme.dangerWash))
                    .padding(.top, 32)
                Text(L("startup.failed")).font(.ih(.bold, 18)).padding(.top, 14)
                Text(problem)
                    .font(.ih(.regular, 14))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
                PillButton(title: L("common.retry"), action: retry).padding(.top, 24)
                PillButton(title: L("library.change"), kind: .ghost, action: change).padding(.top, 8)
            } else {
                ProgressView().tint(Theme.accent).controlSize(.large).padding(.top, 28)
                Text(L("startup.opening")).font(.ih(.regular, 14)).foregroundStyle(Theme.muted).padding(.top, 12)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: 420)
    }
}
