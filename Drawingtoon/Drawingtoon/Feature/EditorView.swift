//
//  EditorView.swift
//  Drawingtoon
//
//  Created by Heejung Yang on 10/14/25.
//

import SwiftUI
import PhotosUI

// MARK: - Layer Model
public enum Layer: Identifiable, Hashable {
    case image(ImageLayer)
    case bubble(BubbleLayer)

    public var id: UUID {
        switch self {
        case .image(let l): return l.id
        case .bubble(let l): return l.id
        }
    }
}

public struct ImageLayer: Hashable {
    public var id = UUID()
    public var image: UIImage
    public var transform = LayerTransform()
}

public struct BubbleLayer: Hashable {
    public var id = UUID()
    public var text: String = "말풍선"
    public var style: BubbleStyle = .rounded
    public var transform = LayerTransform(scale: 1.0)
}

public struct LayerTransform: Hashable {
    public var position: CGPoint = .zero
    public var scale: CGFloat = 1.0
    public var rotation: Angle = .degrees(0)
}

public enum BubbleStyle: String, CaseIterable, Identifiable, Hashable {
    case rounded, cloud, shout
    public var id: String { rawValue }
}

// MARK: - EditorView
public struct EditorView: View {
    public let project: ProjectEntity

    @State private var layers: [Layer] = []
    @State private var selectedID: UUID? = nil

    // Canvas state
    @State private var canvasScale: CGFloat = 1
    // Pickers
    @State private var photosItem: PhotosPickerItem? = nil

    // Export
    @State private var showShare = false
    @State private var exportedImageURL: URL? = nil

    public init(project: ProjectEntity) { self.project = project }

    public var body: some View {
        VStack(spacing: 0) {
            topBar
            TokenDivider()
            editorArea
            TokenDivider()
            bottomBar
        }
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(DT.ColorToken.background)
        .sheet(isPresented: $showShare) {
            if let url = exportedImageURL {
                ShareSheet(items: [url])
            }
        }
        .onChange(of: photosItem) { _, newValue in
            Task { await loadPickedPhoto(newValue) }
        }
    }

    // MARK: - UI Sections
    private var topBar: some View {
        HStack(spacing: DT.Spacing.sm) {
            IconButton("photo.on.rectangle") { /* open picker */ }
                .overlay(
                    PhotosPicker(selection: $photosItem, matching: .images) {
                        Color.clear
                    }
                )
            IconButton("bubble.left.and.bubble.right") { addBubble() }
            IconButton("square.and.arrow.down") { exportPNG() }
            Spacer()
            if let sel = selectedLayer { Text(layerName(sel)).font(DT.FontToken.subhead).foregroundStyle(DT.ColorToken.textSecondary) }
        }
        .padding(.horizontal, DT.Spacing.page)
        .frame(height: 48)
        .background(DT.ColorToken.background)
    }

    private var editorArea: some View {
        GeometryReader { geo in
            let screenScale = UIScreen.main.scale
            let displayCanvas = CGSize(
                width:  project.canvasSize.width  / screenScale,
                height: project.canvasSize.height / screenScale
            )

            let available = CGSize(
                width:  geo.size.width  - DT.Spacing.page * 2,
                height: geo.size.height - DT.Spacing.page * 2
            )

            let fit = min(available.width / displayCanvas.width,
                          available.height / displayCanvas.height) * 0.95

            ZStack {
                Checkerboard()
                    .clipShape(RoundedRectangle(cornerRadius: DT.Radius.l, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DT.Radius.l, style: .continuous)
                            .stroke(DT.ColorToken.outline, lineWidth: 1)
                    )

                CanvasWrapper(size: displayCanvas, scale: $canvasScale) {
                    ForEach(layers) { layer in
                        LayerView(layer: layer, isSelected: selectedID == layer.id)
                            .onTapGesture { selectedID = layer.id }
                            .gesture(dragGesture(for: layer.id))
                            .gesture(scaleGesture(for: layer.id))
                            .gesture(rotationGesture(for: layer.id))
                    }
                }
                .onAppear {
                    canvasScale = max(1.0, min(4.0, fit))
                }
                .padding(DT.Spacing.card)
            }
//            .padding(DT.Spacing.page)
            .clipped()
        }
    }

    private var bottomBar: some View {
        VStack(spacing: DT.Spacing.sm) {
            if let idx = selectedIndex {
                LayerToolbar(layer: $layers[idx])
            } else {
                Text("레이어를 선택해 보세요")
                    .font(DT.FontToken.subhead)
                    .foregroundStyle(DT.ColorToken.textSecondary)
                    .padding(.vertical, DT.Spacing.sm)
            }
        }
        .padding(.horizontal, DT.Spacing.page)
        .padding(.bottom, DT.Spacing.sm)
        .background(DT.ColorToken.background)
    }

