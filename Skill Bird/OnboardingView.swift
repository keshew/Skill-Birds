import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var page = 0
    @State private var selectedSkill: Skill?
    @State private var search = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "bird.fill").font(.caption).foregroundStyle(SBColor.gold)
                    Text("SKILL BIRD").font(.system(size: 11, weight: .bold, design: .rounded)).tracking(2.2)
                }
                Spacer()
                HStack(spacing: 7) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule().fill(index <= page ? LinearGradient(colors: [SBColor.gold, SBColor.sky], startPoint: .leading, endPoint: .trailing) : LinearGradient(colors: [.white.opacity(0.11), .white.opacity(0.11)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: index == page ? 30 : 9, height: 3)
                }
                }
            }
            .padding(.horizontal, 24).padding(.top, 15)

            if page < 3 {
                introPage
            } else {
                skillPage
            }
        }
        .background(PremiumBackground())
        .foregroundStyle(SBColor.text)
        .fullScreenCover(item: $selectedSkill) { skill in
            SkillDetailView(skill: skill, actionTitle: "BEGIN JOURNEY") {
                selectedSkill = nil
                appState.beginJourney(skill)
            }
            .presentationDetents([.large])
        }
    }

    private var introPage: some View {
        let pages = [
            ("Turn learning into an adventure.", "Choose a skill, follow your path, complete challenges and watch your bird fly higher.", "map.fill", "GET STARTED"),
            ("Every skill has a path.", "We'll show you where to start, what comes next, and how every step connects.", "point.topleft.down.to.point.bottomright.curvepath", "CONTINUE"),
            ("Challenge yourself.", "Choose how quickly you can finish each step. The bolder the bet, the bigger the XP reward.", "timer", "CHOOSE MY SKILL")
        ]
        return VStack(spacing: 0) {
            Spacer()
            Image(onboardingArtwork)
                .resizable().scaledToFill()
                .frame(height: 350)
                .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [.clear, SBColor.background.opacity(0.72)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 110)
                }
                .overlay(RoundedRectangle(cornerRadius: 34).stroke(SBColor.gold.opacity(0.16)))
                .shadow(color: .black.opacity(0.35), radius: 24, y: 14)
                .padding(.horizontal, 18)
            Spacer()
            VStack(spacing: 13) {
                OrnamentalDivider().frame(width: 120).padding(.bottom, 6)
                Text(pages[page].0).font(.system(size: 33, weight: .semibold, design: .serif)).multilineTextAlignment(.center)
                Text(pages[page].1).font(.body).foregroundStyle(SBColor.secondaryText).multilineTextAlignment(.center).lineSpacing(4)
            }.padding(.horizontal, 28)
            Spacer()
            Button(pages[page].3) { withAnimation { page += 1 } }
                .buttonStyle(PrimaryButtonStyle()).padding(.horizontal, 22).padding(.bottom, 22)
        }
    }

    private var onboardingArtwork: String {
        ["Onboarding_Adventure", "Onboarding_TimeBet", "Onboarding_BirdEvolution"][min(page, 2)]
    }

    private var filteredSkills: [Skill] {
        search.isEmpty ? SampleData.skills : SampleData.skills.filter { $0.title.localizedCaseInsensitiveContains(search) }
    }

    private var skillPage: some View {
        VStack(spacing: 0) {
            ScreenHeader("What do you want to learn?", eyebrow: "Choose your journey", subtitle: "Pick one path to begin. You can explore more later.")
                .padding(.horizontal, 22).padding(.top, 22)
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(SBColor.secondaryText)
                TextField("Search skills", text: $search).textInputAutocapitalization(.never)
            }
            .padding(14).background(SBColor.surface).clipShape(RoundedRectangle(cornerRadius: 15))
            .padding(.horizontal, 22).padding(.vertical, 16)

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredSkills) { skill in
                        Button { selectedSkill = skill } label: {
                            HStack(spacing: 15) {
                                SkillEmblemView(skill: skill, size: 50)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(skill.title).font(.headline).foregroundStyle(SBColor.text)
                                    Text("\(skill.challenges.count) islands · ~\(skill.estimatedWeeks) weeks")
                                        .font(.caption).foregroundStyle(SBColor.secondaryText)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(SBColor.secondaryText)
                            }.padding(15).background(SBColor.surface).clipShape(RoundedRectangle(cornerRadius: 19))
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 22).padding(.bottom, 30)
            }
        }
    }
}

