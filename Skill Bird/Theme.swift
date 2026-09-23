import SwiftUI

enum SBColor {
    static let background = Color(hex: 0x070B14)
    static let surface = Color(hex: 0x111B2E)
    static let elevated = Color(hex: 0x192943)
    static let sky = Color(hex: 0x73D5FF)
    static let gold = Color(hex: 0xEBCB86)
    static let champagne = Color(hex: 0xFFE4AA)
    static let sapphire = Color(hex: 0x3A7BFF)
    static let violet = Color(hex: 0x8171FF)
    static let success = Color(hex: 0x58D68D)
    static let danger = Color(hex: 0xFF6B6B)
    static let cloud = Color(hex: 0xDDE8F0)
    static let text = Color(hex: 0xF7F9FC)
    static let secondaryText = Color(hex: 0x9DAEC1)
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255, opacity: alpha)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = SBColor.sky
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold, design: .rounded)).tracking(1.1)
            .foregroundStyle(SBColor.background).frame(maxWidth: .infinity).padding(.vertical, 18)
            .background {
                ZStack {
                    LinearGradient(colors: [color.opacity(0.92), color.opacity(0.72), .white.opacity(0.94)], startPoint: .leading, endPoint: .trailing)
                    LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.32), lineWidth: 0.8))
            .shadow(color: color.opacity(configuration.isPressed ? 0.12 : 0.3), radius: 20, y: 9)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
    }
}

struct SBCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(19)
            .background {
                ZStack {
                    LinearGradient(colors: [Color.white.opacity(0.075), Color.white.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    SBColor.surface.opacity(0.82)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(LinearGradient(colors: [.white.opacity(0.16), SBColor.sky.opacity(0.03), .white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8))
            .shadow(color: .black.opacity(0.24), radius: 20, y: 12)
    }
}

extension View { func sbCard() -> some View { modifier(SBCardModifier()) } }

struct SBProgressBar: View {
    let value: Double
    var color: Color = SBColor.sky
    var height: CGFloat = 9
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.black.opacity(0.32)).overlay(Capsule().stroke(.white.opacity(0.06)))
                Capsule().fill(LinearGradient(colors: [color.opacity(0.72), color, .white.opacity(0.92)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, geometry.size.width * min(max(value, 0), 1)))
                    .shadow(color: color.opacity(0.45), radius: 7)
            }
        }.frame(height: height)
    }
}

struct ScreenHeader: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?
    init(_ title: String, eyebrow: String? = nil, subtitle: String? = nil) {
        self.title = title; self.eyebrow = eyebrow; self.subtitle = subtitle
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let eyebrow {
                Text(eyebrow.uppercased()).font(.caption.weight(.bold)).tracking(1.4).foregroundStyle(SBColor.sky)
            }
            Text(title).font(.system(size: 31, weight: .semibold, design: .serif)).foregroundStyle(SBColor.text)
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(SBColor.secondaryText) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PremiumBackground: View {
    var body: some View {
        ZStack {
            SBColor.background
            RadialGradient(colors: [SBColor.sapphire.opacity(0.17), .clear], center: UnitPoint(x: 0.08, y: 0.08), startRadius: 0, endRadius: 330)
            RadialGradient(colors: [SBColor.violet.opacity(0.11), .clear], center: UnitPoint(x: 0.92, y: 0.38), startRadius: 0, endRadius: 290)
            RadialGradient(colors: [SBColor.sky.opacity(0.065), .clear], center: UnitPoint(x: 0.4, y: 1), startRadius: 0, endRadius: 360)
            Canvas { context, size in
                let points: [(Double, Double, Double)] = [(0.08,0.16,1.2),(0.2,0.42,0.7),(0.85,0.13,1),(0.76,0.32,0.6),(0.93,0.67,1.1),(0.14,0.76,0.8),(0.56,0.1,0.6),(0.62,0.82,0.9)]
                for point in points {
                    let rect = CGRect(x: size.width * point.0, y: size.height * point.1, width: point.2, height: point.2)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.35)))
                }
            }
        }.ignoresSafeArea()
    }
}

struct OrnamentalDivider: View {
    var body: some View {
        HStack(spacing: 9) {
            Rectangle().fill(LinearGradient(colors: [.clear, SBColor.gold.opacity(0.45)], startPoint: .leading, endPoint: .trailing)).frame(height: 0.7)
            Diamond().fill(SBColor.gold).frame(width: 6, height: 6).shadow(color: SBColor.gold.opacity(0.7), radius: 5)
            Rectangle().fill(LinearGradient(colors: [SBColor.gold.opacity(0.45), .clear], startPoint: .leading, endPoint: .trailing)).frame(height: 0.7)
        }
    }
}

struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(); path.move(to: CGPoint(x: rect.midX, y: rect.minY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)); path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY)); path.addLine(to: CGPoint(x: rect.minX, y: rect.midY)); path.closeSubpath(); return path
    }
}

struct PremiumIcon: View {
    let symbol: String
    var color: Color = SBColor.sky
    var size: CGFloat = 50
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3).fill(LinearGradient(colors: [color.opacity(0.2), color.opacity(0.045)], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: size * 0.3).stroke(LinearGradient(colors: [color.opacity(0.48), .white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8)
            Image(systemName: symbol).font(.system(size: size * 0.42, weight: .medium)).foregroundStyle(LinearGradient(colors: [.white, color], startPoint: .top, endPoint: .bottom))
        }.frame(width: size, height: size).shadow(color: color.opacity(0.18), radius: 10, y: 5)
    }
}

struct SkillEmblemView: View {
    let skill: Skill
    var size: CGFloat = 50

    var body: some View {
        Image(skill.emblemAsset)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: SBColor.sky.opacity(0.2), radius: 10, y: 5)
            .accessibilityLabel(skill.title)
    }
}
