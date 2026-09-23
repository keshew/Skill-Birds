import SwiftUI

struct MainTabView: View {
    @State private var selection = 0

    var body: some View {
        ZStack {
            PremiumBackground()
            Group {
                switch selection {
                case 0: JourneyView()
                case 1: SkillsView()
                case 2: BirdsView()
                case 3: ProgressDashboardView()
                default: ProfileView()
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                PremiumTabBar(selection: $selection)
                Color.clear.frame(height: 40)
            }
            .background(.ultraThinMaterial)
            .background(SBColor.surface.opacity(0.92))
        }
    }
}

struct PremiumTabBar: View {
    @Binding var selection: Int
    private let items = [("Journey", "map.fill"), ("Skills", "sparkles.rectangle.stack.fill"), ("Birds", "bird.fill"), ("Progress", "chart.xyaxis.line"), ("Profile", "person.crop.circle.fill")]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Button {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { selection = index }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    VStack(spacing: 5) {
                        ZStack {
                            if selection == index {
                                Capsule().fill(SBColor.sky.opacity(0.13)).frame(width: 45, height: 30)
                                    .overlay(Capsule().stroke(SBColor.sky.opacity(0.2)))
                            }
                            Image(systemName: item.1).font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(selection == index ? LinearGradient(colors: [.white, SBColor.sky], startPoint: .top, endPoint: .bottom) : LinearGradient(colors: [SBColor.secondaryText, SBColor.secondaryText], startPoint: .top, endPoint: .bottom))
                        }.frame(height: 31)
                        Text(item.0).font(.system(size: 9, weight: .semibold, design: .rounded)).foregroundStyle(selection == index ? SBColor.text : SBColor.secondaryText)
                    }.frame(maxWidth: .infinity)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10).padding(.top, 9).padding(.bottom, 6)
        .background(.ultraThinMaterial)
        .background(SBColor.surface.opacity(0.86))
        .overlay(alignment: .top) { LinearGradient(colors: [.clear, SBColor.gold.opacity(0.38), .clear], startPoint: .leading, endPoint: .trailing).frame(height: 0.7) }
    }
}

