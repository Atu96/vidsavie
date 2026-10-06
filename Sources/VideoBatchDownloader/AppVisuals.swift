import SwiftUI

/// Product-wide visual tokens. Brand color is deliberately concentrated in
/// icons, progress, and primary actions; surfaces stay neutral and readable.
enum VBDDesign {
    static let brandPink = Color(red: 0.96, green: 0.22, blue: 0.55)
    static let brandBlue = Color(red: 0.12, green: 0.50, blue: 0.96)
    static let brandViolet = Color(red: 0.50, green: 0.34, blue: 0.92)

    static let radiusSmall: CGFloat = 8
    static let radiusControl: CGFloat = 11
    static let radiusCard: CGFloat = 15
    static let controlHeight: CGFloat = 36
    static let compactControlHeight: CGFloat = 30
    static let iconButtonSize: CGFloat = 38

    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [brandPink, brandViolet, brandBlue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func motion(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.20)
    }
}

let accentGradient = VBDDesign.brandGradient

/// Three predictable surface levels replace screen-specific glass recipes.
struct AppSurface: View {
    enum Level { case raised, control, inset }

    let cornerRadius: CGFloat
    var level: Level = .raised
    var tint: Color? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = colorScheme == .dark
        let fillColors = surfaceColors(dark: dark)
        let border = dark ? Color.white.opacity(0.14) : Color.black.opacity(0.105)
        let highlight = dark ? Color.white.opacity(0.13) : Color.white.opacity(0.78)

        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: fillColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                if let tint {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint.opacity(dark ? 0.075 : 0.055))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(border, lineWidth: 0.8)
            }
            .overlay(alignment: .top) {
                Capsule()
                    .fill(highlight)
                    .frame(height: 0.8)
                    .padding(.horizontal, cornerRadius)
            }
            .shadow(
                color: level == .raised
                    ? (dark ? Color.black.opacity(0.34) : Color(red: 0.10, green: 0.18, blue: 0.32).opacity(0.09))
                    : .clear,
                radius: level == .raised ? 10 : 0,
                y: level == .raised ? 4 : 0
            )
    }

    private func surfaceColors(dark: Bool) -> [Color] {
        if dark {
            switch level {
            case .raised:
                return [
                    Color(red: 0.105, green: 0.145, blue: 0.225).opacity(0.98),
                    Color(red: 0.070, green: 0.100, blue: 0.165).opacity(0.98),
                ]
            case .control:
                return [
                    Color(red: 0.095, green: 0.130, blue: 0.205).opacity(0.94),
                    Color(red: 0.060, green: 0.085, blue: 0.145).opacity(0.94),
                ]
            case .inset:
                return [
                    Color(red: 0.050, green: 0.075, blue: 0.130).opacity(0.96),
                    Color(red: 0.035, green: 0.055, blue: 0.105).opacity(0.96),
                ]
            }
        } else {
            switch level {
            case .raised:
                return [Color.white.opacity(0.96), Color(red: 0.955, green: 0.975, blue: 1.0).opacity(0.94)]
            case .control:
                return [Color.white.opacity(0.88), Color(red: 0.940, green: 0.965, blue: 0.995).opacity(0.82)]
            case .inset:
                return [Color.white.opacity(0.72), Color(red: 0.925, green: 0.950, blue: 0.985).opacity(0.66)]
            }
        }
    }
}

enum AppVisual {
    static func background(theme: String) -> AnyView {
        AnyView(AppGlassCanvas(theme: theme))
    }
}

/// Resolves System from the application's real macOS appearance, never from a
/// window-level override left behind by Dark or Light glass.
enum AppAppearance {
    static func colorScheme(for theme: String) -> ColorScheme {
        switch theme {
        case "light": return .light
        case "dark": return .dark
        default:
            let match = NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua ? .dark : .light
        }
    }

