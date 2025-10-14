//
//  HomeView.swift
//  Drawingtoon
//
//  Created by Heejung Yang on 10/14/25.
//

import SwiftUI

// MARK: - Project Model
public struct ProjectEntity: Identifiable, Codable, Equatable {
    public var id: UUID = .init()
    public var title: String
    public var createdAt: Date = .init()
    public var canvasSize: CGSize = .init(width: 1080, height: 1920)
}

// Codable CGSize support
private struct _CodableCGSize: Codable { let w: CGFloat; let h: CGFloat }
public extension ProjectEntity {
    enum CodingKeys: String, CodingKey { case id, title, createdAt, _canvas }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        let cs = try c.decode(_CodableCGSize.self, forKey: ._canvas)
        canvasSize = .init(width: cs.w, height: cs.h)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(_CodableCGSize(w: canvasSize.width, h: canvasSize.height), forKey: ._canvas)
    }
}

// MARK: - Project Store (JSON persistence)
public final class ProjectStore: ObservableObject {
    @Published public private(set) var projects: [ProjectEntity] = []

    private let fileName = "projects.json"
    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent(fileName)
    }

    public init(preloadIfEmpty: Bool = true) {
        load()
        if preloadIfEmpty && projects.isEmpty {
            projects = [ .init(title: "샘플 프로젝트", canvasSize: .init(width: 1080, height: 1920)) ]
            save()
        }
    }

    public func add(_ project: ProjectEntity) {
        withAnimation(DT.AnimationToken.normal) { projects.insert(project, at: 0) }
        save()
    }

    public func remove(_ project: ProjectEntity) {
        if let idx = projects.firstIndex(of: project) {
            withAnimation(DT.AnimationToken.fast) { projects.remove(at: idx) }
            save()
        }
    }

    public func load() {
        do {
            let url = fileURL
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            let data = try Data(contentsOf: url)
            projects = try JSONDecoder().decode([ProjectEntity].self, from: data)
        } catch { print("[ProjectStore] Load error: \(error)") }
    }

    public func save() {
        do {
            let data = try JSONEncoder().encode(projects)
            try data.write(to: fileURL, options: [.atomic])
        } catch { print("[ProjectStore] Save error: \(error)") }
    }
}

// MARK: - Canvas Presets
public enum CanvasPreset: String, CaseIterable, Identifiable {
    case fhdPortrait = "1080 × 1920"
    case fhdLandscape = "1920 × 1080"
    case webtoonTall = "1600 × 2560"
    case square = "2048 × 2048"

    public var id: String { rawValue }
    public var size: CGSize {
        switch self {
        case .fhdPortrait: return .init(width: 1080, height: 1920)
        case .fhdLandscape: return .init(width: 1920, height: 1080)
        case .webtoonTall: return .init(width: 1600, height: 2560)
        case .square: return .init(width: 2048, height: 2048)
        }
    }
}

// MARK: - HomeView (Router‑Integrated)
public struct HomeView: View {
    @EnvironmentObject private var router: Router
    @StateObject private var store = ProjectStore()
    @State private var showNewProject = false
    @State private var searchText = ""

    public init() {}

    public var body: some View {
        ZStack {
            DT.ColorToken.background.ignoresSafeArea()
            VStack(spacing: DT.Spacing.lg) {
                header
                searchField
                projectList
                Spacer(minLength: 0)
                actionBar
            }
            .padding(.horizontal, DT.Spacing.page)
            .padding(.top, DT.Spacing.page)
        }
        .sheet(isPresented: $showNewProject) {
            NewProjectSheet { new in store.add(new) }
                .presentationDetents([.medium])
        }
    }

