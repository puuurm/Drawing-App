//
//  Components.swift
//  Drawingtoon
//
//  Created by Heejung Yang on 10/14/25.
//

import SwiftUI

// MARK: - Helpers
public extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}

// MARK: - Buttons
public struct PrimaryButton: View {
    private let title: String
    private let leading: Image?
    private let trailing: Image?
    private let action: () -> Void

    public init(_ title: String, leading: Image? = nil, trailing: Image? = nil, action: @escaping () -> Void) {
        self.title = title
        self.leading = leading
        self.trailing = trailing
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: DT.Spacing.xs) {
                if let leading { leading.imageScale(.medium) }
                Text(title).font(DT.FontToken.headline)
                if let trailing { trailing.imageScale(.medium) }
            }
            .foregroundStyle(DT.ColorToken.textInverse)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DT.Spacing.sm)
        }
        .padding(.horizontal, DT.Spacing.sm)
        .background(DT.ColorToken.brandPrimary)
        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.l, style: .continuous))
        .shadow(DT.Elevation.level1)
        .frame(minHeight: DT.Layout.minTapSize.height)
        .contentShape(Rectangle())
    }
}

public struct SecondaryButton: View {
    private let title: String
    private let action: () -> Void

    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title; self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(DT.FontToken.headline)
                .foregroundStyle(DT.ColorToken.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DT.Spacing.sm)
        }
        .padding(.horizontal, DT.Spacing.sm)
        .background(DT.ColorToken.surface)
        .overlay(
            RoundedRectangle(cornerRadius: DT.Radius.l, style: .continuous)
                .stroke(DT.ColorToken.outline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.l, style: .continuous))
        .shadow(DT.Elevation.level0)
        .frame(minHeight: DT.Layout.minTapSize.height)
        .contentShape(Rectangle())
    }
}

public struct GhostButton: View {
    private let title: String
    private let action: () -> Void

    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title; self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(DT.FontToken.body)
                .foregroundStyle(DT.ColorToken.brandPrimary)
                .padding(.horizontal, DT.Spacing.sm)
                .padding(.vertical, DT.Spacing.xs)
        }
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}

public struct IconButton: View {
    private let systemName: String
    private let action: () -> Void
    private let isFilled: Bool

    public init(_ systemName: String, isFilled: Bool = false, action: @escaping () -> Void) {
        self.systemName = systemName
        self.isFilled = isFilled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .imageScale(.medium)
                .frame(width: 36, height: 36)
                .foregroundStyle(isFilled ? DT.ColorToken.textInverse : DT.ColorToken.textPrimary)
                .background(
                    Group {
                        if isFilled { DT.ColorToken.brandPrimary } else { DT.ColorToken.surface }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DT.Radius.m, style: .continuous)
                        .stroke(DT.ColorToken.outline, lineWidth: isFilled ? 0 : 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: DT.Radius.m, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Cards
public struct TappableCard<Content: View>: View {
    private let content: Content
    private let onTap: () -> Void

    public init(onTap: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onTap = onTap
        self.content = content()
    }

    public var body: some View {
        CardBase { content }
            .onTapGesture(perform: onTap)
            .contentShape(Rectangle())
    }
}

public struct CardBase<Content: View>: View {
    private let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View {
        VStack(alignment: .leading, spacing: DT.Spacing.sm) { content }
            .padding(DT.Spacing.card)
            .background(DT.ColorToken.surface)
            .clipShape(RoundedRectangle(cornerRadius: DT.Radius.l, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DT.Radius.l, style: .continuous)
                    .stroke(DT.ColorToken.outline, lineWidth: 1)
            )
    }
}

// MARK: - Inputs
public struct LabeledTextField: View {
    private let label: String
    @Binding private var text: String
    private var placeholder: String
    private var keyboard: UIKeyboardType

    public init(_ label: String, text: Binding<String>, placeholder: String = "", keyboard: UIKeyboardType = .default) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
        self.keyboard = keyboard
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DT.Spacing.xs) {
            Text(label)
                .font(DT.FontToken.subhead)
                .foregroundStyle(DT.ColorToken.textSecondary)
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .padding(.vertical, DT.Spacing.sm)
                .padding(.horizontal, DT.Spacing.md)
                .background(DT.ColorToken.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: DT.Radius.m, style: .continuous)
                        .stroke(DT.ColorToken.outline, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: DT.Radius.m, style: .continuous))
        }
    }
}

public struct SearchBar: View {
    @Binding private var text: String
    public init(text: Binding<String>) { self._text = text }
    public var body: some View {
        HStack(spacing: DT.Spacing.xs) {
            Image(systemName: "magnifyingglass").foregroundStyle(DT.ColorToken.textSecondary)
            TextField("검색", text: $text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DT.ColorToken.textSecondary)
                }
            }
        }
        .padding(.vertical, DT.Spacing.sm)
        .padding(.horizontal, DT.Spacing.md)
        .background(DT.ColorToken.surface)
        .overlay(
            RoundedRectangle(cornerRadius: DT.Radius.m, style: .continuous)
                .stroke(DT.ColorToken.outline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.m, style: .continuous))
    }
}

// MARK: - Section Header
public struct SectionHeader: View {
    private let title: String
    private let subtitle: String?
    private let trailing: AnyView?

