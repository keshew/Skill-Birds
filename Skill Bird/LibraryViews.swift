import SwiftUI

struct SkillsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var search = ""
    @State private var selectedSkill: Skill?
    @State private var pendingSkill: Skill?
    @State private var confirmSwitch = false

    private var filtered: [Skill] {
        search.isEmpty ? SampleData.skills : SampleData.skills.filter {
            $0.title.localizedCaseInsensitiveContains(search) || $0.category.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenHeader("Skills", eyebrow: "Explore", subtitle: "Structured paths for your next chapter.")
                    if let active = appState.activeSkill {
                        VStack(alignment: .leading, spacing: 13) {
                            Text("ACTIVE JOURNEY").font(.caption.bold()).tracking(1.3).foregroundStyle(SBColor.sky)
                            HStack(spacing: 14) {
                                SkillEmblemView(skill: active, size: 50)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(active.title).font(.headline)
                                    SBProgressBar(value: journeyProgress(active), color: SBColor.success, height: 7)
                                    Text("\(completed(in: active)) / \(active.challenges.count) islands").font(.caption).foregroundStyle(SBColor.secondaryText)
                                }
                            }
                        }.sbCard()
                    }
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(SBColor.secondaryText)
                        TextField("Search skills", text: $search).textInputAutocapitalization(.never)
                    }.padding(14).background(SBColor.surface).clipShape(RoundedRectangle(cornerRadius: 15))
                    Text("ALL PATHS").font(.caption.bold()).tracking(1.3).foregroundStyle(SBColor.secondaryText)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 13) {
                        ForEach(filtered) { skill in
                            Button { selectedSkill = skill } label: {
                                VStack(alignment: .leading, spacing: 13) {
                                    SkillEmblemView(skill: skill, size: 47)
                                    Text(skill.title).font(.system(size: 17, weight: .semibold, design: .serif)).foregroundStyle(SBColor.text).multilineTextAlignment(.leading).lineLimit(2)
                                    Text(skill.category.uppercased()).font(.caption2.bold()).tracking(1).foregroundStyle(SBColor.secondaryText)
                                    HStack { Label("\(skill.challenges.count)", systemImage: "circle.grid.2x2.fill"); Spacer(); Text("~\(skill.estimatedWeeks)w") }
                                        .font(.caption).foregroundStyle(SBColor.secondaryText)
                                }.frame(maxWidth: .infinity, minHeight: 150, alignment: .leading).sbCard()
                            }.buttonStyle(.plain)
                        }
                    }
                    Color.clear.frame(height: 60)
                }.padding(20).padding(.bottom, 20)
            }
            .background(PremiumBackground()).toolbar(.hidden, for: .navigationBar)
        }
        .fullScreenCover(item: $selectedSkill) { skill in
            SkillDetailView(skill: skill, actionTitle: skill.id == appState.activeSkillID ? "CLOSE" : "START THIS JOURNEY") {
                guard skill.id != appState.activeSkillID else { selectedSkill = nil; return }
                if appState.activeSkillID != nil { pendingSkill = skill; selectedSkill = nil; confirmSwitch = true }
                else { appState.beginJourney(skill); selectedSkill = nil }
            }.presentationDetents([.large])
        }
        .alert("Switch journey?", isPresented: $confirmSwitch) {
            Button("Cancel", role: .cancel) { pendingSkill = nil }
            Button("Switch") { if let pendingSkill { appState.beginJourney(pendingSkill) }; pendingSkill = nil }
        } message: { Text("Your progress is saved. You can return to this journey later.") }
    }

    private func completed(in skill: Skill) -> Int { skill.challenges.filter { appState.progress(for: $0).isCompleted }.count }
    private func journeyProgress(_ skill: Skill) -> Double { Double(completed(in: skill)) / Double(skill.challenges.count) }
}