struct JourneyView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedChallenge: Challenge?

    var body: some View {
        NavigationStack {
            Group {
                if let skill = appState.activeSkill {
                    journey(skill)
                } else {
                    EmptyJourneyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                GeometryReader { geometry in
                    Image("Background_JourneySky")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .opacity(0.2)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
            .background(PremiumBackground())
            .clipped()
            .toolbar(.hidden, for: .navigationBar)
        }
        .fullScreenCover(item: $selectedChallenge) { challenge in
            if let skill = appState.activeSkill {
                ChallengeFlowView(skill: skill, challenge: challenge)
            }
        }
    }

    private func journey(_ skill: Skill) -> some View {
        VStack(spacing: 0) {
            journeyHeader(skill)
            ScrollViewReader { proxy in
                ScrollView {
                    ZStack {
                        ForEach(0..<7, id: \.self) { cloud in
                            Image(cloud.isMultiple(of: 2) ? "Cloud_SoftWide" : "Cloud_SmallWisp")
                                .resizable().scaledToFit()
                                .frame(width: cloud.isMultiple(of: 2) ? 150 : 96)
                                .opacity(0.28)
                                .offset(x: cloud.isMultiple(of: 2) ? 135 : -142, y: CGFloat(cloud * 225 - 80))
                        }
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: 30))
                            path.addLine(to: CGPoint(x: 0, y: CGFloat(skill.challenges.count - 1) * 178 + 30))
                        }
                        .stroke(LinearGradient(colors: [SBColor.gold.opacity(0.15), SBColor.sky.opacity(0.42), SBColor.violet.opacity(0.12)], startPoint: .bottom, endPoint: .top), style: StrokeStyle(lineWidth: 1.5, dash: [4, 9]))
                        .frame(width: 3)

                        LazyVStack(spacing: 34) {
                            Text("ASCEND THE PATH").font(.system(size: 9, weight: .bold, design: .rounded)).tracking(3).foregroundStyle(SBColor.gold.opacity(0.7))
                                .padding(.bottom, 2)
                            ForEach(Array(skill.challenges.enumerated()), id: \.element.id) { index, challenge in
                                IslandView(skill: skill, challenge: challenge, index: index) {
                                    if appState.isUnlocked(challenge, in: skill) { selectedChallenge = challenge }
                                }
                                .id(challenge.id)
                                .offset(x: index.isMultiple(of: 2) ? -46 : 46)
                            }
                            Color.clear.frame(height: 60)
                        }.padding(.vertical, 35)
                    }
                }
                .onAppear {
                    if let current = skill.challenges.first(where: { !appState.progress(for: $0).isCompleted && appState.isUnlocked($0, in: skill) }) {
                        proxy.scrollTo(current.id, anchor: .center)
                    }
                }
            }
        }
    }

    private func journeyHeader(_ skill: Skill) -> some View {
        VStack(spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("ACTIVE JOURNEY").font(.system(size: 9, weight: .bold, design: .rounded)).tracking(2.1).foregroundStyle(SBColor.gold)
                    Text(skill.title).font(.system(size: 22, weight: .semibold, design: .serif))
                }
                Spacer()
                ZStack {
                    Circle().fill(LinearGradient(colors: [SBColor.gold.opacity(0.18), .clear], startPoint: .top, endPoint: .bottom))
                    Circle().stroke(SBColor.gold.opacity(0.25), lineWidth: 0.8)
                    Image(appState.equippedBird.portraitAsset).resizable().scaledToFit().padding(4).clipShape(Circle())
                }.frame(width: 49, height: 49).shadow(color: SBColor.gold.opacity(0.18), radius: 10)
            }
            HStack(spacing: 10) {
                headerPill("Level \(appState.level)", "sparkles", SBColor.sky)
                headerPill("\(appState.currentStreak)", "flame.fill", SBColor.danger)
                headerPill("\(appState.xp.formatted()) XP", "star.fill", SBColor.gold)
            }
            if let current = skill.challenges.first(where: { !appState.progress(for: $0).isCompleted && appState.isUnlocked($0, in: skill) }) {
                HStack(spacing: 10) {
                    Image(systemName: "hand.tap.fill").foregroundStyle(SBColor.sky)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("YOUR NEXT MOVE").font(.system(size: 9, weight: .bold, design: .rounded)).tracking(1.4).foregroundStyle(SBColor.gold)
                        Text("Tap “\(current.title)”, choose a deadline, update progress and finish to fly onward.")
                            .font(.caption).foregroundStyle(SBColor.secondaryText).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(11).background(SBColor.sky.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(SBColor.sky.opacity(0.12)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 14)
        .background(.ultraThinMaterial)
        .background(SBColor.surface.opacity(0.82))
        .overlay(alignment: .bottom) { LinearGradient(colors: [.clear, SBColor.gold.opacity(0.28), .clear], startPoint: .leading, endPoint: .trailing).frame(height: 0.7) }
    }

    private func headerPill(_ text: String, _ icon: String, _ color: Color) -> some View {
        Label(text, systemImage: icon).font(.caption.weight(.bold)).foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 7).background(color.opacity(0.1)).clipShape(Capsule())
    }
}

struct IslandView: View {
    @EnvironmentObject private var appState: AppState
    let skill: Skill
    let challenge: Challenge
    let index: Int
    let action: () -> Void