    // MARK: Sections
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("내 프로젝트")
                    .font(DT.FontToken.title)
                    .foregroundStyle(DT.ColorToken.textPrimary)
                Text("최근 생성한 프로젝트부터 보여줘요")
                    .font(DT.FontToken.subhead)
                    .foregroundStyle(DT.ColorToken.textSecondary)
            }
            Spacer()
        }
    }

    private var searchField: some View {
        HStack(spacing: DT.Spacing.sm) {
            Image(systemName: "magnifyingglass").imageScale(.medium)
                .foregroundStyle(DT.ColorToken.textSecondary)
            TextField("프로젝트 검색", text: $searchText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
        }
        .padding(.vertical, DT.Spacing.sm)
        .padding(.horizontal, DT.Spacing.md)
        .background(DT.ColorToken.surface)
        .overlay(
            RoundedRectangle(cornerRadius: DT.Radius.m, style: .continuous)
                .stroke(DT.ColorToken.outline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.m, style: .continuous))
        .shadow(DT.Elevation.level0)
        .accessibilityLabel(Text("프로젝트 검색"))
    }

    private var projectList: some View {
        ScrollView {
            LazyVStack(spacing: DT.Spacing.md) {
                ForEach(filteredProjects) { project in
                    ProjectCard(project: project) {
                        router.push(.editor(project))
                    }
                    .contextMenu {
                        Button(role: .destructive) { store.remove(project) } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                }
                if filteredProjects.isEmpty { emptyState }
            }
            .padding(.vertical, DT.Spacing.section)
        }
    }

    private var actionBar: some View {
        HStack(spacing: DT.Spacing.sm) { FilledButton("새 프로젝트 만들기") { showNewProject = true } }
    }

    private var emptyState: some View {
        VStack(spacing: DT.Spacing.sm) {
            Image(systemName: "folder.badge.plus").imageScale(.large)
                .font(.system(size: 28))
                .foregroundStyle(DT.ColorToken.textSecondary)
            Text("아직 프로젝트가 없어요").font(DT.FontToken.headline)
                .foregroundStyle(DT.ColorToken.textPrimary)
            Text("하단의 ‘새 프로젝트 만들기’를 눌러 시작해보세요")
                .font(DT.FontToken.subhead)
                .foregroundStyle(DT.ColorToken.textSecondary)
        }
        .padding(DT.Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(DT.ColorToken.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.l, style: .continuous))
    }

    private var filteredProjects: [ProjectEntity] {
        let key = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return store.projects }
        return store.projects.filter { $0.title.lowercased().contains(key) }
    }
}

// MARK: - Project Card
public struct ProjectCard: View {
    let project: ProjectEntity
    var onTap: () -> Void = {}

    public init(project: ProjectEntity, onTap: @escaping () -> Void = {}) {
        self.project = project
        self.onTap = onTap
    }

    public var body: some View {
        CardView {
            HStack(alignment: .top, spacing: DT.Spacing.md) {
                thumb
                VStack(alignment: .leading, spacing: 6) {
                    Text(project.title)
                        .font(DT.FontToken.headline)
                        .foregroundStyle(DT.ColorToken.textPrimary)
                        .lineLimit(1)
                    Text(dateString(project.createdAt))
                        .font(DT.FontToken.caption)
                        .foregroundStyle(DT.ColorToken.textSecondary)
                    Text("캔버스 \(Int(project.canvasSize.width)) × \(Int(project.canvasSize.height))")
                        .font(DT.FontToken.subhead)
                        .foregroundStyle(DT.ColorToken.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(DT.ColorToken.textSecondary)
            }
        }
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("프로젝트 \(project.title)"))
    }

    private var thumb: some View {
        RoundedRectangle(cornerRadius: DT.Radius.m, style: .continuous)
            .fill(DT.ColorToken.surfaceAlt)
            .frame(width: 56, height: 56)
            .overlay(
                Image(systemName: "doc.richtext")
                    .imageScale(.large)
                    .foregroundStyle(DT.ColorToken.textSecondary)
            )
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy.MM.dd HH:mm"; return f.string(from: date)
    }
}

// MARK: - New Project Sheet
public struct NewProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var preset: CanvasPreset = .fhdPortrait

    public var onCreate: (ProjectEntity) -> Void

    public init(onCreate: @escaping (ProjectEntity) -> Void) { self.onCreate = onCreate }

    public var body: some View {
        NavigationStack {
            form
                .navigationTitle("새 프로젝트")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
                .background(DT.ColorToken.background)
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: DT.Spacing.lg) {
            Group {
                Text("프로젝트 이름")
                    .font(DT.FontToken.subhead)
                    .foregroundStyle(DT.ColorToken.textSecondary)
                TextField("예: 휴먼카툰 샘플", text: $title)
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

            Group {
                Text("캔버스 프리셋")
                    .font(DT.FontToken.subhead)
                    .foregroundStyle(DT.ColorToken.textSecondary)
                Picker("Canvas", selection: $preset) {
                    ForEach(CanvasPreset.allCases) { p in Text(p.rawValue).tag(p) }
                }
                .pickerStyle(.segmented)
            }

            Spacer(minLength: 0)
            FilledButton("생성") { create() }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? DT.Opacity.disabled : 1)
        }
        .padding(DT.Spacing.page)
    }

    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
    }

    private func create() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let project = ProjectEntity(title: trimmed, canvasSize: preset.size)
        onCreate(project); dismiss()
    }
}

// MARK: - Preview
#if DEBUG
struct HomeView_RouterIntegrated_Previews: PreviewProvider {
    static var previews: some View {
        HomeView().environmentObject(Router())
    }
}
#endif
