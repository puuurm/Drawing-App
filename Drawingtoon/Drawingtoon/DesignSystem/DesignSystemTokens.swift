//
//  DesignSystemTokens.swift
//  Drawingtoon
//
//  Created by Heejung Yang on 10/14/25.
//

import SwiftUI

// MARK: - Root Token Namespace
public enum DT { }

// MARK: - Color Helpers
public extension Color {
    /// Create a dynamic color that switches between light/dark values.
    static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }

    /// Hex initializer via UIColor bridge (supports #RGB, #RRGGBB, #AARRGGBB)
    init(hex: String) {
        self = Color(UIColor(hex: hex))
    }
}

public extension UIColor {
    /// Hex initializer (supports #RGB, #RRGGBB, #AARRGGBB)
    convenience init(hex: String) {
        let r, g, b, a: CGFloat
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexSanitized.hasPrefix("#") { hexSanitized.removeFirst() }

        func hexToCGFloat(_ start: Int, _ length: Int) -> CGFloat {
            let startIndex = hexSanitized.index(hexSanitized.startIndex, offsetBy: start)
            let endIndex = hexSanitized.index(startIndex, offsetBy: length)
            let substring = hexSanitized[startIndex..<endIndex]
            let value = UInt64(substring, radix: 16) ?? 0
            return CGFloat(value) / CGFloat((1 << (length * 4)) - 1)
        }

        switch hexSanitized.count {
        case 3: // RGB (12-bit)
            r = hexToCGFloat(0,1)
            g = hexToCGFloat(1,1)
            b = hexToCGFloat(2,1)
            a = 1
        case 6: // RRGGBB (24-bit)
            r = hexToCGFloat(0,2)
            g = hexToCGFloat(2,2)
            b = hexToCGFloat(4,2)
            a = 1
        case 8: // AARRGGBB (32-bit)
            a = hexToCGFloat(0,2)
            r = hexToCGFloat(2,2)
            g = hexToCGFloat(4,2)
            b = hexToCGFloat(6,2)
        default:
            r = 1; g = 0; b = 1; a = 1 // Fallback: magenta to surface invalid hex
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

// MARK: - Color Tokens
public extension DT {
    enum ColorToken {
        // Brand
        public static let brandPrimary = Color.dynamic(
            light: UIColor(hex: "#FF6F3D"),   // vivid orange
            dark:  UIColor(hex: "#FF8A5C")
        )
        public static let brandSecondary = Color.dynamic(
            light: UIColor(hex: "#6C63FF"),   // indigo accent
            dark:  UIColor(hex: "#8B86FF")
        )

        // Backgrounds & Surfaces
        public static let background = Color.dynamic(
            light: UIColor(hex: "#FCFCFD"),
            dark:  UIColor(hex: "#0B0B0C")
        )
        public static let surface = Color.dynamic(
            light: UIColor(hex: "#FFFFFF"),
            dark:  UIColor(hex: "#141416")
        )
        public static let surfaceAlt = Color.dynamic(
            light: UIColor(hex: "#F4F5F7"),
            dark:  UIColor(hex: "#1B1C1E")
        )

        // Text
        public static let textPrimary = Color.dynamic(
            light: UIColor(hex: "#111827"),
            dark:  UIColor(hex: "#F3F4F6")
        )
        public static let textSecondary = Color.dynamic(
            light: UIColor(hex: "#6B7280"),
            dark:  UIColor(hex: "#9CA3AF")
        )
        public static let textInverse = Color.dynamic(
            light: UIColor(hex: "#FFFFFF"),
            dark:  UIColor(hex: "#111111")
        )

        // Status
        public static let success = Color.dynamic(
            light: UIColor(hex: "#16A34A"),
            dark:  UIColor(hex: "#22C55E")
        )
        public static let warning = Color.dynamic(
            light: UIColor(hex: "#EA580C"),
            dark:  UIColor(hex: "#F97316")
        )
        public static let error = Color.dynamic(
            light: UIColor(hex: "#DC2626"),
            dark:  UIColor(hex: "#EF4444")
        )

        // UI Utility
        public static let outline = Color.dynamic(
            light: UIColor(hex: "#E5E7EB"),
            dark:  UIColor(hex: "#2A2D34")
        )
        public static let separator = outline.opacity(0.6)
        public static let overlay = Color.black.opacity(0.25)
    }
}

// MARK: - Spacing Tokens (4pt base scale)
public extension DT {
    enum Spacing {
        public static let xxxs: CGFloat = 2
        public static let xxs:  CGFloat = 4
        public static let xs:   CGFloat = 8
        public static let sm:   CGFloat = 12
        public static let md:   CGFloat = 16
        public static let lg:   CGFloat = 24
        public static let xl:   CGFloat = 32
        public static let xxl:  CGFloat = 40
        public static let xxxl: CGFloat = 56

        // Layout presets
        public static let page = 20.0
        public static let section = 16.0
        public static let card = 12.0
    }
}

// MARK: - Corner Radius Tokens
public extension DT {
    enum Radius {
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
        public static let xl: CGFloat = 24
        /// Use for pill/fully rounded components
        public static let pill: CGFloat = 999
    }
}

// MARK: - Typography Tokens
public extension DT {
    enum FontToken {
        // Size Scale
        public static let sizeXS: CGFloat = 12
        public static let sizeSM: CGFloat = 14
        public static let sizeMD: CGFloat = 16
        public static let sizeLG: CGFloat = 20
        public static let sizeXL: CGFloat = 24
        public static let sizeXXL: CGFloat = 32

        // Presets (Dynamic Type friendly via system styles)
        public static var title: Font { .system(size: sizeXL, weight: .bold, design: .default) }
        public static var headline: Font { .system(size: sizeLG, weight: .semibold, design: .default) }
        public static var body: Font { .system(size: sizeMD, weight: .regular, design: .default) }
        public static var subhead: Font { .system(size: sizeSM, weight: .regular, design: .default) }
        public static var caption: Font { .system(size: sizeXS, weight: .regular, design: .default) }
        public static var mono: Font { .system(size: sizeMD, weight: .regular, design: .monospaced) }
    }
}

// MARK: - Shadow / Elevation Tokens
public extension DT {
    struct ShadowToken: Equatable {
        public let radius: CGFloat
        public let x: CGFloat
        public let y: CGFloat
        public let opacity: CGFloat
        public init(radius: CGFloat, x: CGFloat, y: CGFloat, opacity: CGFloat) {
            self.radius = radius; self.x = x; self.y = y; self.opacity = opacity
        }
    }

    enum Elevation {
        public static let level0 = ShadowToken(radius: 0,  x: 0, y: 0,  opacity: 0)
        public static let level1 = ShadowToken(radius: 8,  x: 0, y: 2,  opacity: 0.08)
        public static let level2 = ShadowToken(radius: 12, x: 0, y: 6,  opacity: 0.12)
        public static let level3 = ShadowToken(radius: 20, x: 0, y: 12, opacity: 0.16)
    }
}

public extension View {
    /// Apply a standard shadow from token.
    func shadow(_ token: DT.ShadowToken) -> some View {
        self.shadow(color: .black.opacity(token.opacity), radius: token.radius, x: token.x, y: token.y)
    }
}

// MARK: - Opacity Tokens
public extension DT {
    enum Opacity {
        public static let disabled: Double = 0.5
        public static let pressed:  Double = 0.8
        public static let overlay:  Double = 0.25
        public static let hidden:   Double = 0.0
    }
}

// MARK: - Animation Tokens
public extension DT {
    enum AnimationToken {
        public static let fast: Animation = .easeOut(duration: 0.15)
        public static let normal: Animation = .easeOut(duration: 0.25)
        public static let slow: Animation = .easeOut(duration: 0.4)
    }
}

// MARK: - Layout Tokens
public extension DT {
    enum Layout {
        public static let minTapSize: CGSize = .init(width: 44, height: 44)
        public static let cardPadding: CGFloat = Spacing.card
        public static let sectionSpacing: CGFloat = Spacing.section
        public static let pagePadding: CGFloat = Spacing.page
    }
}

// MARK: - Example Components (Using Tokens)
public struct FilledButton: View {
    private let title: String
    private let action: () -> Void
    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title; self.action = action
    }
    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(DT.FontToken.headline)
                .foregroundStyle(DT.ColorToken.textInverse)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DT.Spacing.sm)
        }
        .padding(.horizontal, DT.Spacing.sm)
        .background(DT.ColorToken.brandPrimary)
        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.l, style: .continuous))
        .shadow(DT.Elevation.level1)
        .contentShape(Rectangle())
        .accessibilityLabel(Text(title))
        .frame(minHeight: DT.Layout.minTapSize.height)
    }
}

public struct CardView<Content: View>: View {
    private let content: Content
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: DT.Spacing.sm) {
            content
        }
        .padding(DT.Spacing.card)
        .background(DT.ColorToken.surface)
        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.l, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DT.Radius.l, style: .continuous)
                .strokeBorder(DT.ColorToken.outline, lineWidth: 1)
        )
        .shadow(DT.Elevation.level0)
    }
}

// MARK: - Quick Preview (for Xcode Canvas)
#if DEBUG
struct DesignSystemTokens_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DT.Spacing.lg) {
                Text("DrawingToon Tokens")
                    .font(DT.FontToken.title)
                    .foregroundStyle(DT.ColorToken.textPrimary)

                HStack {
                    FilledButton("새 프로젝트") {}
                    FilledButton("불러오기") {}
                }

                CardView {
                    Text("Card Title").font(DT.FontToken.headline).foregroundStyle(DT.ColorToken.textPrimary)
                    Text("This is a body text using tokenized typography and colors. ")
                        .font(DT.FontToken.body)
                        .foregroundStyle(DT.ColorToken.textSecondary)
                }
            }
            .padding(DT.Spacing.page)
            .background(DT.ColorToken.background)
        }
        .previewDisplayName("Tokens Preview")
    }
}
#endif
