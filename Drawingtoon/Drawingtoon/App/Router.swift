//
//  Router.swift
//  Drawingtoon
//
//  Created by Heejung Yang on 10/14/25.
//

import SwiftUI

/// Navigation destinations used across the app.
public enum Route: Hashable {
    case editor(ProjectEntity)
    case settings
}

/// Observable router holding a NavigationPath. Share via `.environmentObject(router)`.
public final class Router: ObservableObject {
    @Published public var path = NavigationPath()
    public init() {}

    @MainActor
    public func push(_ route: Route) {
        withAnimation(.easeOut(duration: 0.25)) { path.append(route) }
    }

    @MainActor
    public func pop() {
        withAnimation(.easeOut(duration: 0.25)) {
            if !path.isEmpty { path.removeLast() }
        }
    }

    @MainActor
    public func popToRoot() {
        withAnimation(.easeOut(duration: 0.25)) { path.removeLast(path.count) }
    }
}

extension ProjectEntity: Hashable {
    public static func == (lhs: ProjectEntity, rhs: ProjectEntity) -> Bool {
        lhs.id == rhs.id
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
