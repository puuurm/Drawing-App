//
//  RootView.swift
//  Drawingtoon
//
//  Created by Heejung Yang on 10/14/25.
//

import SwiftUI

// MARK: - RootView
public struct RootView: View {
    @EnvironmentObject private var router: Router
    @Environment(\.scenePhase) private var scenePhase

    public init() {}

    public var body: some View {
        NavigationStack(path: $router.path) {
            GeminiTextPingView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .editor(let project):
                        EditorView(project: project)
                    case .settings:
                        SettingsView()
                    }
                }
                .toolbar { trailingToolbar }
                .background(DT.ColorToken.background)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .inactive {
                // TODO: Add autosave logic or cleanup here if necessary.
            }
        }
    }

    private var trailingToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            IconButton("gearshape") { router.push(.settings) }
        }
    }
}

// MARK: - Settings (Placeholder)
public struct SettingsView: View {
    public init() {}
    public var body: some View {
        Form {
            Section("환경 설정") {
                Toggle("다크 모드 따라가기", isOn: .constant(true))
                Toggle("Haptics", isOn: .constant(true))
            }
        }
        .navigationTitle("설정")
    }
}

// MARK: - Preview
#if DEBUG
struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView().environmentObject(Router())
    }
}
#endif
