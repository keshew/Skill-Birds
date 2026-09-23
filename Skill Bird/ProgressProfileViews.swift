import SwiftUI
import UserNotifications

struct ProgressDashboardView: View {
    @EnvironmentObject private var appState: AppState
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenHeader("Your Progress", eyebrow: "Keep flying", subtitle: "Every small step moves your whole journey forward.")
                    levelCard
                    HStack(spacing: 13) {
                        statCard("\(appState.currentStreak)", "DAY STREAK", "flame.fill", SBColor.danger)
                        statCard("\(appState.onTimeRate)%", "ON TIME", "timer", SBColor.success)
                    }
                    HStack(spacing: 13) {
                        statCard("\(appState.completedCount)", "COMPLETED", "checkmark.seal.fill", SBColor.sky)
                        statCard("\(appState.bestStreak)", "BEST STREAK", "trophy.fill", SBColor.gold)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        Text("CHALLENGES").font(.caption.bold()).tracking(1.3).foregroundStyle(SBColor.secondaryText)
                        summaryRow("Completed on time", appState.onTimeCount, SBColor.success)
                        summaryRow("Completed late", appState.lateCount, SBColor.danger)
                        summaryRow("In progress", inProgress, SBColor.sky)
                    }.sbCard()
                    VStack(alignment: .leading, spacing: 17) {
                        Text("LEARNING HISTORY").font(.caption.bold()).tracking(1.3).foregroundStyle(SBColor.secondaryText)
                        if appState.activities.isEmpty {
                            Text("Your learning activity will appear here.").font(.subheadline).foregroundStyle(SBColor.secondaryText).padding(.vertical, 10)
                        } else {
                            ForEach(appState.activities.prefix(12)) { event in
                                HStack(alignment: .top, spacing: 13) {
                                    Image(systemName: event.icon).font(.subheadline).foregroundStyle(SBColor.sky).frame(width: 34, height: 34).background(SBColor.sky.opacity(0.1)).clipShape(Circle())
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(event.title).font(.subheadline.bold())
                                        Text(event.detail).font(.caption).foregroundStyle(SBColor.secondaryText)
                                    }
                                    Spacer()
                                    Text(event.date.formatted(date: .abbreviated, time: .omitted)).font(.caption2).foregroundStyle(SBColor.secondaryText)
                                }
                            }
                        }
                    }.sbCard()
                    Color.clear.frame(height: 60)
                }.padding(20).padding(.bottom, 20)
            }.background(PremiumBackground()).toolbar(.hidden, for: .navigationBar)
        }
    }

    private var inProgress: Int { appState.challengeProgress.values.filter { $0.isStarted && !$0.isCompleted }.count }
    private var levelCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LEVEL \(appState.level)").font(.caption.bold()).tracking(1.5).foregroundStyle(SBColor.sky)
                    Text("\(appState.xp.formatted()) XP").font(.system(size: 31, weight: .bold, design: .rounded))
                }
                Spacer()
                PremiumIcon(symbol: "sparkles", color: SBColor.gold, size: 58)
            }
            SBProgressBar(value: appState.levelProgress, color: SBColor.gold, height: 11)
            HStack { Text("Level \(appState.level)"); Spacer(); Text("\((appState.level) * 1_000) XP") }.font(.caption).foregroundStyle(SBColor.secondaryText)
        }.sbCard()
    }
    private func statCard(_ value: String, _ label: String, _ icon: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            PremiumIcon(symbol: icon, color: color, size: 43)
            Text(value).font(.system(size: 27, weight: .bold, design: .rounded))
            Text(label).font(.caption2.bold()).tracking(1).foregroundStyle(SBColor.secondaryText)
        }.frame(maxWidth: .infinity, alignment: .leading).sbCard()
    }
    private func summaryRow(_ label: String, _ count: Int, _ color: Color) -> some View {
        HStack { Circle().fill(color).frame(width: 9, height: 9); Text(label).font(.subheadline); Spacer(); Text("\(count)").font(.subheadline.bold()) }
    }
}

