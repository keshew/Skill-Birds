import SwiftUI

struct CompletionSequenceView: View {
    @EnvironmentObject private var appState: AppState
    let skill: Skill
    let challenge: Challenge
    let nextChallenge: Challenge?
    let earnedXP: Int
    let didLevelUp: Bool
    let unlockedBird: Bird?
    let journeyCompleted: Bool
    let animate: Bool
    let close: () -> Void

    @State private var xpFlying = false
    @State private var birdHappy = false
    @State private var birdFlying = false
    @State private var nextRevealed = false
    @State private var summaryVisible = false
    @State private var unlockVisible = false
    @State private var sequenceStarted = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                PremiumBackground()
                Image("Background_RewardVault").resizable().scaledToFill().opacity(0.2).ignoresSafeArea()
                world(in: geometry.size)
                xpHeader
                    .position(x: geometry.size.width / 2, y: 38)

                if summaryVisible {
                    summary
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.horizontal, 22)
                        .padding(.bottom, 22)
                }

                if unlockVisible, let unlockedBird {
                    BirdUnlockOverlay(previousBird: appState.equippedBird, bird: unlockedBird) {
                        appState.equip(unlockedBird)
                        close()
                    } later: {
                        withAnimation(.easeInOut(duration: 0.35)) { unlockVisible = false }
                    }
                    .transition(.opacity)
                    .zIndex(20)
                }
            }
            .clipped()
        }
        .task { await runSequence() }
    }

    private var xpHeader: some View {
        HStack(spacing: 9) {
            Image(systemName: "star.fill").foregroundStyle(SBColor.gold)
            Text("\(appState.xp.formatted()) XP").font(.headline.monospacedDigit())
        }
        .padding(.horizontal, 17).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(SBColor.gold.opacity(0.35), lineWidth: 1))
        .shadow(color: SBColor.gold.opacity(xpFlying ? 0.8 : 0.2), radius: xpFlying ? 22 : 8)
        .scaleEffect(xpFlying ? 1.08 : 1)
    }

    private func world(in size: CGSize) -> some View {
        let start = CGPoint(x: size.width * 0.31, y: size.height * 0.57)
        let destination = CGPoint(x: size.width * 0.69, y: size.height * 0.31)
        return ZStack {
            Path { path in
                path.move(to: start)
                path.addCurve(to: destination,
                              control1: CGPoint(x: size.width * 0.25, y: size.height * 0.39),
                              control2: CGPoint(x: size.width * 0.72, y: size.height * 0.5))
            }
            .trim(from: 0, to: birdFlying ? 1 : 0)
            .stroke(SBColor.gold.opacity(0.45), style: StrokeStyle(lineWidth: 2, dash: [4, 8]))
            .animation(.easeInOut(duration: 1.35), value: birdFlying)

            island(challenge, completed: true)
                .position(start)

            if let nextChallenge {
                island(nextChallenge, completed: false)
                    .saturation(nextRevealed ? 1 : 0.08)
                    .opacity(nextRevealed ? 1 : 0.3)
                    .scaleEffect(nextRevealed ? 1 : 0.88)
                    .position(destination)
                cloudLock
                    .opacity(nextRevealed ? 0 : 0.95)
                    .scaleEffect(nextRevealed ? 1.5 : 1)
                    .position(destination)
            } else {
                Image("Island_FinalCastle").resizable().scaledToFit().frame(width: 225, height: 150)
                    .position(destination)
            }

            ForEach(0..<12, id: \.self) { index in
                xpParticle(index, start: start, size: size)
            }

            Image(appState.equippedBird.flightAsset)
                .resizable().scaledToFit().frame(width: birdFlying ? 92 : 76, height: birdFlying ? 72 : 60)
                .rotationEffect(.degrees(birdFlying ? -8 : birdHappy ? -7 : 0))
                .scaleEffect(birdHappy ? 1.12 : 1)
                .position(x: birdFlying ? destination.x : start.x + 46,
                          y: birdFlying ? destination.y - 52 : start.y - 58 + (birdHappy ? -12 : 0))
                .shadow(color: SBColor.gold.opacity(0.6), radius: 14)
                .animation(.spring(response: 0.38, dampingFraction: 0.5), value: birdHappy)
                .animation(.easeInOut(duration: 1.35), value: birdFlying)

            Text(nextChallenge == nil ? "JOURNEY COMPLETED" : "NEW ISLAND DISCOVERED")
                .font(.caption.bold()).tracking(2).foregroundStyle(SBColor.gold)
                .padding(.horizontal, 15).padding(.vertical, 9)
                .background(SBColor.surface.opacity(0.88), in: Capsule())
                .overlay(Capsule().stroke(SBColor.gold.opacity(0.3)))
                .opacity(nextRevealed ? 1 : 0)
                .offset(y: size.height * 0.13)
        }
    }

    private func island(_ challenge: Challenge, completed: Bool) -> some View {
        ZStack {
            Image(challenge.type.islandAsset).resizable().scaledToFit().frame(width: 205, height: 138)
                .shadow(color: .black.opacity(0.45), radius: 14, y: 10)
            if completed {
                Image(systemName: "checkmark")
                    .font(.headline.bold()).foregroundStyle(SBColor.background)
                    .frame(width: 34, height: 34).background(SBColor.success, in: Circle())
            }
        }
    }

    private var cloudLock: some View {
        ZStack {
            Image("Cloud_LockedDense").resizable().scaledToFit().frame(width: 235, height: 135)
            Image(systemName: "lock.fill").font(.title2).foregroundStyle(SBColor.secondaryText)
        }
    }

    private func xpParticle(_ index: Int, start: CGPoint, size: CGSize) -> some View {
        let spreadX = CGFloat((index % 4) * 24 - 36)
        let spreadY = CGFloat((index / 4) * 17 - 18)
        return Image(systemName: index.isMultiple(of: 3) ? "star.fill" : "sparkle")
            .font(.system(size: CGFloat(10 + index % 3 * 3), weight: .bold))
            .foregroundStyle(index.isMultiple(of: 2) ? SBColor.gold : SBColor.champagne)
            .position(x: xpFlying ? size.width / 2 : start.x + spreadX,
                      y: xpFlying ? 42 : start.y + spreadY)
            .opacity(xpFlying ? 0 : 1)
            .scaleEffect(xpFlying ? 0.3 : 1)
            .animation(.easeIn(duration: 0.85).delay(Double(index) * 0.035), value: xpFlying)
    }

    private var summary: some View {
        VStack(spacing: 12) {
            Image(summaryRewardAsset)
                .resizable().scaledToFit().frame(width: 94, height: 94)
                .shadow(color: SBColor.gold.opacity(0.35), radius: 14)
            Text(journeyCompleted ? "JOURNEY MASTERED" : "ISLAND COMPLETED")
                .font(.system(size: 24, weight: .semibold, design: .serif))
            Text("+\(earnedXP) XP").font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(SBColor.gold)
            if didLevelUp {
                HStack(spacing: 8) {
                    Image("Reward_LevelUp").resizable().scaledToFit().frame(width: 34, height: 34)
                    Text("LEVEL \(appState.level) REACHED")
                }.font(.caption.bold()).tracking(1).foregroundStyle(SBColor.sky)
            }
            Button(journeyCompleted ? "VIEW COMPLETED JOURNEY" : "BACK TO JOURNEY", action: close)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .background(SBColor.surface.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(SBColor.gold.opacity(0.2)))
    }

    private var summaryRewardAsset: String {
        if journeyCompleted { return "Reward_JourneyCompleted" }
        if challenge.type == .milestone { return "Reward_MysteryChest" }
        return "Reward_IslandCompleted"
    }

    @MainActor
    private func runSequence() async {
        guard !sequenceStarted else { return }
        sequenceStarted = true
        if !animate {
            xpFlying = true; birdHappy = true; birdFlying = true; nextRevealed = true; summaryVisible = true
            return
        }
        try? await Task.sleep(nanoseconds: 350_000_000)
        withAnimation { xpFlying = true }
        try? await Task.sleep(nanoseconds: 700_000_000)
        withAnimation { birdHappy = true }
        try? await Task.sleep(nanoseconds: 500_000_000)
        withAnimation { birdFlying = true }
        try? await Task.sleep(nanoseconds: 1_050_000_000)
        withAnimation(.spring(response: 0.65, dampingFraction: 0.72)) { nextRevealed = true }
        try? await Task.sleep(nanoseconds: 650_000_000)
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) { summaryVisible = true }
        if unlockedBird != nil {
            try? await Task.sleep(nanoseconds: 650_000_000)
            withAnimation(.easeInOut(duration: 0.45)) { unlockVisible = true }
        }
    }
}