    public init(_ title: String, subtitle: String? = nil, trailing: AnyView? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DT.FontToken.headline)
                    .foregroundStyle(DT.ColorToken.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(DT.FontToken.caption)
                        .foregroundStyle(DT.ColorToken.textSecondary)
                }
            }
            Spacer()
            if let trailing { trailing }
        }
        .padding(.horizontal, DT.Spacing.page)
        .padding(.vertical, DT.Spacing.sm)
        .background(.clear)
    }
}

// MARK: - Tag / Chip
public struct TagChip: View {
    private let text: String
    private let isSelected: Bool

    public init(_ text: String, isSelected: Bool = false) {
        self.text = text
        self.isSelected = isSelected
    }

    public var body: some View {
        Text(text)
            .font(DT.FontToken.subhead)
            .padding(.horizontal, DT.Spacing.sm)
            .padding(.vertical, DT.Spacing.xs)
            .foregroundStyle(isSelected ? DT.ColorToken.textInverse : DT.ColorToken.textPrimary)
            .background(isSelected ? DT.ColorToken.brandPrimary : DT.ColorToken.surfaceAlt)
            .clipShape(Capsule())
    }
}

// MARK: - Divider Tokenized
public struct TokenDivider: View {
    public init() {}
    public var body: some View {
        Rectangle()
            .fill(DT.ColorToken.outline)
            .frame(height: 1)
            .opacity(0.7)
    }
}

// MARK: - Toast
public struct ToastConfig: Equatable {
    public enum Style { case info, success, warning, error }
    public var style: Style = .info
    public var title: String
    public var message: String? = nil
    public var duration: TimeInterval = 2.0
    public init(style: Style = .info, title: String, message: String? = nil, duration: TimeInterval = 2.0) {
        self.style = style; self.title = title; self.message = message; self.duration = duration
    }
}

public struct ToastView: View {
    public let config: ToastConfig
    public var body: some View {
        HStack(alignment: .top, spacing: DT.Spacing.sm) {
            Image(systemName: iconName)
                .imageScale(.medium)
            VStack(alignment: .leading, spacing: 2) {
                Text(config.title).font(DT.FontToken.headline)
                if let msg = config.message { Text(msg).font(DT.FontToken.caption) }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(DT.ColorToken.textInverse)
        .padding(DT.Spacing.md)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.l, style: .continuous))
        .shadow(DT.Elevation.level2)
        .padding(DT.Spacing.page)
    }

    private var backgroundColor: Color {
        switch config.style {
        case .info: return .black.opacity(0.8)
        case .success: return DT.ColorToken.success
        case .warning: return DT.ColorToken.warning
        case .error: return DT.ColorToken.error
        }
    }

    private var iconName: String {
        switch config.style {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }
}

public struct ToastPresenterModifier: ViewModifier {
    @Binding var config: ToastConfig?
    public func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            if let cfg = config { ToastView(config: cfg).transition(.move(edge: .top).combined(with: .opacity)) }
        }
        .animation(DT.AnimationToken.normal, value: config)
        .onChange(of: config) { _, newValue in
            guard newValue != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + (newValue!.duration)) {
                withAnimation { config = nil }
            }
        }
    }
}

public extension View {
    func toast(_ config: Binding<ToastConfig?>) -> some View {
        self.modifier(ToastPresenterModifier(config: config))
    }
}

// MARK: - Loading Indicator
public struct DTProgressStyle: ProgressViewStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: DT.Spacing.sm) {
            ProgressView()
                .progressViewStyle(.circular)
            if let label = Mirror(reflecting: configuration).descendant("label") as? Text {
                label.font(DT.FontToken.subhead).foregroundStyle(DT.ColorToken.textSecondary)
            }
        }
        .padding(DT.Spacing.card)
        .background(DT.ColorToken.surface)
        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.m, style: .continuous))
        .shadow(DT.Elevation.level1)
    }
}

// MARK: - Example Previews
#if DEBUG
struct Components_Previews: PreviewProvider {
    struct Demo: View {
        @State private var search = ""
        @State private var toastCfg: ToastConfig? = nil
        @State private var name = ""

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: DT.Spacing.lg) {
                    SectionHeader("버튼")
                    PrimaryButton("기본 버튼", leading: Image(systemName: "plus")) { toastCfg = .init(style: .success, title: "생성됨") }
                    SecondaryButton("보조 버튼") {}
                    HStack { GhostButton("텍스트 버튼") {}; IconButton("square.and.arrow.up") {} }

                    SectionHeader("입력")
                    SearchBar(text: $search)
                    LabeledTextField("프로젝트 이름", text: $name, placeholder: "예: 샘플")

                    SectionHeader("카드")
                    TappableCard(onTap: { toastCfg = .init(style: .info, title: "카드 탭") }) {
                        HStack {
                            TagChip("웹툰", isSelected: true)
                            TagChip("샘플")
                        }
                        Text("내용 미리보기 영역입니다.")
                            .font(DT.FontToken.body)
                            .foregroundStyle(DT.ColorToken.textSecondary)
                    }

                    SectionHeader("로딩 & 토스트")
                    ProgressView("업로드 중...")
                        .progressViewStyle(DTProgressStyle())
                }
                .padding(DT.Spacing.page)
            }
            .background(DT.ColorToken.background)
            .toast($toastCfg)
        }
    }

    static var previews: some View { Demo() }
}
#endif
