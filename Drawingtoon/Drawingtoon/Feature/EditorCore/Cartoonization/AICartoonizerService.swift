//
//  AICartoonizerService.swift
//  Drawingtoon
//
//  Created by Heejung Yang on 10/16/25.
//

import SwiftUI
import PhotosUI
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - 1) Service Protocol & Models

public struct CartoonizeOptions: Sendable, Equatable {
    public enum Style: String, CaseIterable, Sendable { case comic, monoSketch, noir, edgeWork }
    public var style: Style
    public var intensity: Double // 0.0 ~ 1.0 (implementation-dependent)
    public var resizeMax: CGFloat? // optional longest-edge resize before upload
    public init(style: Style = .comic, intensity: Double = 0.7, resizeMax: CGFloat? = 2048) {
        self.style = style
        self.intensity = max(0, min(1, intensity))
        self.resizeMax = resizeMax
    }
}

public enum CartoonizeError: Error, LocalizedError {
    case invalidInput
    case encodeFailed
    case decodeFailed
    case network(String)
    case server(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .invalidInput: return "잘못된 입력 이미지입니다."
        case .encodeFailed: return "이미지 인코딩에 실패했어요."
        case .decodeFailed: return "응답 이미지를 해석하지 못했어요."
        case .network(let m): return "네트워크 오류: \(m)"
        case .server(let m): return "서버 오류: \(m)"
        case .cancelled: return "요청이 취소되었어요."
        }
    }
}

public protocol AICartoonizerService: Sendable {
    /// Returns a cartoonized UIImage (main-thread safe to present)
    func cartoonize(_ image: UIImage, options: CartoonizeOptions) async throws -> UIImage
}

// MARK: - 2) Stub Implementation (CI-based, offline)

public struct StubCartoonizerService: AICartoonizerService {
    private let context = CIContext(options: [.priorityRequestLow: true])
    private let defaultDelay: UInt64
    public init(simulatedLatencyMs: Int = 800) {
        self.defaultDelay = UInt64(simulatedLatencyMs) * 1_000_000
    }

    public func cartoonize(_ image: UIImage, options: CartoonizeOptions) async throws -> UIImage {
        try Task.checkCancellation()
        // Simulate latency
        try? await Task.sleep(nanoseconds: defaultDelay)

        guard let input = image.cgImage else { throw CartoonizeError.invalidInput }
        let ciImage = CIImage(cgImage: input)

        let output: CIImage
        switch options.style {
        case .comic:
            let comic = CIFilter.comicEffect()
            comic.inputImage = ciImage
            output = comic.outputImage ?? ciImage
        case .monoSketch:
            let noir = CIFilter.photoEffectNoir()
            noir.inputImage = ciImage
            let edges = CIFilter.edges()
            edges.inputImage = noir.outputImage
            edges.intensity = Float(5 * options.intensity + 1)
            output = edges.outputImage ?? ciImage
        case .noir:
            let noir = CIFilter.photoEffectNoir()
            noir.inputImage = ciImage
            output = noir.outputImage ?? ciImage
        case .edgeWork:
            let edgeWork = CIFilter.edgeWork()
            edgeWork.inputImage = ciImage
            edgeWork.radius = Float(3 + 8 * options.intensity)
            output = edgeWork.outputImage ?? ciImage
        }

        guard let cg = context.createCGImage(output, from: output.extent) else {
            throw CartoonizeError.decodeFailed
        }
        return UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
    }
}

// MARK: - 3) Live Service (Gemini) — URLSession + (optional) SDK

public struct GeminiCartoonizerService: AICartoonizerService {
    public struct Config: Sendable, Equatable {
        public var apiKey: String
        public var model: String // e.g. "gemini-1.5-flash" or "gemini-1.5-pro"
        public var endpoint: String // Google AI public endpoint (generativelanguage)
        public var timeout: TimeInterval
        public init(apiKey: String,
                    model: String = "gemini-2.5-flash-image",
                    endpoint: String = "https://generativelanguage.googleapis.com/v1beta",
                    timeout: TimeInterval = 30) {
            self.apiKey = apiKey
            self.model = model
            self.endpoint = endpoint
            self.timeout = timeout
        }
    }

    let config: Config
    public init(config: Config = .init(apiKey: GeminiCartoonizerService.defaultAPIKey())) {
        self.config = config
    }

    /// Read API key from Info.plist (GEMINI_API_KEY) by default
    public static func defaultAPIKey() -> String {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dic = plist as? [String: Any],
              let apiKey = dic["GEMINI_API_KEY"] as? String else {
            return ""
        }
        return apiKey
    }

