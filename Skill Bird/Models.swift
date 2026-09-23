import Foundation

enum ChallengeType: String, Codable, CaseIterable {
    case book = "BOOK", course = "COURSE", practice = "PRACTICE", project = "PROJECT"
    case milestone = "MILESTONE", finalProject = "FINAL PROJECT"
    var icon: String {
        switch self {
        case .book: return "books.vertical.fill"
        case .course: return "graduationcap.fill"
        case .practice: return "figure.run"
        case .project: return "hammer.fill"
        case .milestone: return "flag.checkered"
        case .finalProject: return "crown.fill"
        }
    }
    var islandAsset: String {
        switch self {
        case .book: return "Island_BookLibrary"
        case .course: return "Island_CourseAcademy"
        case .practice: return "Island_PracticeGround"
        case .project: return "Island_ProjectWorkshop"
        case .milestone: return "Island_MilestoneSanctuary"
        case .finalProject: return "Island_FinalCastle"
        }
    }
    var challengeAsset: String {
        switch self {
        case .book: return "Challenge_Book"
        case .course: return "Challenge_Course"
        case .practice: return "Challenge_Practice"
        case .project: return "Challenge_Project"
        case .milestone: return "Challenge_Milestone"
        case .finalProject: return "Challenge_FinalProject"
        }
    }
}

struct DeadlineOption: Codable, Hashable, Identifiable {
    let label: String
    let days: Int
    let xp: Int
    var id: Int { days }
}

struct Challenge: Codable, Identifiable, Hashable {
    let id: String
    let type: ChallengeType
    let title: String
    let source: String
    let description: String
    let learning: [String]
    let deadlines: [DeadlineOption]
    let lateReward: Int
}

struct Skill: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let category: String
    let icon: String
    let description: String
    let difficulty: String
    let estimatedWeeks: Int
    let challenges: [Challenge]

    var emblemAsset: String {
        switch id {
        case "ios": return "Skill_iOS_Emblem"
        case "productivity": return "Skill_Productivity_Emblem"
        case "english": return "Skill_English_Emblem"
        case "programming": return "Skill_Programming_Emblem"
        case "design": return "Skill_Design_Emblem"
        case "finance": return "Skill_Finance_Emblem"
        case "investing": return "Skill_Investing_Emblem"
        case "speaking": return "Skill_PublicSpeaking_Emblem"
        case "leadership": return "Skill_Leadership_Emblem"
        case "marketing": return "Skill_Marketing_Emblem"
        case "business": return "Skill_Entrepreneurship_Emblem"
        case "psychology": return "Skill_Psychology_Emblem"
        case "writing": return "Skill_Writing_Emblem"
        case "fitness": return "Skill_Fitness_Emblem"
        case "photo": return "Skill_Photography_Emblem"
        default: return "Skill_Productivity_Emblem"
        }
    }
}

struct ChallengeProgress: Codable, Equatable {
    var progress: Double = 0
    var selectedDays: Int?
    var potentialXP: Int?
    var startedAt: Date?
    var deadline: Date?
    var completedAt: Date?
    var earnedXP: Int = 0
    var isStarted: Bool { startedAt != nil }
    var isCompleted: Bool { completedAt != nil }
}

struct ActivityEvent: Codable, Identifiable {
    let id: UUID
    let date: Date
    let title: String
    let detail: String
    let icon: String
    init(title: String, detail: String, icon: String, date: Date = Date()) {
        id = UUID(); self.date = date; self.title = title; self.detail = detail; self.icon = icon
    }
}

struct Bird: Identifiable, Hashable {
    let id: String
    let name: String
    let personality: String
    let quote: String
    let requiredXP: Int
    let rarity: String
    let symbol: String

    private var assetStem: String {
        switch id {
        case "bluejay": return "BlueJay"
        case "snowowl": return "SnowOwl"
        case "goldeneagle": return "GoldenEagle"
        default: return name.replacingOccurrences(of: " ", with: "")
        }
    }
    var portraitAsset: String { "Bird_\(assetStem)_Portrait" }
    var flightAsset: String { "Bird_\(assetStem)_Flight" }
    var hasFlightAsset: Bool { true }
}