struct BirdsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedBird: Bird?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenHeader("My Birds", eyebrow: "Collection", subtitle: "\(appState.unlockedBirds.count) / \(SampleData.birds.count) discovered")
                    featuredBird
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 13) {
                        ForEach(SampleData.birds) { bird in
                            birdCell(bird)
                        }
                    }
                    Color.clear.frame(height: 60)
                }.padding(20).padding(.bottom, 20)
            }.background(PremiumBackground()).toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $selectedBird) { bird in BirdDetailView(bird: bird).presentationDetents([.medium, .large]) }
    }

    private var featuredBird: some View {
        HStack(spacing: 20) {
            BirdMedallion(bird: appState.equippedBird, unlocked: true, size: 108)
            VStack(alignment: .leading, spacing: 6) {
                Text("EQUIPPED").font(.caption2.bold()).tracking(1.4).foregroundStyle(SBColor.gold)
                Text(appState.equippedBird.name).font(.title2.bold())
                Text(appState.equippedBird.personality).font(.subheadline).foregroundStyle(SBColor.secondaryText)
                Text("“\(appState.equippedBird.quote)”").font(.caption).italic().foregroundStyle(SBColor.secondaryText).padding(.top, 3)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).sbCard()
    }

    private func birdCell(_ bird: Bird) -> some View {
        let unlocked = appState.xp >= bird.requiredXP
        return Button { selectedBird = bird } label: {
            VStack(spacing: 10) {
                ZStack {
                    BirdMedallion(bird: bird, unlocked: unlocked, size: 78)
                }
                Text(bird.name).font(.subheadline.bold()).foregroundStyle(unlocked ? SBColor.text : SBColor.secondaryText)
                Text(bird.id == appState.equippedBirdID ? "EQUIPPED" : unlocked ? "OWNED" : "\(bird.requiredXP.formatted()) XP")
                    .font(.caption2.bold()).foregroundStyle(bird.id == appState.equippedBirdID ? SBColor.gold : SBColor.secondaryText)
            }.frame(maxWidth: .infinity, minHeight: 145).sbCard()
        }.buttonStyle(.plain)
    }
}

struct BirdDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let bird: Bird
    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(.white.opacity(0.2)).frame(width: 42, height: 5).padding(.top, 10)
            Spacer()
            BirdMedallion(bird: bird, unlocked: appState.xp >= bird.requiredXP, size: 158)
            Text(bird.name).font(.system(size: 32, weight: .semibold, design: .serif))
            Text(bird.personality).font(.headline).foregroundStyle(SBColor.gold)
            Text("“\(bird.quote)”").multilineTextAlignment(.center).foregroundStyle(SBColor.secondaryText)
            HStack { birdMetric("RARITY", bird.rarity); birdMetric("UNLOCKS AT", "\(bird.requiredXP.formatted()) XP") }.sbCard()
            Spacer()
            if appState.xp >= bird.requiredXP {
                Button(bird.id == appState.equippedBirdID ? "DONE" : "EQUIP") {
                    if bird.id != appState.equippedBirdID { appState.equip(bird) }
                    dismiss()
                }.buttonStyle(PrimaryButtonStyle(color: bird.id == appState.equippedBirdID ? SBColor.secondaryText : SBColor.sky))
            } else {
                VStack(spacing: 8) {
                    SBProgressBar(value: Double(appState.xp) / Double(max(bird.requiredXP, 1)), color: SBColor.gold)
                    Text("\((bird.requiredXP - appState.xp).formatted()) XP to unlock").font(.caption).foregroundStyle(SBColor.secondaryText)
                    Button("CLOSE") { dismiss() }.buttonStyle(PrimaryButtonStyle(color: SBColor.secondaryText)).padding(.top, 12)
                }
            }
        }.padding(22).background(PremiumBackground()).foregroundStyle(SBColor.text)
    }
    private func birdMetric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) { Text(title).font(.caption2.bold()).foregroundStyle(SBColor.secondaryText); Text(value).font(.subheadline.bold()) }.frame(maxWidth: .infinity)
    }
}

struct BirdMedallion: View {
    let bird: Bird
    let unlocked: Bool
    let size: CGFloat
    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [unlocked ? SBColor.gold.opacity(0.22) : .white.opacity(0.04), SBColor.surface.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().stroke(AngularGradient(colors: unlocked ? [SBColor.gold.opacity(0.75), SBColor.sky.opacity(0.24), SBColor.gold.opacity(0.08), SBColor.gold.opacity(0.75)] : [.white.opacity(0.09), .clear, .white.opacity(0.09)], center: .center), lineWidth: max(0.8, size * 0.009))
            Circle().stroke(.white.opacity(unlocked ? 0.12 : 0.03), lineWidth: 0.7).padding(size * 0.11)
            if unlocked {
                Image(bird.portraitAsset)
                    .resizable().scaledToFit()
                    .frame(width: size * 0.88, height: size * 0.88)
                    .mask(Circle().padding(size * 0.045))
                    .shadow(color: SBColor.gold.opacity(0.32), radius: size * 0.08)
            } else {
                Image(systemName: "lock.fill").font(.system(size: size * 0.3)).foregroundStyle(SBColor.secondaryText.opacity(0.42))
            }
        }.frame(width: size, height: size).shadow(color: .black.opacity(0.3), radius: size * 0.13, y: size * 0.08)
    }
}