    public func cartoonize(_ image: UIImage, options: CartoonizeOptions) async throws -> UIImage {
        try Task.checkCancellation()

        // Prefer SDK when available
        #if canImport(GoogleGenerativeAI)
        if let img = try await cartoonizeWithSDK(image, options: options) { return img }
        #endif

        return try await cartoonizeWithREST(image, options: options)
    }

    // MARK: REST path (public Generative Language API)
    /// Builds a generateContent request with the input image as inline_data and a light prompt.
    private func cartoonizeWithREST(_ image: UIImage, options: CartoonizeOptions) async throws -> UIImage {
        guard !config.apiKey.isEmpty else { throw CartoonizeError.server("API 키가 없습니다 (GEMINI_API_KEY).") }
        
        // Encode image -> JPEG (you can switch to PNG if transparency matters)
        guard let data = image.jpegData(compressionQuality: 0.9) else { throw CartoonizeError.encodeFailed }
        
        // Prompt guiding style
        let stylePrompt: String = {
            switch options.style {
            case .comic: return "Convert the input photo into a clean comic/cartoon style with bold outlines and simplified shading."
            case .monoSketch: return "Convert the input photo into a monochrome sketch style with strong edges and pencil-like strokes."
            case .noir: return "Convert the input photo into a noir black-and-white high-contrast comic style."
            case .edgeWork: return "Convert the input photo emphasizing edges with stylized line work."
            }
        }()
        
        // Gemini 1.5 generateContent JSON
        struct InlineData: Codable { let mime_type: String; let data: String }
        struct Part: Codable {
            var text: String? = nil
            var inline_data: InlineData? = nil
        }
        struct Content: Codable { let role: String?; let parts: [Part] }
        struct GenerationConfig: Codable {
            var responseModalities: [String]?
            var response_mime_type: String?
        }
        struct RequestBody: Codable {
            let contents: [Content]
            var generationConfig: GenerationConfig?
        }
        
        let body = RequestBody(
            contents: [
                Content(role: "user", parts: [
                    Part(text: stylePrompt + " Return the output as an image only (no text)."),
                    Part(inline_data: .init(mime_type: "image/jpeg", data: data.base64EncodedString()))
                ])
            ],
            generationConfig: GenerationConfig(
                responseModalities: ["IMAGE", "TEXT"]
            )
        )

        // POST /models/{model}:generateContent
        guard let url = URL(string: "\(config.endpoint)/models/\(config.model):generateContent?key=\(config.apiKey)") else {
            throw CartoonizeError.network("잘못된 URL")
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = config.timeout
        req.httpBody = try JSONEncoder().encode(body)

        let (dataResp, resp) = try await URLSession.shared.data(for: req)
        try Task.checkCancellation()

        guard let http = resp as? HTTPURLResponse else { throw CartoonizeError.network("응답 형식 오류") }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: dataResp, encoding: .utf8) ?? "Unknown error"
            throw CartoonizeError.server("HTTP \(http.statusCode): \(message)")
        }

        // Minimal response model to find an inline image in parts
        struct GenPart: Codable {
            let text: String?
            let inline_data: InlineData?
        }
        struct GenContent: Codable { let parts: [GenPart]? }
        struct Candidate: Codable { let content: GenContent? }
        struct GenResponse: Codable { let candidates: [Candidate]? }

        let decoded = try JSONDecoder().decode(GenResponse.self, from: dataResp)

        if let candidates = decoded.candidates {
            for cand in candidates {
                if let parts = cand.content?.parts {
                    for p in parts {
                        if let blob = p.inline_data, blob.mime_type.starts(with: "image/") {
                            if let imgData = Data(base64Encoded: blob.data), let ui = UIImage(data: imgData) {
                                return ui
                            }
                        }
                    }
                }
            }
        }

        // If no image returned, attempt to fall back by returning the original or throw
        throw CartoonizeError.decodeFailed
    }
}

// MARK: - 4) Simple DI Container via SwiftUI Environment

public struct AppServices: Sendable {
    public var cartoonizer: any AICartoonizerService

    public init(cartoonizer: any AICartoonizerService) {
        self.cartoonizer = cartoonizer
    }
}

private struct AppServicesKey: EnvironmentKey {
    static let defaultValue = AppServices(cartoonizer: StubCartoonizerService())
}

public extension EnvironmentValues {
    var services: AppServices {
        get { self[AppServicesKey.self] }
        set { self[AppServicesKey.self] = newValue }
    }
}

public extension AppServices {
    static let stub = AppServices(cartoonizer: StubCartoonizerService())
    static let live = AppServices(cartoonizer: GeminiCartoonizerService())
}