enum SampleData {
    static let deadlines = [
        DeadlineOption(label: "RELAXED", days: 14, xp: 100),
        DeadlineOption(label: "STANDARD", days: 10, xp: 200),
        DeadlineOption(label: "AMBITIOUS", days: 7, xp: 350),
        DeadlineOption(label: "HARD", days: 5, xp: 500),
        DeadlineOption(label: "EXTREME", days: 3, xp: 800)
    ]

    static let birds = [
        Bird(id: "owl", name: "Owl", personality: "The Curious One", quote: "Every expert started by asking questions.", requiredXP: 0, rarity: "Common", symbol: "bird.fill"),
        Bird(id: "bluejay", name: "Blue Jay", personality: "The Bright Mind", quote: "Curiosity makes every path visible.", requiredXP: 1_000, rarity: "Common", symbol: "bird.fill"),
        Bird(id: "toucan", name: "Toucan", personality: "The Explorer", quote: "New skills open new worlds.", requiredXP: 2_500, rarity: "Rare", symbol: "bird.fill"),
        Bird(id: "parrot", name: "Parrot", personality: "The Communicator", quote: "What you share, you remember.", requiredXP: 5_000, rarity: "Rare", symbol: "bird.fill"),
        Bird(id: "pelican", name: "Pelican", personality: "The Patient One", quote: "Carry the lesson until it becomes yours.", requiredXP: 8_500, rarity: "Epic", symbol: "bird.fill"),
        Bird(id: "falcon", name: "Falcon", personality: "The Focused One", quote: "Focus turns motion into progress.", requiredXP: 13_000, rarity: "Epic", symbol: "bird.fill"),
        Bird(id: "eagle", name: "Eagle", personality: "The Master", quote: "Discipline turns knowledge into power.", requiredXP: 20_000, rarity: "Legendary", symbol: "bird.fill"),
        Bird(id: "peacock", name: "Peacock", personality: "The Creator", quote: "Mastery deserves to be seen.", requiredXP: 30_000, rarity: "Legendary", symbol: "bird.fill"),
        Bird(id: "snowowl", name: "Snow Owl", personality: "The Sage", quote: "Wisdom grows in quiet practice.", requiredXP: 45_000, rarity: "Mythic", symbol: "bird.fill"),
        Bird(id: "goldeneagle", name: "Golden Eagle", personality: "The Achiever", quote: "Rise above every limit.", requiredXP: 65_000, rarity: "Mythic", symbol: "bird.fill"),
        Bird(id: "phoenix", name: "Phoenix", personality: "The Legendary Learner", quote: "You didn't just learn. You transformed.", requiredXP: 100_000, rarity: "Ultimate", symbol: "flame.fill")
    ]