    // MARK: - Canvas
    private func canvas(size: CGSize) -> some View {
        let canvasRect = CGSize(width: project.canvasSize.width, height: project.canvasSize.height)
        return CanvasWrapper(size: canvasRect, scale: $canvasScale) {
            ForEach(layers) { layer in
                LayerView(layer: layer, isSelected: selectedID == layer.id)
                    .onTapGesture { selectedID = layer.id }
                    .gesture(dragGesture(for: layer.id))
                    .gesture(scaleGesture(for: layer.id))
                    .gesture(rotationGesture(for: layer.id))
            }
        }
    }

    // MARK: - Gestures
    private func dragGesture(for id: UUID) -> some Gesture {
        DragGesture()
            .onChanged { value in
                mutateTransform(id: id) { t in
                    t.position.x += value.translation.width
                    t.position.y += value.translation.height
                }
            }
    }

    private func scaleGesture(for id: UUID) -> some Gesture {
        MagnificationGesture()
            .onChanged { v in
                mutateTransform(id: id) { t in t.scale = max(0.1, min(8.0, v)) }
            }
    }

    private func rotationGesture(for id: UUID) -> some Gesture {
        RotationGesture()
            .onChanged { a in
                mutateTransform(id: id) { t in t.rotation = a }
            }
    }

    private func mutateTransform(id: UUID, _ f: (inout LayerTransform) -> Void) {
        guard let idx = layers.firstIndex(where: { $0.id == id }) else { return }
        switch layers[idx] {
        case .image(var l):
            var t = l.transform; f(&t); l.transform = t; layers[idx] = .image(l)
        case .bubble(var b):
            var t = b.transform; f(&t); b.transform = t; layers[idx] = .bubble(b)
        }
    }

    // MARK: - Actions
    private func addBubble() {
        let bubble = BubbleLayer(text: "말풍선", style: .rounded, transform: .init(position: .zero, scale: 1.0, rotation: .degrees(0)))
        layers.append(.bubble(bubble))
        selectedID = bubble.id
    }

    private func exportPNG() {
        // Render against the project canvas size
        let renderer = ImageRenderer(content: canvasForExport())
        renderer.scale = 1.0
        if let ui = renderer.uiImage {
            do {
                let url = try writePNG(ui)
                exportedImageURL = url
                showShare = true
            } catch {
                print("[Export] error: \(error)")
            }
        }
    }

    private func canvasForExport() -> some View {
        CanvasWrapper(size: project.canvasSize, scale: .constant(1)) {
            ForEach(layers) { layer in
                LayerView(layer: layer, isSelected: false)
            }
        }
    }

    private func writePNG(_ image: UIImage) throws -> URL {
        let data = image.pngData() ?? Data()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("export_\(UUID().uuidString).png")
        try data.write(to: url)
        return url
    }

    private func loadPickedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {

                let screenScale = UIScreen.main.scale
                let displayCanvas = CGSize(
                    width:  project.canvasSize.width  / screenScale,
                    height: project.canvasSize.height / screenScale
                )
                let fit = initialFitScale(imageSize: image.size, displayCanvas: displayCanvas)

                let layer = ImageLayer(
                    image: image,
                    transform: .init(position: .zero, scale: fit, rotation: .degrees(0))
                )
                layers.append(.image(layer))
                selectedID = layer.id
            }
        } catch {
            print("[PhotosPicker] error: \(error)")
        }
    }

    private func initialFitScale(imageSize: CGSize, displayCanvas: CGSize) -> CGFloat {
        guard imageSize.width > 0, imageSize.height > 0 else { return 1 }
        let s = min(displayCanvas.width / imageSize.width,
                    displayCanvas.height / imageSize.height) * 0.9
        return max(0.1, min(4.0, s))
    }


    // MARK: - Helpers
    private var selectedIndex: Int? { layers.firstIndex { $0.id == selectedID } }
    private var selectedLayer: Layer? { layers.first { $0.id == selectedID } }

    private func update(id: UUID, _ mutate: (inout Layer) -> Void) {
        guard let idx = layers.firstIndex(where: { $0.id == id }) else { return }
        var l = layers[idx]
        mutate(&l)
        layers[idx] = l
    }

    private func layerName(_ layer: Layer) -> String {
        switch layer {
        case .image: return "이미지"
        case .bubble: return "말풍선"
        }
    }
}

// MARK: - Layer View
fileprivate struct LayerView: View {
    let layer: Layer
    let isSelected: Bool

    var body: some View {
        switch layer {
        case .image(let l): ImageLayerView(layer: l, selected: isSelected)
        case .bubble(let l): BubbleLayerView(layer: l, selected: isSelected)
        }
    }
}

fileprivate struct ImageLayerView: View {
    var layer: ImageLayer
    var selected: Bool

    var body: some View {
        Image(uiImage: layer.image)
            .resizable()
            .interpolation(.high)
            .frame(width: layer.image.size.width, height: layer.image.size.height)
            .modifier(TransformModifier(t: layer.transform))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? DT.ColorToken.brandSecondary : .clear, lineWidth: 2)
            )
    }
}