struct ProfileView: View {
    enum ProfileSheet: String, Identifiable { case privacy, terms, about; var id: String { rawValue } }
    @EnvironmentObject private var appState: AppState
    @State private var showReset = false
    @State private var activeSheet: ProfileSheet?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileHeader
                    VStack(spacing: 0) {
                        ToggleRow(title: "Daily Reminder", icon: "bell.fill", isOn: reminderBinding)
                        Divider().overlay(.white.opacity(0.06)).padding(.leading, 50)
                        ToggleRow(title: "Sound", icon: "speaker.wave.2.fill", isOn: savingBinding(\.soundEnabled))
                        Divider().overlay(.white.opacity(0.06)).padding(.leading, 50)
                        ToggleRow(title: "Haptics", icon: "waveform", isOn: savingBinding(\.hapticsEnabled))
                    }.sbCard()
                    VStack(spacing: 0) {
                        Button { activeSheet = .privacy } label: { settingsRow("Privacy Policy", "hand.raised.fill") }.buttonStyle(.plain)
                        Divider().overlay(.white.opacity(0.06)).padding(.leading, 50)
                        Button { activeSheet = .terms } label: { settingsRow("Terms of Use", "doc.text.fill") }.buttonStyle(.plain)
                        Divider().overlay(.white.opacity(0.06)).padding(.leading, 50)
                        Button { activeSheet = .about } label: { settingsRow("About Skill Bird", "info.circle.fill") }.buttonStyle(.plain)
                    }.sbCard()
                    Button(role: .destructive) { showReset = true } label: {
                        Label("Reset All Progress", systemImage: "arrow.counterclockwise").font(.subheadline.bold()).frame(maxWidth: .infinity).padding(16)
                    }.background(SBColor.danger.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 17))
                    Text("Skill Bird · Version 1.0").font(.caption).foregroundStyle(SBColor.secondaryText).padding(.top, 5)
                    Color.clear.frame(height: 60)
                }.padding(20).padding(.bottom, 20)
            }.background(PremiumBackground()).toolbar(.hidden, for: .navigationBar)
        }
        .alert("Reset all progress?", isPresented: $showReset) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) { appState.resetAll() }
        } message: { Text("This removes your journeys, XP, streak, and bird collection from this device. This cannot be undone.") }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .privacy: LegalView(kind: .privacy).presentationDetents([.large])
            case .terms: LegalView(kind: .terms).presentationDetents([.large])
            case .about: AboutView().presentationDetents([.medium])
            }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 15) {
            BirdMedallion(bird: appState.equippedBird, unlocked: true, size: 116)
            TextField("Your name", text: $appState.displayName)
                .font(.title2.bold()).multilineTextAlignment(.center).onSubmit { appState.save() }
                .onChange(of: appState.displayName) { _ in appState.save() }
            HStack(spacing: 8) {
                Text("Level \(appState.level)"); Text("•"); Text("\(appState.xp.formatted()) XP")
            }.font(.subheadline.bold()).foregroundStyle(SBColor.secondaryText)
        }.frame(maxWidth: .infinity).padding(.vertical, 16)
    }

    private var reminderBinding: Binding<Bool> {
        Binding(get: { appState.remindersEnabled }, set: { enabled in
            appState.remindersEnabled = enabled; appState.save()
            if enabled {
                NotificationManager.enable { granted in
                    if !granted { appState.remindersEnabled = false; appState.save() }
                }
            } else { NotificationManager.disable() }
        })
    }
    private func savingBinding(_ keyPath: ReferenceWritableKeyPath<AppState, Bool>) -> Binding<Bool> {
        Binding(get: { appState[keyPath: keyPath] }, set: { appState[keyPath: keyPath] = $0; appState.save() })
    }
    private func settingsRow(_ title: String, _ icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).foregroundStyle(SBColor.sky).frame(width: 30)
            Text(title).font(.subheadline)
            Spacer(); Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(SBColor.secondaryText)
        }.padding(.vertical, 14)
    }
}

