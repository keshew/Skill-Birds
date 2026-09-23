import SwiftUI
import UIKit
import AudioToolbox
import UserNotifications

@MainActor
final class AppState: ObservableObject {
    @Published var hasOnboarded = false
    @Published var activeSkillID: String?
    @Published var challengeProgress: [String: ChallengeProgress] = [:]
    @Published var xp = 0
    @Published var currentStreak = 0
    @Published var bestStreak = 0
    @Published var equippedBirdID = "owl"
    @Published var activities: [ActivityEvent] = []
    @Published var soundEnabled = true
    @Published var hapticsEnabled = true
    @Published var remindersEnabled = false
    @Published var displayName = "Learner"

    private let defaults: UserDefaults
    private let calendar = Calendar.current
    var activeSkill: Skill? { SampleData.skills.first { $0.id == activeSkillID } }
    var needsOnboarding: Bool { !hasOnboarded || activeSkill == nil }
    var level: Int { max(1, xp / 1_000 + 1) }
    var levelProgress: Double { Double(xp % 1_000) / 1_000 }
    var equippedBird: Bird { SampleData.birds.first { $0.id == equippedBirdID } ?? SampleData.birds[0] }
    var unlockedBirds: [Bird] { SampleData.birds.filter { xp >= $0.requiredXP } }
    var completedCount: Int { challengeProgress.values.filter(\.isCompleted).count }
    var onTimeCount: Int {
        challengeProgress.values.filter { value in
            guard let completed = value.completedAt, let deadline = value.deadline else { return false }
            return completed <= deadline
        }.count
    }
    var lateCount: Int { max(0, completedCount - onTimeCount) }
    var onTimeRate: Int { completedCount == 0 ? 0 : Int((Double(onTimeCount) / Double(completedCount) * 100).rounded()) }

    init(preview: Bool = false) {
        defaults = preview ? UserDefaults(suiteName: "SkillBirdPreview")! : .standard
        if preview {
            hasOnboarded = true; activeSkillID = "ios"; xp = 1_450; currentStreak = 6; bestStreak = 9
            challengeProgress["ios_0"] = ChallengeProgress(progress: 1, selectedDays: 7, potentialXP: 350, startedAt: Date().addingTimeInterval(-300_000), deadline: Date().addingTimeInterval(-40_000), completedAt: Date().addingTimeInterval(-80_000), earnedXP: 350)
            challengeProgress["ios_1"] = ChallengeProgress(progress: 0.42, selectedDays: 7, potentialXP: 350, startedAt: Date().addingTimeInterval(-100_000), deadline: Date().addingTimeInterval(500_000), completedAt: nil, earnedXP: 0)
        } else { load() }
    }

    func beginJourney(_ skill: Skill) {
        activeSkillID = skill.id; hasOnboarded = true
        activities.insert(ActivityEvent(title: "Journey started", detail: skill.title, icon: "map.fill"), at: 0)
        save()
    }

    func progress(for challenge: Challenge) -> ChallengeProgress { challengeProgress[challenge.id] ?? ChallengeProgress() }

    func isUnlocked(_ challenge: Challenge, in skill: Skill) -> Bool {
        guard let index = skill.challenges.firstIndex(of: challenge) else { return false }
        return index == 0 || progress(for: skill.challenges[index - 1]).isCompleted
    }

    func start(_ challenge: Challenge, option: DeadlineOption) {
        var value = progress(for: challenge)
        value.selectedDays = option.days; value.potentialXP = option.xp; value.startedAt = Date()
        value.deadline = calendar.date(byAdding: .day, value: option.days, to: Date())
        challengeProgress[challenge.id] = value
        activities.insert(ActivityEvent(title: "Challenge accepted", detail: "\(challenge.title) · \(option.days) days", icon: "flag.fill"), at: 0)
        touchStreak(); feedback(.medium); save()
    }

    func update(_ challenge: Challenge, to progress: Double) {
        var value = self.progress(for: challenge); let oldPercent = Int(value.progress * 100)
        value.progress = min(max(progress, 0), 1); challengeProgress[challenge.id] = value
        activities.insert(ActivityEvent(title: challenge.title, detail: "Progress \(oldPercent)% → \(Int(value.progress * 100))%", icon: "arrow.up.right"), at: 0)
        touchStreak(); feedback(.light); save()
    }