    static let skills: [Skill] = {
        let definitions: [(String, String, String, String, String, [String])] = [
            ("ios", "iOS Development", "Career", "iphone", "Build real iOS apps from fundamentals to a complete product.", ["Swift Fundamentals", "The Swift Programming Language", "20 Swift Exercises", "Build Your First iOS App", "Networking & REST APIs", "Create a Weather App", "SwiftUI Fundamentals", "Build Your Own iOS App"]),
            ("productivity", "Productivity", "Mind", "bolt.fill", "Build better systems for focus, habits, and execution.", ["Habits 101", "Atomic Habits", "7-Day Habit Practice", "Deep Work", "Time Management", "Focus Sprint", "Build Your Routine", "Your Productivity System"]),
            ("english", "English", "Languages", "character.book.closed.fill", "Grow practical vocabulary, comprehension, and speaking confidence.", ["Find Your Level", "Core Vocabulary", "Listening Basics", "Daily Speaking", "Grammar in Context", "Watch & Retell", "Conversation Week", "English Portfolio"]),
            ("programming", "Programming Fundamentals", "Career", "chevron.left.forwardslash.chevron.right", "Learn the core ideas behind modern software development.", ["How Computers Think", "Variables & Types", "Control Flow", "Function Practice", "Data Structures", "Debugging", "Build a CLI Tool", "Your First Program"]),
            ("design", "UI/UX Design", "Creativity", "scribble.variable", "Design useful, clear, and delightful digital experiences.", ["Design Principles", "User Research", "Visual Hierarchy", "Wireframe Practice", "Color & Type", "Prototype an App", "Usability Testing", "Portfolio Case Study"]),
            ("finance", "Personal Finance", "Money", "banknote.fill", "Build a calm, practical system for your money.", ["Money Snapshot", "Budget Basics", "Emergency Fund", "Track for 7 Days", "Debt Strategy", "Build a Budget", "Future Planning", "Personal Money Plan"]),
            ("investing", "Investing", "Money", "chart.line.uptrend.xyaxis", "Understand risk, returns, and long-term investing habits.", ["Investing Basics", "Risk & Return", "Index Funds", "Market Practice", "Asset Allocation", "Draft a Portfolio", "Investor Behavior", "Investment Policy"]),
            ("speaking", "Public Speaking", "Career", "mic.fill", "Speak with structure, clarity, and confidence.", ["Know Your Audience", "Talk Structure", "Voice & Pace", "Daily Delivery", "Storytelling", "Record a Talk", "Handle Questions", "Final Presentation"]),
            ("leadership", "Leadership", "Career", "person.3.fill", "Lead people with clarity, trust, and useful feedback.", ["Leadership Mindset", "Build Trust", "Clear Decisions", "Feedback Practice", "Delegation", "Run a 1:1", "Team Alignment", "Leadership Playbook"]),
            ("marketing", "Marketing", "Career", "megaphone.fill", "Learn positioning, customer insight, and campaign thinking.", ["Marketing Basics", "Know the Customer", "Positioning", "Message Practice", "Channels", "Build a Campaign", "Measure Results", "Go-to-Market Plan"]),
            ("business", "Entrepreneurship", "Career", "building.2.fill", "Turn a promising problem into a tested business concept.", ["Founder Mindset", "Find a Problem", "Customer Interviews", "Idea Validation", "Business Models", "Build an MVP", "First Customers", "Launch Plan"]),
            ("psychology", "Psychology", "Mind", "brain.head.profile", "Explore how people think, feel, learn, and decide.", ["Psychology Basics", "Memory", "Motivation", "Observation Practice", "Cognitive Biases", "Behavior Journal", "Social Psychology", "Insight Project"]),
            ("writing", "Writing", "Creativity", "pencil.line", "Write with clarity, voice, and persuasive structure.", ["Writing Clearly", "Find Your Voice", "Story Structure", "Daily Pages", "Editing", "Write an Essay", "Publish & Learn", "Writing Portfolio"]),
            ("fitness", "Fitness Fundamentals", "Health", "figure.strengthtraining.traditional", "Create a safe and sustainable foundation for movement.", ["Movement Basics", "Recovery", "Strength 101", "7-Day Movement", "Cardio Basics", "Build a Workout", "Consistency", "Personal Fitness Plan"]),
            ("photo", "Photography", "Creativity", "camera.fill", "Learn composition, light, and visual storytelling.", ["Know Your Camera", "Composition", "Understanding Light", "Photo Walk", "Color & Mood", "Portrait Project", "Edit with Intent", "Photo Story"])
        ]
        return definitions.map { makeSkill(id: $0.0, title: $0.1, category: $0.2, icon: $0.3, description: $0.4, titles: $0.5) }
    }()

    private static func makeSkill(id: String, title: String, category: String, icon: String, description: String, titles: [String]) -> Skill {
        let types: [ChallengeType] = [.course, .book, .practice, .project, .course, .project, .milestone, .finalProject]
        let challenges = titles.enumerated().map { index, title in
            Challenge(id: "\(id)_\(index)", type: types[index], title: title,
                      source: index == 1 ? "Selected reading" : "Skill Bird Path",
                      description: "A focused step designed to turn knowledge into practical progress.",
                      learning: ["Core concepts", "Practical application", "A repeatable learning habit"],
                      deadlines: index == 2 ? Array(deadlines.dropFirst(2)) : deadlines, lateReward: 25)
        }
        return Skill(id: id, title: title, category: category, icon: icon, description: description, difficulty: "Beginner → Intermediate", estimatedWeeks: 8, challenges: challenges)
    }
}