    static func preferredColorScheme(for theme: String) -> ColorScheme? {
        switch theme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    static func windowAppearance(for theme: String) -> NSAppearance? {
        switch theme {
        case "light": return NSAppearance(named: .aqua)
        case "dark": return NSAppearance(named: .darkAqua)
        default: return nil
        }
    }
}

struct AppGlassCanvas: View {
    let theme: String
    @Environment(\.colorScheme) private var colorScheme

    private var usesDarkCanvas: Bool {
        theme == "dark" || (theme == "auto" && colorScheme == .dark)
    }

    var body: some View {
        ZStack {
            if usesDarkCanvas {
                LinearGradient(
                    colors: [
                        Color(red: 0.035, green: 0.055, blue: 0.10),
                        Color(red: 0.055, green: 0.070, blue: 0.13),
                        Color(red: 0.075, green: 0.050, blue: 0.105),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.985, green: 0.992, blue: 1.0),
                        Color(red: 0.945, green: 0.970, blue: 0.995),
                        Color(red: 0.985, green: 0.965, blue: 0.985),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            RadialGradient(
                colors: [VBDDesign.brandBlue.opacity(usesDarkCanvas ? 0.10 : 0.055), .clear],
                center: .topTrailing,
                startRadius: 12,
                endRadius: 420
            )
            RadialGradient(
                colors: [VBDDesign.brandPink.opacity(usesDarkCanvas ? 0.075 : 0.038), .clear],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 380
            )
        }
    }
}

struct MenuBarGlassCanvas: View {
    let theme: String

    var body: some View {
        AppGlassCanvas(theme: theme)
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(minHeight: VBDDesign.controlHeight)
            .background(
                LinearGradient(
                    colors: [tint.opacity(configuration.isPressed ? 0.78 : 0.96), tint.opacity(0.76)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: VBDDesign.radiusControl, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VBDDesign.radiusControl, style: .continuous)
                    .stroke(Color.white.opacity(0.26), lineWidth: 0.8)
            )
            .shadow(color: tint.opacity(configuration.isPressed ? 0.10 : 0.20), radius: 5, y: 2)
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}

/// A compact filled action for dense settings rows. It keeps the same visual
/// language as the primary action without inheriting its larger touch target.
struct AppCompactPrimaryButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .frame(minHeight: VBDDesign.compactControlHeight)
            .background(
                LinearGradient(
                    colors: [tint.opacity(configuration.isPressed ? 0.78 : 0.96), tint.opacity(0.76)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: VBDDesign.radiusSmall, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VBDDesign.radiusSmall, style: .continuous)
                    .stroke(Color.white.opacity(0.24), lineWidth: 0.7)
            )
            .shadow(color: tint.opacity(configuration.isPressed ? 0.08 : 0.16), radius: 3, y: 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    var tint: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 11)
            .frame(minHeight: VBDDesign.compactControlHeight)
            .background(AppSurface(cornerRadius: VBDDesign.radiusSmall, level: .control, tint: tint))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

/// Pointer feedback only: never changes a control's geometry or hit target.
struct AppHoverButtonStyle: ButtonStyle {
    let tint: Color
    var cornerRadius: CGFloat = 11

    func makeBody(configuration: Configuration) -> some View {
        HoverBody(configuration: configuration, tint: tint, cornerRadius: cornerRadius)
    }

    private struct HoverBody: View {
        let configuration: ButtonStyleConfiguration
        let tint: Color
        let cornerRadius: CGFloat
        @State private var hovering = false
        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        private var highlighted: Bool { hovering && isEnabled }

        var body: some View {
            configuration.label
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint.opacity(highlighted ? (colorScheme == .dark ? 0.18 : 0.12) : 0))
                        .allowsHitTesting(false)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(tint.opacity(highlighted ? 0.65 : 0), lineWidth: 1)
                        .allowsHitTesting(false)
                }
                .shadow(color: tint.opacity(highlighted ? (colorScheme == .dark ? 0.24 : 0.14) : 0), radius: 5)
                .opacity(configuration.isPressed && isEnabled ? 0.85 : 1)
                .onHover { hovering = $0 }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: highlighted)
        }
    }
}
