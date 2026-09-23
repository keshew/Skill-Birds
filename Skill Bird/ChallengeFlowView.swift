import SwiftUI

struct ChallengeFlowView: View {
    enum Phase { case details, deadline, confirmation, accepted, active, reward }
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let skill: Skill
    let challenge: Challenge
    @State private var phase: Phase = .details
    @State private var selectedOption: DeadlineOption?
    @State private var draftProgress: Double = 0
    @State private var earnedXP = 0
    @State private var didLevelUp = false
    @State private var newlyUnlockedBird: Bird?
    @State private var journeyCompleted = false
    @State private var showCompleteConfirmation = false
    @State private var initialized = false
    @State private var freshlyCompleted = false

    var body: some View {
        ZStack {
            PremiumBackground()
            switch phase {
            case .details: detailsView
            case .deadline: deadlineView
            case .confirmation: confirmationView
            case .accepted: acceptedView
            case .active: activeView
            case .reward: rewardView
            }
        }
        .foregroundStyle(SBColor.text)
        .overlay(alignment: .topTrailing) {
            if phase != .accepted && phase != .reward {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.headline).foregroundStyle(SBColor.secondaryText)
                        .frame(width: 40, height: 40).background(.ultraThinMaterial).clipShape(Circle()).overlay(Circle().stroke(.white.opacity(0.1)))
                }.padding(18)
            }
        }
        .onAppear {
            guard !initialized else { return }; initialized = true
            let value = appState.progress(for: challenge); draftProgress = value.progress
            if value.isCompleted {
                earnedXP = value.earnedXP
                journeyCompleted = skill.challenges.allSatisfy { appState.progress(for: $0).isCompleted }
                phase = .reward
            }
            else if value.isStarted { phase = .active }
        }
        .alert("Finished already?", isPresented: $showCompleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Yes, I finished it") {
                let previousLevel = appState.level
                let previousBirds = Set(appState.unlockedBirds.map(\.id))
                earnedXP = appState.complete(challenge)
                freshlyCompleted = true
                didLevelUp = appState.level > previousLevel
                newlyUnlockedBird = appState.unlockedBirds.last(where: { !previousBirds.contains($0.id) })
                journeyCompleted = skill.challenges.allSatisfy { appState.progress(for: $0).isCompleted }
                withAnimation { phase = .reward }
            }
        } message: {
            Text("Mark \(challenge.title) as completed? Your current progress is \(Int(appState.progress(for: challenge).progress * 100))%.")
        }
    }

    private var detailsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                challengeHero
                VStack(alignment: .leading, spacing: 10) {
                    Text(challenge.title).font(.system(size: 32, weight: .semibold, design: .serif))
                    Text(challenge.source).font(.subheadline).foregroundStyle(SBColor.secondaryText)
                    Text(challenge.description).foregroundStyle(SBColor.secondaryText).lineSpacing(4).padding(.top, 5)
                }
                VStack(alignment: .leading, spacing: 13) {
                    Text("WHY THIS MATTERS").font(.caption.bold()).tracking(1.2).foregroundStyle(SBColor.sky)
                    Text("This island builds the foundation you need for the next part of your journey.").font(.subheadline).lineSpacing(3)
                }.sbCard()
                VStack(alignment: .leading, spacing: 13) {
                    Text("WHAT YOU'LL LEARN").font(.caption.bold()).tracking(1.2).foregroundStyle(SBColor.sky)
                    ForEach(challenge.learning, id: \.self) { item in
                        Label(item, systemImage: "checkmark.circle.fill").font(.subheadline).foregroundStyle(SBColor.text)
                            .symbolRenderingMode(.palette).foregroundStyle(SBColor.success, SBColor.success.opacity(0.14))
                    }
                }.sbCard()
                Button("START CHALLENGE") { withAnimation { phase = .deadline } }.buttonStyle(PrimaryButtonStyle())
            }.padding(22).padding(.top, 24)
        }
    }

    private var challengeHero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32).fill(LinearGradient(colors: [SBColor.elevated.opacity(0.72), SBColor.sapphire.opacity(0.16), SBColor.surface], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(height: 230)
                .overlay(RoundedRectangle(cornerRadius: 32).stroke(LinearGradient(colors: [SBColor.gold.opacity(0.34), .white.opacity(0.09), SBColor.sky.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8))
                .shadow(color: SBColor.sapphire.opacity(0.16), radius: 25, y: 14)
            Circle().stroke(SBColor.gold.opacity(0.11), style: StrokeStyle(lineWidth: 0.8, dash: [3, 7])).frame(width: 165, height: 165)
            Circle().fill(SBColor.sky.opacity(0.06)).frame(width: 126, height: 126).blur(radius: 4)
            ForEach(0..<4, id: \.self) { index in
                Diamond().fill(index.isMultiple(of: 2) ? SBColor.gold.opacity(0.5) : SBColor.sky.opacity(0.4)).frame(width: 5, height: 5)
                    .offset(x: CGFloat([-94, 88, -72, 102][index]), y: CGFloat([-54, -78, 69, 47][index]))
            }
            VStack(spacing: 7) {
                Image(challenge.type.challengeAsset).resizable().scaledToFit().frame(width: 185, height: 164)
                    .shadow(color: SBColor.sky.opacity(0.3), radius: 16)
                HStack(spacing: 9) { Diamond().fill(SBColor.gold).frame(width: 5, height: 5); Text(challenge.type.rawValue); Diamond().fill(SBColor.gold).frame(width: 5, height: 5) }
                    .font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1.8).foregroundStyle(SBColor.gold)
            }
        }
    }

    private var deadlineView: some View {
        ScrollView {
            VStack(spacing: 18) {
                ScreenHeader("How fast can you finish it?", eyebrow: "Make your time bet", subtitle: "The harder the challenge, the bigger the reward.")
                ForEach(challenge.deadlines) { option in
                    Button {
                        selectedOption = option
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle().stroke(selectedOption == option ? SBColor.sky : .white.opacity(0.14), lineWidth: 2).frame(width: 24, height: 24)
                                if selectedOption == option { Circle().fill(SBColor.sky).frame(width: 12, height: 12) }
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.label).font(.caption.bold()).tracking(1.2).foregroundStyle(SBColor.secondaryText)
                                Text("\(option.days) Days").font(.title3.bold()).foregroundStyle(SBColor.text)
                            }
                            Spacer()
                            Text("+\(option.xp) XP").font(.headline).foregroundStyle(SBColor.gold)
                        }
                        .padding(17).background(LinearGradient(colors: selectedOption == option ? [SBColor.sapphire.opacity(0.19), SBColor.surface.opacity(0.88)] : [.white.opacity(0.055), SBColor.surface.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .clipShape(RoundedRectangle(cornerRadius: 21)).overlay(RoundedRectangle(cornerRadius: 21).stroke(selectedOption == option ? LinearGradient(colors: [SBColor.sky, SBColor.gold.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [.white.opacity(0.1), .white.opacity(0.02)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                    }.buttonStyle(.plain)
                }
                Button("CONTINUE") { withAnimation { phase = .confirmation } }
                    .buttonStyle(PrimaryButtonStyle()).disabled(selectedOption == nil).opacity(selectedOption == nil ? 0.45 : 1).padding(.top, 8)
            }.padding(22).padding(.top, 34)
        }
    }

    private var confirmationView: some View {
        VStack(spacing: 25) {
            Spacer()
            PremiumIcon(symbol: "flag.fill", color: SBColor.gold, size: 116)
            ScreenHeader("Ready to commit?", eyebrow: "Final check", subtitle: challenge.title).multilineTextAlignment(.center)
            if let selectedOption {
                VStack(spacing: 17) {
                    confirmationRow("Deadline", Date().addingTimeInterval(Double(selectedOption.days) * 86_400).formatted(date: .abbreviated, time: .omitted))
                    Divider().overlay(.white.opacity(0.08))
                    confirmationRow("Time", "\(selectedOption.days) Days")
                    Divider().overlay(.white.opacity(0.08))
                    confirmationRow("Reward", "+\(selectedOption.xp) XP", color: SBColor.gold)
                }.sbCard()
                Label("Finish after the deadline and you'll receive \(challenge.lateReward) XP instead.", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(SBColor.secondaryText).multilineTextAlignment(.center)
            }
            Spacer()
            Button("ACCEPT CHALLENGE") {
                guard let selectedOption else { return }
                appState.start(challenge, option: selectedOption)
                withAnimation { phase = .accepted }
            }.buttonStyle(PrimaryButtonStyle())
        }.padding(22)
    }

    private func confirmationRow(_ title: String, _ value: String, color: Color = SBColor.text) -> some View {
        HStack { Text(title).foregroundStyle(SBColor.secondaryText); Spacer(); Text(value).fontWeight(.bold).foregroundStyle(color) }
    }

    private var acceptedView: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle().fill(SBColor.success.opacity(0.08)).frame(width: 200, height: 200).overlay(Circle().stroke(SBColor.gold.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [3, 8])))
                Image("Reward_ChallengeAccepted")
                    .resizable().scaledToFit().frame(width: 188, height: 188)
                    .shadow(color: SBColor.gold.opacity(0.45), radius: 18)
            }
            Text("CHALLENGE ACCEPTED").font(.system(size: 27, weight: .black, design: .rounded)).tracking(1)
            if let selectedOption {
                Text("\(selectedOption.days) DAYS").font(.title.bold()).foregroundStyle(SBColor.sky)
                Text("\(selectedOption.xp) XP AT STAKE").font(.headline).foregroundStyle(SBColor.gold)
            }
            Spacer()
            Button("LET'S GO") { withAnimation { phase = .active } }.buttonStyle(PrimaryButtonStyle())
        }.padding(22)
    }

    private var activeView: some View {
        let value = appState.progress(for: challenge)
        return ScrollView {
            VStack(spacing: 25) {
                challengeHero.frame(height: 210)
                VStack(spacing: 7) {
                    Text(challenge.title).font(.system(size: 29, weight: .semibold, design: .serif)).multilineTextAlignment(.center)
                    if let deadline = value.deadline {
                        Label(deadlineText(deadline), systemImage: deadline < Date() ? "exclamationmark.circle.fill" : "timer")
                            .font(.subheadline.bold()).foregroundStyle(deadline < Date() ? SBColor.danger : SBColor.sky)
                    }
                }
                VStack(spacing: 18) {
                    HStack(alignment: .lastTextBaseline) {
                        Text("Progress").font(.headline)
                        Spacer()
                        Text("\(Int(draftProgress * 100))%").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(SBColor.sky)
                    }
                    SBProgressBar(value: draftProgress, height: 12)
                    Slider(value: $draftProgress, in: 0...1, step: 0.05).tint(SBColor.sky)
                    Button("UPDATE PROGRESS") { appState.update(challenge, to: draftProgress) }.buttonStyle(PrimaryButtonStyle())
                }.sbCard()
                HStack {
                    activeMetric("STARTED", value.startedAt?.formatted(date: .abbreviated, time: .omitted) ?? "—")
                    activeMetric("DEADLINE", value.deadline?.formatted(date: .abbreviated, time: .omitted) ?? "—")
                    activeMetric("REWARD", "+\(value.potentialXP ?? 0) XP")
                }.sbCard()
                Button("COMPLETE CHALLENGE") { showCompleteConfirmation = true }
                    .font(.subheadline.bold()).foregroundStyle(SBColor.success).padding(.bottom, 20)
            }.padding(22).padding(.top, 24)
        }
    }

    private func activeMetric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 5) { Text(title).font(.caption2.bold()).foregroundStyle(SBColor.secondaryText); Text(value).font(.caption.bold()).lineLimit(1).minimumScaleFactor(0.7) }.frame(maxWidth: .infinity)
    }
    private func deadlineText(_ deadline: Date) -> String {
        let seconds = deadline.timeIntervalSinceNow
        if seconds <= 0 { return "Deadline passed · \(challenge.lateReward) XP reward" }
        let days = Int(seconds / 86_400); let hours = Int(seconds.truncatingRemainder(dividingBy: 86_400) / 3_600)
        return "\(days) days \(hours) hours left"
    }

    private var rewardView: some View {
        let value = appState.progress(for: challenge)
        return CompletionSequenceView(
            skill: skill,
            challenge: challenge,
            nextChallenge: nextChallenge,
            earnedXP: earnedXP == 0 ? value.earnedXP : earnedXP,
            didLevelUp: didLevelUp,
            unlockedBird: newlyUnlockedBird,
            journeyCompleted: journeyCompleted,
            animate: freshlyCompleted,
            close: { dismiss() }
        )
    }

    private var nextChallenge: Challenge? {
        guard let index = skill.challenges.firstIndex(of: challenge), index + 1 < skill.challenges.count else { return nil }
        return skill.challenges[index + 1]
    }
}