// MARK: - 3) ViewModel
@MainActor
final class AICartoonizerViewModel: ObservableObject {
    @Published var inputImage: UIImage?
    @Published var resultImage: UIImage?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var style: CartoonizeOptions.Style = .comic
    @Published var intensity: Double = 0.7
    @Published var resizeMax: CGFloat = 1200

    private let service: any AICartoonizerService
    private var lastImageBeforeRun: UIImage?

    init(service: any AICartoonizerService) { self.service = service }

    func setInput(_ ui: UIImage?) { inputImage = ui; resultImage = nil; errorMessage = nil }

    func run() async {
        guard let img = inputImage else { return }
        isLoading = true; errorMessage = nil
        lastImageBeforeRun = resultImage ?? img
        defer { isLoading = false }
        do {
            let prepared = resizedIfNeeded(img, maxSize: resizeMax)
            let options = CartoonizeOptions(style: style, intensity: intensity, resizeMax: resizeMax)
            let out = try await service.cartoonize(prepared, options: options)
            resultImage = out
        } catch is CancellationError { errorMessage = CartoonizeError.cancelled.localizedDescription }
          catch let e as CartoonizeError { errorMessage = e.localizedDescription }
          catch { errorMessage = error.localizedDescription }
    }

    func undoOnce() { if let prev = lastImageBeforeRun { resultImage = prev } }

    func saveToPhotos() async {
        guard let ui = resultImage ?? inputImage else { errorMessage = "저장할 이미지가 없어요"; return }
        await withCheckedContinuation { cont in
            UIImageWriteToSavedPhotosAlbum(ui, nil, nil, nil)
            cont.resume()
        }
    }

    // MARK: helpers
    private func resizedIfNeeded(_ image: UIImage, maxSize: CGFloat?) -> UIImage {
        guard let maxSize, maxSize > 0 else { return image }
        let w = image.size.width, h = image.size.height
        let longest = Swift.max(w, h)
        guard longest > maxSize else { return image }
        let scale = maxSize / longest
        let newSize = CGSize(width: w * scale, height: h * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}

// MARK: - 4) View
struct AICartoonizerView: View {
    @Environment(\.services) private var services
    @Environment(\.flags) private var flags
    @StateObject private var vm: AICartoonizerViewModel
    @State private var showPicker = false

    init() {
        // default to Local/Stub; will be overridden by Environment in App entry
        _vm = StateObject(wrappedValue: AICartoonizerViewModel(service: LocalCartoonizerService()))
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            preview
            controls
            footer
        }
        .padding()
        .navigationTitle("AI 카툰화 v0")
        .sheet(isPresented: $showPicker) { ImagePicker(image: Binding(get: { vm.inputImage }, set: vm.setInput)) }
        .onAppear { /* could rebuild VM with services.cartoonizer if desired */ }
    }

    private var header: some View {
        HStack {
            Button { showPicker = true } label: { Label("사진 선택", systemImage: "photo") }
                .buttonStyle(.bordered)
            Spacer()
            Menu {
                Picker("스타일", selection: $vm.style) {
                    ForEach(CartoonizeOptions.Style.allCases, id: \.self) { Text($0.rawValue) }
                }
                HStack { Text("강도"); Slider(value: $vm.intensity, in: 0...1) }
                HStack { Text("리사이즈"); Slider(value: Binding(get: { Double(vm.resizeMax) }, set: { vm.resizeMax = CGFloat($0) }), in: 512...2048) }
            } label: { Label("옵션", systemImage: "slider.horizontal.3") }
        }
    }

    private var preview: some View {
        Group {
            if let out = vm.resultImage ?? vm.inputImage {
                Image(uiImage: out).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(maxHeight: 360)
            } else {
                RoundedRectangle(cornerRadius: 16).fill(.quaternary).frame(height: 240)
                    .overlay(Text("미리보기").foregroundStyle(.secondary))
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button { Task { await vm.run() } } label: { Label("AI 카툰화", systemImage: "wand.and.stars") }
                .buttonStyle(.borderedProminent)
                .disabled(vm.inputImage == nil || vm.isLoading)
            Button { vm.undoOnce() } label: { Label("되돌리기", systemImage: "arrow.uturn.backward") }
                .disabled(vm.resultImage == nil)
            Spacer()
            if vm.isLoading { ProgressView() }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack {
                Button { Task { await vm.saveToPhotos() } } label: { Label("앨범에 저장", systemImage: "square.and.arrow.down") }
                    .disabled(vm.resultImage == nil && vm.inputImage == nil)
                Spacer()
                if flags.useLiveAI == false {
                    Text("Live off · 로컬/스텁 모드").font(.caption).foregroundStyle(.secondary)
                }
            }
            if let err = vm.errorMessage { Text(err).foregroundStyle(.red).font(.callout) }
        }
    }
}

// MARK: - 5) Minimal UIKit ImagePicker for SwiftUI
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let img = (info[.editedImage] ?? info[.originalImage]) as? UIImage
            parent.image = img
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated: true) }
    }
}