struct JourneyConstellation: View {
    let page: Int
    let symbol: String
    @State private var float = false

    var body: some View {
        ZStack {
            Ellipse().fill(SBColor.sapphire.opacity(0.08)).frame(width: 320, height: 240).blur(radius: 3)
            Circle().stroke(SBColor.sky.opacity(0.11), style: StrokeStyle(lineWidth: 0.8, dash: [3, 8])).frame(width: 248, height: 248).rotationEffect(.degrees(float ? 16 : 0))
            Circle().stroke(SBColor.gold.opacity(0.09), lineWidth: 0.7).frame(width: 190, height: 190)
            path
            premiumIsland(size: 118, symbol: symbol, accent: SBColor.sky)
                .offset(y: float ? -6 : 2)
            premiumIsland(size: 60, symbol: "sparkles", accent: SBColor.violet).offset(x: -115, y: -72)
            premiumIsland(size: 52, symbol: "star.fill", accent: SBColor.gold).offset(x: 120, y: 78)
            Image(systemName: "bird.fill").font(.system(size: 29, weight: .semibold)).foregroundStyle(LinearGradient(colors: [SBColor.champagne, SBColor.gold], startPoint: .top, endPoint: .bottom))
                .shadow(color: SBColor.gold.opacity(0.55), radius: 12).offset(x: float ? 102 : 94, y: float ? -78 : -67).rotationEffect(.degrees(-7))
        }
        .onAppear { withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { float = true } }
    }

    private var path: some View {
        Path { p in
            p.move(to: CGPoint(x: 53, y: 217)); p.addCurve(to: CGPoint(x: 164, y: 156), control1: CGPoint(x: 74, y: 170), control2: CGPoint(x: 132, y: 203)); p.addCurve(to: CGPoint(x: 278, y: 83), control1: CGPoint(x: 205, y: 115), control2: CGPoint(x: 232, y: 130))
        }.stroke(LinearGradient(colors: [SBColor.violet.opacity(0), SBColor.sky.opacity(0.46), SBColor.gold.opacity(0)], startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 1.2, dash: [4, 7]))
    }

    private func premiumIsland(size: CGFloat, symbol: String, accent: Color) -> some View {
        ZStack {
            Ellipse().fill(.black.opacity(0.45)).frame(width: size * 0.9, height: size * 0.24).blur(radius: 10).offset(y: size * 0.28)
            Diamond().fill(LinearGradient(colors: [accent.opacity(0.34), SBColor.surface], startPoint: .top, endPoint: .bottom)).frame(width: size * 0.67, height: size * 0.67).rotationEffect(.degrees(45)).offset(y: size * 0.13)
            Ellipse().fill(LinearGradient(colors: [accent.opacity(0.35), SBColor.elevated], startPoint: .top, endPoint: .bottom)).frame(width: size, height: size * 0.5)
                .overlay(Ellipse().stroke(LinearGradient(colors: [.white.opacity(0.45), accent.opacity(0.12)], startPoint: .top, endPoint: .bottom), lineWidth: 0.8))
            Image(systemName: symbol).font(.system(size: size * 0.26, weight: .semibold)).foregroundStyle(.white).offset(y: -size * 0.04)
        }.frame(width: size, height: size).shadow(color: accent.opacity(0.22), radius: 18, y: 8)
    }
}

