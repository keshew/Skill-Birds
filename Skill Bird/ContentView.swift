import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showSplash = true

    var body: some View {
        ZStack {
            PremiumBackground()
            if showSplash {
                SplashView().transition(.opacity)
            } else if appState.needsOnboarding {
                OnboardingView().transition(.opacity)
            } else {
                MainTabView().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showSplash)
        .animation(.easeInOut(duration: 0.35), value: appState.needsOnboarding)
        .task {
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            showSplash = false
        }
    }
}

struct SplashView: View {
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(SBColor.gold.opacity(0.08)).frame(width: 148, height: 148)
                Circle().stroke(SBColor.gold.opacity(0.28), style: StrokeStyle(lineWidth: 0.8, dash: [3, 7])).frame(width: 132, height: 132).rotationEffect(.degrees(appeared ? 20 : 0))
                Circle().stroke(LinearGradient(colors: [SBColor.sky.opacity(0.1), SBColor.gold.opacity(0.6), SBColor.sky.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1).frame(width: 102, height: 102)
                Image(systemName: "bird.fill")
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [.white, SBColor.champagne, SBColor.gold], startPoint: .top, endPoint: .bottom))
                    .shadow(color: SBColor.gold.opacity(0.5), radius: 18)
                    .rotationEffect(.degrees(appeared ? 0 : -12))
                    .offset(y: appeared ? 0 : 20)
            }
            OrnamentalDivider().frame(width: 150)
            Text("SKILL BIRD").font(.system(size: 29, weight: .semibold, design: .serif)).tracking(3)
            Text("Learn. Grow. Fly.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(SBColor.secondaryText)
        }
        .foregroundStyle(SBColor.text)
        .scaleEffect(appeared ? 1 : 0.92)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) { appeared = true }
        }
    }
}