// MARK: - 2) LocalCartoonizerService (offline cartoon effect)
public struct LocalCartoonizerService: AICartoonizerService {
    private let ctx = CIContext(options: [.priorityRequestLow: true])
    public init() {}

    public func cartoonize(_ image: UIImage, options: CartoonizeOptions) async throws -> UIImage {
        guard let cg = image.cgImage else { throw CartoonizeError.invalidInput }
        let src = CIImage(cgImage: cg)
        let t = CGFloat(max(0.0, min(1.0, options.intensity))) // 0...1

        let output: CIImage
        switch options.style {
        case .comic:
            // Comic: posterize -> edges -> noir -> multiply
            let poster = CIFilter.colorPosterize(); poster.inputImage = src; poster.levels = Float(NSNumber(value: Int(3 + roundf(Float(t*4)))))
            let edges = CIFilter.edges(); edges.inputImage = poster.outputImage; edges.intensity = Float(2 + 6*t)
            let noir = CIFilter.photoEffectNoir(); noir.inputImage = poster.outputImage
            let blend = CIFilter.multiplyBlendMode(); blend.inputImage = edges.outputImage; blend.backgroundImage = noir.outputImage
            // optional: slight saturation boost back
            let sat = CIFilter.colorControls(); sat.inputImage = blend.outputImage; sat.saturation = Float(0.9 + 0.6*t as NSNumber); sat.brightness = 0; sat.contrast = Float(1.05 + 0.2*t as NSNumber)
            output = sat.outputImage ?? blend.outputImage ?? src

        case .monoSketch:
            // MonoSketch: edges strong -> invert -> screen over monochrome base
            let mono = CIFilter.photoEffectMono(); mono.inputImage = src
            let edges = CIFilter.edges(); edges.inputImage = mono.outputImage; edges.intensity = Float(4 + 6*t)
            let invert = CIFilter.colorInvert(); invert.inputImage = edges.outputImage
            let blur = CIFilter.gaussianBlur(); blur.inputImage = invert.outputImage; blur.radius = Float(0.5 + 1.5*t)
            let screen = CIFilter.screenBlendMode(); screen.inputImage = blur.outputImage; screen.backgroundImage = mono.outputImage
            output = screen.outputImage ?? mono.outputImage ?? src

        case .noir:
            // Noir: noir high-contrast + subtle edges
            let noir = CIFilter.photoEffectNoir(); noir.inputImage = src
            let edges = CIFilter.edges(); edges.inputImage = noir.outputImage; edges.intensity = Float(1 + 3*t)
            let overlay = CIFilter.overlayBlendMode(); overlay.inputImage = edges.outputImage; overlay.backgroundImage = noir.outputImage
            let contrast = CIFilter.colorControls(); contrast.inputImage = overlay.outputImage; contrast.contrast = Float(1.1 + 0.4*t as NSNumber)
            output = contrast.outputImage ?? overlay.outputImage ?? noir.outputImage ?? src

        case .edgeWork:
            // EdgeWork: native CIEdgeWork + posterize subtle
            let ew = CIFilter.edgeWork(); ew.inputImage = src; ew.radius = Float(1 + 4*t as NSNumber)
            let poster = CIFilter.colorPosterize(); poster.inputImage = ew.outputImage; poster.levels = Float(NSNumber(value: 4 + Int(round(2*t))))
            output = poster.outputImage ?? ew.outputImage ?? src
        }

        guard let outCG = ctx.createCGImage(output, from: output.extent) else { throw CartoonizeError.decodeFailed }
        return UIImage(cgImage: outCG, scale: image.scale, orientation: image.imageOrientation)
    }
}

struct FeatureFlags { var useLiveAI: Bool = false }
private struct FlagsKey: EnvironmentKey { static let defaultValue = FeatureFlags() }
extension EnvironmentValues { var flags: FeatureFlags { get { self[FlagsKey.self] } set { self[FlagsKey.self] = newValue } } }


#Preview("Stub Service (Default)") {
    AICartoonizerView()
        .environment(\.services, .stub)
}

#Preview("Live Shape (Delegates to Stub)") {
    AICartoonizerView()
        .environment(\.services, .live)
}