struct ToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).foregroundStyle(SBColor.sky).frame(width: 30)
            Toggle(title, isOn: $isOn).font(.subheadline).tint(SBColor.sky)
        }.padding(.vertical, 8)
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(.white.opacity(0.2)).frame(width: 42, height: 5).padding(.top, 10)
            Spacer()
            BirdMedallion(bird: SampleData.birds[0], unlocked: true, size: 112)
            Text("Skill Bird").font(.system(size: 31, weight: .semibold, design: .serif))
            Text("Turn any skill into a journey.").font(.headline).foregroundStyle(SBColor.gold)
            Text("Choose what you want to learn, follow a structured path, challenge yourself with deadlines, earn XP, and keep flying.").multilineTextAlignment(.center).foregroundStyle(SBColor.secondaryText).lineSpacing(4)
            Spacer()
            Button("DONE") { dismiss() }.buttonStyle(PrimaryButtonStyle())
        }.padding(25).background(PremiumBackground()).foregroundStyle(SBColor.text)
    }
}

enum NotificationManager {
    static func enable(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { DispatchQueue.main.async { completion(false) }; return }
            let content = UNMutableNotificationContent()
            content.title = "Your bird is ready to fly"
            content.body = "A small step today keeps your learning journey moving."
            content.sound = .default
            var components = DateComponents(); components.hour = 9
            let request = UNNotificationRequest(identifier: "skillbird.daily", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true))
            UNUserNotificationCenter.current().add(request) { error in
                DispatchQueue.main.async { completion(error == nil) }
            }
        }
    }
    static func disable() { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["skillbird.daily"]) }
}

struct LegalView: View {
    enum Kind: Equatable { case privacy, terms }
    let kind: Kind
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PremiumIcon(symbol: kind == .privacy ? "hand.raised.fill" : "doc.text.fill", color: SBColor.gold, size: 64)
                    ScreenHeader(kind == .privacy ? "Privacy Policy" : "Terms of Use", eyebrow: "Skill Bird", subtitle: "Effective September 17, 2026")
                    ForEach(sections, id: \.0) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.0).font(.system(size: 18, weight: .semibold, design: .serif))
                            Text(section.1).font(.subheadline).foregroundStyle(SBColor.secondaryText).lineSpacing(5)
                        }.sbCard()
                    }
                }.padding(22)
            }
            .background(PremiumBackground())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() }.foregroundStyle(SBColor.sky) }
            }
        }
    }

    private var sections: [(String, String)] {
        if kind == .privacy {
            return [
                ("Your data stays on your device", "Skill Bird stores your profile, journeys, challenge progress, XP, settings, and learning history locally on this device. The current release does not create an online account or upload this information to a server."),
                ("Notifications", "If you enable Daily Reminder, iOS grants Skill Bird permission to schedule one local notification. You can disable it at any time in the app or in iOS Settings."),
                ("Analytics and advertising", "This release contains no advertising SDK, third-party analytics, tracking, or sale of personal information."),
                ("Deleting your data", "Use Reset All Progress in Profile to permanently remove locally stored Skill Bird data. Removing the app also removes its local data."),
                ("Contact", "Questions about privacy can be sent to the developer through the support contact on the App Store product page.")
            ]
        }
        return [
            ("Using Skill Bird", "Skill Bird is a self-guided education and productivity tool. You are responsible for choosing suitable learning activities and deadlines."),
            ("No professional advice", "Learning paths are educational suggestions and do not constitute financial, medical, legal, fitness, or other professional advice."),
            ("Progress and rewards", "XP, levels, streaks, birds, and completion statuses are motivational features inside the app. They have no monetary value and cannot be exchanged or transferred."),
            ("Content", "Book, course, and resource names may identify third-party works. Skill Bird does not provide copies of those works and is not affiliated with their authors or publishers unless explicitly stated."),
            ("Availability", "Features may evolve in future releases. We aim to preserve local progress when updating the app, but recommend keeping normal device backups.")
        ]
    }
}