struct SkillDetailView: View {
    let skill: Skill
    let actionTitle: String
    let action: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    hero
                    howItWorks
                    HStack {
                        metric("\(skill.challenges.count)", "ISLANDS")
                        metric("~\(skill.estimatedWeeks)", "WEEKS")
                        metric("4", "PROJECTS")
                    }.sbCard()
                    JourneyPreviewMap(skill: skill)
                    Button(actionTitle, action: action).buttonStyle(PrimaryButtonStyle())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 54)
            }
            .background(PremiumBackground())
            .toolbarBackground(SBColor.background.opacity(0.95), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("SKILL BIRD").font(.caption2.bold()).tracking(1.8).foregroundStyle(SBColor.gold)
                        Text("Choose your path").font(.caption2).foregroundStyle(SBColor.secondaryText)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(SBColor.secondaryText) }
                }
            }
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [SBColor.sapphire.opacity(0.34), SBColor.elevated, SBColor.surface], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(skill.challenges.last?.type.islandAsset ?? "Island_FinalCastle")
                .resizable().scaledToFit().frame(width: 235, height: 175)
                .frame(maxWidth: .infinity, alignment: .trailing).offset(x: 25, y: -12).opacity(0.8)
            LinearGradient(colors: [SBColor.surface.opacity(0.96), .clear], startPoint: .leading, endPoint: .trailing)
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    SkillEmblemView(skill: skill, size: 34)
                    Text(skill.category.uppercased()).font(.caption.bold()).tracking(1.3).foregroundStyle(SBColor.sky)
                }
                Text(skill.title).font(.system(size: 34, weight: .semibold, design: .serif)).lineLimit(2)
                Text(skill.description).font(.subheadline).foregroundStyle(SBColor.secondaryText).lineLimit(3).frame(maxWidth: 270, alignment: .leading)
            }.padding(22)
        }
        .frame(maxWidth: .infinity).frame(height: 245)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30).stroke(SBColor.gold.opacity(0.16)))
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("HOW IT WORKS").font(.caption.bold()).tracking(1.4).foregroundStyle(SBColor.gold)
            HStack(spacing: 8) {
                guideStep("1", "BET", "Pick a deadline")
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(SBColor.secondaryText)
                guideStep("2", "LEARN", "Update progress")
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(SBColor.secondaryText)
                guideStep("3", "FLY", "Earn XP & unlock")
            }
        }.sbCard()
    }

    private func guideStep(_ number: String, _ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 5) {
            Text(number).font(.caption.bold()).foregroundStyle(SBColor.background).frame(width: 25, height: 25).background(SBColor.sky, in: Circle())
            Text(title).font(.caption2.bold()).tracking(0.8)
            Text(subtitle).font(.system(size: 9)).foregroundStyle(SBColor.secondaryText).multilineTextAlignment(.center).lineLimit(2)
        }.frame(maxWidth: .infinity)
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) { Text(value).font(.title3.bold()); Text(label).font(.caption2.bold()).foregroundStyle(SBColor.secondaryText) }.frame(maxWidth: .infinity)
    }
}

private struct JourneyPreviewMap: View {
    let skill: Skill

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR LEARNING PATH").font(.caption.bold()).tracking(1.4).foregroundStyle(SBColor.sky)
            Text("Start at the first island. Complete each challenge to reveal the next one.")
                .font(.caption).foregroundStyle(SBColor.secondaryText).padding(.bottom, 8)
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 145, y: 55))
                    for index in 1..<skill.challenges.count {
                        let x: CGFloat = index.isMultiple(of: 2) ? 88 : 202
                        path.addLine(to: CGPoint(x: x, y: CGFloat(index) * 142 + 55))
                    }
                }
                .stroke(LinearGradient(colors: [SBColor.sky.opacity(0.65), SBColor.gold.opacity(0.3)], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 1.4, dash: [5, 8]))

                VStack(spacing: 12) {
                    ForEach(Array(skill.challenges.enumerated()), id: \.element.id) { index, challenge in
                        HStack {
                            if !index.isMultiple(of: 2) { Spacer(minLength: 85) }
                            previewIsland(challenge, index: index)
                            if index.isMultiple(of: 2) { Spacer(minLength: 85) }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(SBColor.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.08)))
    }

    private func previewIsland(_ challenge: Challenge, index: Int) -> some View {
        VStack(spacing: 1) {
            ZStack {
                Image(challenge.type.islandAsset).resizable().scaledToFit().frame(width: 142, height: 94)
                    .saturation(index == 0 ? 1 : 0.55).opacity(index == 0 ? 1 : 0.72)
                if index == 0 {
                    Image("Bird_Owl_Flight").resizable().scaledToFit().frame(width: 46, height: 38).offset(x: 48, y: -35)
                }
            }
            Text(challenge.title).font(.caption.bold()).lineLimit(1).frame(width: 155)
            Text(index == 0 ? "START HERE" : challenge.type.rawValue).font(.system(size: 8, weight: .bold)).tracking(0.8).foregroundStyle(index == 0 ? SBColor.sky : SBColor.secondaryText)
        }
    }
}