    var body: some View {
        let value = appState.progress(for: challenge)
        let unlocked = appState.isUnlocked(challenge, in: skill)
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack {
                    if !unlocked {
                        Image("Cloud_LockedDense")
                            .resizable().scaledToFit().frame(width: 238, height: 128)
                            .opacity(0.52).offset(y: 12)
                    }
                    Image(challenge.type.islandAsset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: challenge.type == .finalProject ? 218 : 202, height: 126)
                        .saturation(unlocked ? 1 : 0.08)
                        .opacity(unlocked ? 1 : 0.38)
                        .shadow(color: .black.opacity(unlocked ? 0.42 : 0.18), radius: 14, y: 10)
                    if value.isCompleted || !unlocked {
                        Image(systemName: value.isCompleted ? "checkmark" : "lock.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(value.isCompleted ? SBColor.background : SBColor.secondaryText)
                            .frame(width: 34, height: 34)
                            .background(value.isCompleted ? SBColor.success : SBColor.surface.opacity(0.92), in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
                            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                    }
                    if unlocked && !value.isCompleted && isCurrent {
                        Image(appState.equippedBird.hasFlightAsset ? appState.equippedBird.flightAsset : appState.equippedBird.portraitAsset)
                            .resizable().scaledToFit().frame(width: 62, height: 48)
                            .shadow(color: SBColor.gold.opacity(0.55), radius: 9).offset(x: 76, y: -53)
                    }
                }
                VStack(spacing: 3) {
                    Text(challenge.title).font(.system(size: 14, weight: .semibold, design: .serif)).foregroundStyle(unlocked ? SBColor.text : SBColor.secondaryText).lineLimit(1)
                    Text(value.isCompleted ? "COMPLETED" : isCurrent ? "CURRENT ISLAND" : unlocked ? challenge.type.rawValue : "LOCKED")
                        .font(.caption2.bold()).tracking(1).foregroundStyle(value.isCompleted ? SBColor.success : isCurrent ? SBColor.sky : SBColor.secondaryText)
                }
            }.contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(!unlocked)
    }

    private var isCurrent: Bool {
        guard let first = skill.challenges.first(where: { !appState.progress(for: $0).isCompleted && appState.isUnlocked($0, in: skill) }) else { return false }
        return first.id == challenge.id
    }
}

struct FloatingIslandToken: View {
    let accent: Color
    let locked: Bool
    let important: Bool
    var body: some View {
        ZStack {
            Ellipse().fill(.black.opacity(0.48)).frame(width: important ? 184 : 158, height: 34).blur(radius: 13).offset(y: 38)
            IslandUnderbelly().fill(LinearGradient(colors: [accent.opacity(locked ? 0.12 : 0.38), SBColor.surface.opacity(0.35)], startPoint: .top, endPoint: .bottom))
                .frame(width: important ? 170 : 148, height: 91).offset(y: 20)
            IslandUnderbelly().stroke(accent.opacity(locked ? 0.04 : 0.16), lineWidth: 0.7).frame(width: important ? 170 : 148, height: 91).offset(y: 20)
            Ellipse().fill(LinearGradient(colors: [locked ? SBColor.surface : accent.opacity(0.72), SBColor.elevated], startPoint: .top, endPoint: .bottom)).frame(width: important ? 190 : 166, height: important ? 72 : 64)
                .overlay(Ellipse().stroke(LinearGradient(colors: [.white.opacity(locked ? 0.06 : 0.42), accent.opacity(0.08)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
                .offset(y: -7)
            if important {
                ForEach([-55.0, 53.0], id: \.self) { x in
                    Diamond().fill(SBColor.gold.opacity(locked ? 0.12 : 0.7)).frame(width: 8, height: 16).offset(x: x, y: -35).shadow(color: SBColor.gold.opacity(0.4), radius: 5)
                }
            }
        }.frame(width: 202, height: 105)
    }
}

struct IslandUnderbelly: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(); path.move(to: CGPoint(x: rect.minX + 3, y: rect.minY)); path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: CGPoint(x: rect.midX * 0.7, y: rect.maxY * 0.68)); path.addQuadCurve(to: CGPoint(x: rect.maxX - 3, y: rect.minY), control: CGPoint(x: rect.midX * 1.3, y: rect.maxY * 0.68)); path.closeSubpath(); return path
    }
}

struct CloudWisp: View {
    var body: some View {
        ZStack {
            Capsule().fill(LinearGradient(colors: [SBColor.cloud.opacity(0.35), .clear], startPoint: .leading, endPoint: .trailing)).frame(height: 14)
            Circle().fill(SBColor.cloud.opacity(0.23)).frame(width: 28, height: 28).offset(x: -16, y: -7)
            Circle().fill(SBColor.cloud.opacity(0.18)).frame(width: 38, height: 38).offset(x: 7, y: -9)
        }.blur(radius: 1.5)
    }
}

struct EmptyJourneyView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "map").font(.system(size: 64)).foregroundStyle(SBColor.sky)
            Text("No Active Journey").font(.title2.bold())
            Text("Choose a skill from the Skills tab to create your first learning path.").multilineTextAlignment(.center).foregroundStyle(SBColor.secondaryText)
        }.padding(32)
    }
}