    @discardableResult func complete(_ challenge: Challenge) -> Int {
        var value = progress(for: challenge); let now = Date()
        let earned = (value.deadline.map { now <= $0 } ?? true) ? (value.potentialXP ?? 100) : challenge.lateReward
        value.progress = 1; value.completedAt = now; value.earnedXP = earned
        challengeProgress[challenge.id] = value; xp += earned
        activities.insert(ActivityEvent(title: "Challenge completed", detail: "\(challenge.title) · +\(earned) XP", icon: "checkmark.seal.fill"), at: 0)
        touchStreak(); feedback(.success); save(); return earned
    }

    func equip(_ bird: Bird) {
        guard xp >= bird.requiredXP else { return }
        equippedBirdID = bird.id; feedback(.medium); save()
    }

    func resetAll() {
        hasOnboarded = false; activeSkillID = nil; challengeProgress = [:]; xp = 0
        currentStreak = 0; bestStreak = 0; equippedBirdID = "owl"; activities = []
        soundEnabled = true; hapticsEnabled = true; remindersEnabled = false; displayName = "Learner"
        defaults.removeObject(forKey: Keys.state)
        defaults.removeObject(forKey: Keys.lastActivity)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["skillbird.daily"])
    }

    private func touchStreak() {
        let last = defaults.object(forKey: Keys.lastActivity) as? Date
        if let last {
            if calendar.isDateInToday(last) { return }
            currentStreak = calendar.isDateInYesterday(last) ? currentStreak + 1 : 1
        } else { currentStreak = 1 }
        bestStreak = max(bestStreak, currentStreak); defaults.set(Date(), forKey: Keys.lastActivity)
    }

    private enum Feedback { case light, medium, success }
    private func feedback(_ kind: Feedback) {
        if hapticsEnabled {
            switch kind {
            case .light: UIImpactFeedbackGenerator(style: .light).impactOccurred()
            case .medium: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
        if soundEnabled {
            switch kind {
            case .light: AudioServicesPlaySystemSound(1104)
            case .medium: AudioServicesPlaySystemSound(1103)
            case .success: AudioServicesPlaySystemSound(1025)
            }
        }
    }

    private struct SavedState: Codable {
        let hasOnboarded: Bool; let activeSkillID: String?; let challengeProgress: [String: ChallengeProgress]
        let xp: Int; let currentStreak: Int; let bestStreak: Int; let equippedBirdID: String
        let activities: [ActivityEvent]; let soundEnabled: Bool; let hapticsEnabled: Bool
        let remindersEnabled: Bool; let displayName: String
    }
    private enum Keys { static let state = "skillbird.state.v1"; static let lastActivity = "skillbird.lastActivity" }

    func save() {
        let value = SavedState(hasOnboarded: hasOnboarded, activeSkillID: activeSkillID, challengeProgress: challengeProgress, xp: xp, currentStreak: currentStreak, bestStreak: bestStreak, equippedBirdID: equippedBirdID, activities: Array(activities.prefix(100)), soundEnabled: soundEnabled, hapticsEnabled: hapticsEnabled, remindersEnabled: remindersEnabled, displayName: displayName)
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: Keys.state) }
    }

    private func load() {
        guard let data = defaults.data(forKey: Keys.state), let value = try? JSONDecoder().decode(SavedState.self, from: data) else { return }
        hasOnboarded = value.hasOnboarded; activeSkillID = value.activeSkillID; challengeProgress = value.challengeProgress
        xp = value.xp; currentStreak = value.currentStreak; bestStreak = value.bestStreak; equippedBirdID = value.equippedBirdID
        activities = value.activities; soundEnabled = value.soundEnabled; hapticsEnabled = value.hapticsEnabled
        remindersEnabled = value.remindersEnabled; displayName = value.displayName
        if let last = defaults.object(forKey: Keys.lastActivity) as? Date,
           !calendar.isDateInToday(last), !calendar.isDateInYesterday(last) {
            currentStreak = 0
        }

        // Older or partially written state can claim onboarding was completed
        // without containing a valid journey. Recover by showing onboarding.
        if hasOnboarded && activeSkill == nil {
            hasOnboarded = false
            save()
        }
    }
}