fileprivate struct BubbleLayerView: View {
    @State var layer: BubbleLayer
    var selected: Bool

    var body: some View {
        HStack(spacing: DT.Spacing.xs) {
            TextField("말풍선", text: $layer.text)
                .font(.system(size: 24, weight: .bold))
                .padding(.horizontal, DT.Spacing.md)
                .padding(.vertical, DT.Spacing.xs)
                .background(bubbleShape.fill(Color.white.opacity(0.9)))
                .overlay(bubbleShape.stroke(DT.ColorToken.outline, lineWidth: 1))
        }
        .modifier(TransformModifier(t: layer.transform))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(selected ? DT.ColorToken.brandSecondary : .clear, lineWidth: 2)
        )
    }

    private var bubbleShape: some Shape {
        switch layer.style {
        case .rounded: return AnyShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        case .cloud: return AnyShape(CloudShape())
        case .shout: return AnyShape(SpeechTailShape())
        }
    }
}

// MARK: - Layer Toolbar
fileprivate struct LayerToolbar: View {
    @Binding var layer: Layer

    var body: some View {
        HStack(spacing: DT.Spacing.sm) {
            switch layer {
            case .image(var l):
                Button("맞춤") { l.transform = .init(position: .zero, scale: 1, rotation: .degrees(0)); layer = .image(l) }
                Button("좌우반전") { if let flipped = l.image.flippedHorizontally() { l.image = flipped; layer = .image(l) } }
            case .bubble(var b):
                Menu {
                    Picker("스타일", selection: Binding(get: { b.style }, set: { b.style = $0; layer = .bubble(b) })) {
                        ForEach(BubbleStyle.allCases) { style in Text(style.rawValue).tag(style) }
                    }
                } label: { Label("스타일", systemImage: "scribble") }
                Button("리셋") { b.transform = .init(position: .zero, scale: 1, rotation: .degrees(0)); layer = .bubble(b) }
            }
            Spacer()
        }
    }
}

// MARK: - Canvas Wrapper
fileprivate struct CanvasWrapper<Content: View>: View {
    var size: CGSize
    @Binding var scale: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white)
                .frame(width: size.width, height: size.height)
                .overlay(
                    ZStack { content }
                )
                .clipShape(RoundedRectangle(cornerRadius: DT.Radius.l, style: .continuous))
                .shadow(DT.Elevation.level1)
        }
        .scaleEffect(scale)
        // 줌만 허용 (캔버스 자체 드래그/오프셋 제거)
        .gesture(
            MagnificationGesture()
                .onChanged { v in
                    scale = max(0.1, min(4.0, v))
                }
        )
    }
}


// MARK: - Shapes & Modifiers
fileprivate struct TransformModifier: ViewModifier {
    let t: LayerTransform
    func body(content: Content) -> some View {
        content
            .scaleEffect(t.scale)
            .rotationEffect(t.rotation)
            .offset(x: t.position.x, y: t.position.y)
    }
}

fileprivate struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = rect
        p.addRoundedRect(in: r, cornerSize: .init(width: 24, height: 24))
        return p
    }
}

fileprivate struct SpeechTailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path(roundedRect: rect, cornerRadius: 12)
        let tail = CGRect(x: rect.midX - 10, y: rect.maxY - 6, width: 20, height: 12)
        p.move(to: CGPoint(x: tail.minX, y: tail.minY))
        p.addLine(to: CGPoint(x: tail.midX, y: tail.maxY))
        p.addLine(to: CGPoint(x: tail.maxX, y: tail.minY))
        p.closeSubpath()
        return p
    }
}

fileprivate struct AnyShape: Shape {
    private let pathBuilder: (CGRect) -> Path
    init<S: Shape>(_ wrapped: S) { self.pathBuilder = { wrapped.path(in: $0) } }
    func path(in rect: CGRect) -> Path { pathBuilder(rect) }
}

fileprivate struct Checkerboard: View {
    var body: some View {
        GeometryReader { geo in
            let size = 10.0 * (geo.size.width / 300.0)
            Canvas { ctx, rect in
                let rows = Int(rect.height / size)
                let cols = Int(rect.width / size)
                for r in 0...rows {
                    for c in 0...cols {
                        let isDark = (r + c) % 2 == 0
                        let color = isDark ? Color.gray.opacity(0.15) : Color.gray.opacity(0.05)
                        ctx.fill(Path(CGRect(x: Double(c)*size, y: Double(r)*size, width: size, height: size)), with: .color(color))
                    }
                }
            }
        }
    }
}

// MARK: - Utilities
fileprivate struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

fileprivate extension UIImage {
    func flippedHorizontally() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        ctx.translateBy(x: size.width, y: 0)
        ctx.scaleBy(x: -1.0, y: 1.0)
        draw(at: .zero)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img
    }
}

// MARK: - Preview
#if DEBUG
struct EditorView_Previews: PreviewProvider {
    static var previews: some View {
        let proj = ProjectEntity(title: "샘플 프로젝트", canvasSize: .init(width: 1080, height: 1920))
        NavigationStack { EditorView(project: proj) }
            .environmentObject(Router())
    }
}
#endif
