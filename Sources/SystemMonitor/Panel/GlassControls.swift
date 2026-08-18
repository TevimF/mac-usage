import SwiftUI

/// Liquid Glass adoption, kept to the standard components.
///
/// The panel itself deliberately draws NO background of its own: NSPopover
/// already provides the window material, and on macOS 26 that material *is*
/// Liquid Glass. Layering our own `.glassEffect()` on top of it was glass
/// over glass — the thing Apple's adoption guide tells you not to do — and
/// it cost an extra blur layer every frame for nothing.
///
/// Glass is therefore reserved for the controls that float above the
/// content, which is where the material is meant to live.

/// Groups adjacent glass controls so the system can blend them as one
/// piece instead of rendering separate, competing capsules.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                HStack(spacing: spacing) { content }
            }
        } else {
            HStack(spacing: spacing) { content }
        }
    }
}

private struct GlassButtonStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.buttonStyle(.glass)
        } else {
            content.buttonStyle(LegacyCapsuleButtonStyle())
        }
    }
}

private struct GlassProminentButtonStyleModifier: ViewModifier {
    var tint: Color

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.buttonStyle(.glassProminent).tint(tint)
        } else {
            content.buttonStyle(LegacyProminentButtonStyle(tint: tint))
        }
    }
}

private struct LegacyCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.primary.opacity(configuration.isPressed ? 0.18 : 0.08)))
    }
}

private struct LegacyProminentButtonStyle: ButtonStyle {
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(tint.opacity(configuration.isPressed ? 1 : 0.85)))
    }
}

extension View {
    func glassButton() -> some View {
        modifier(GlassButtonStyleModifier())
    }

    func glassProminentButton(tint: Color) -> some View {
        modifier(GlassProminentButtonStyleModifier(tint: tint))
    }
}