private struct BirdUnlockOverlay: View {
    let previousBird: Bird
    let bird: Bird
    let equip: () -> Void
    let later: () -> Void
    @State private var revealed = false

    var body: some View {
        ZStack {
            PremiumBackground()
            RadialGradient(colors: [SBColor.gold.opacity(revealed ? 0.32 : 0.08), .clear], center: .center, startRadius: 0, endRadius: 300).ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer()
                Text("NEW BIRD UNLOCKED!").font(.caption.bold()).tracking(2.4).foregroundStyle(SBColor.gold)
                ZStack {
                    Circle().stroke(SBColor.gold.opacity(0.32), style: StrokeStyle(lineWidth: 1.2, dash: [4, 8])).frame(width: 270, height: 270)
                        .rotationEffect(.degrees(revealed ? 180 : 0))
                    Image(previousBird.portraitAsset).resizable().scaledToFit().frame(width: 190, height: 190)
                        .opacity(revealed ? 0 : 1).scaleEffect(revealed ? 0.45 : 1)
                    Image(bird.portraitAsset).resizable().scaledToFit().frame(width: 250, height: 250)
                        .opacity(revealed ? 1 : 0).scaleEffect(revealed ? 1 : 0.4)
                        .shadow(color: SBColor.gold.opacity(0.72), radius: 28)
                    ForEach(0..<10, id: \.self) { index in
                        Diamond().fill(index.isMultiple(of: 2) ? SBColor.gold : SBColor.sky)
                            .frame(width: 6, height: 12)
                            .offset(y: revealed ? -155 : -45)
                            .rotationEffect(.degrees(Double(index) * 36))
                            .opacity(revealed ? 0.9 : 0)
                    }
                }
                .animation(.spring(response: 1, dampingFraction: 0.68), value: revealed)
                Text(bird.name.uppercased()).font(.system(size: 36, weight: .semibold, design: .serif))
                Text(bird.personality).font(.headline).foregroundStyle(SBColor.sky)
                Text(bird.quote).font(.subheadline).italic().foregroundStyle(SBColor.secondaryText).multilineTextAlignment(.center).padding(.horizontal, 34)
                Spacer()
                Button("EQUIP", action: equip).buttonStyle(PrimaryButtonStyle(color: SBColor.gold))
                Button("LATER", action: later).font(.subheadline.bold()).foregroundStyle(SBColor.secondaryText).padding(.vertical, 8)
            }.padding(22)
        }
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 1, dampingFraction: 0.68).delay(0.35)) { revealed = true }
        }
    }
}
