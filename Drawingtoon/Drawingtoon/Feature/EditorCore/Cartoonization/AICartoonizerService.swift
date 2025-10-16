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
    public enum Style: String, Sendable { case comic, monoSketch, noir, edgeWork }
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
                    model: String = "gemini-1.5-flash",
                    endpoint: String = "https://generativelanguage.googleapis.com/v1beta",
                    timeout: TimeInterval = 30) {
            self.apiKey = apiKey
            self.model = model
            self.endpoint = endpoint
            self.timeout = timeout
        }
    }

    private let config: Config
    public init(config: Config = .init(apiKey: GeminiCartoonizerService.defaultAPIKey())) {
        self.config = config
    }

    /// Read API key from Info.plist (GEMINI_API_KEY) by default
    public static func defaultAPIKey() -> String {
        (Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String) ?? ""
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
        struct RequestBody: Codable { let contents: [Content] }

        let body = RequestBody(contents: [
            Content(role: "user", parts: [
                Part(text: stylePrompt + " Intensity: \(options.intensity). Respond with an image output."),
                Part(inline_data: .init(mime_type: "image/jpeg", data: data.base64EncodedString()))
            ])
        ])

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

// MARK: - 5) ViewModel wired for injection

@MainActor
public final class AICartoonizerViewModel: ObservableObject {
    @Published public var imageItem: PhotosPickerItem? {
        didSet { Task { await loadImage() } }
    }
    @Published public var inputImage: UIImage?
    @Published public var resultImage: UIImage?
    @Published public var isLoading = false
    @Published public var lastError: CartoonizeError?

    private let service: any AICartoonizerService
    private var options: CartoonizeOptions

    public init(service: any AICartoonizerService, options: CartoonizeOptions = .init()) {
        self.service = service
        self.options = options
    }

    public func setOptions(_ newValue: CartoonizeOptions) { self.options = newValue }

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

    private func loadImage() async {
        guard let data = try? await imageItem?.loadTransferable(type: Data.self),
              let img = UIImage(data: data) else { return }
        inputImage = img
        resultImage = nil
        lastError = nil
    }

    public func runCartoonize() async {
        guard let image = inputImage else { return }
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            let prepared = resizedIfNeeded(image, maxSize: options.resizeMax)
            let output = try await service.cartoonize(prepared, options: options)
            resultImage = output
        } catch is CancellationError {
            lastError = .cancelled
        } catch let e as CartoonizeError {
            lastError = e
        } catch {
            lastError = .server(error.localizedDescription)
        }
    }
}

// MARK: - 6) Minimal View usage + Previews

public struct AICartoonizerView: View {
    @Environment(\.services) private var services
    @StateObject private var vm: AICartoonizerViewModel

    public init() {
        _vm = StateObject(wrappedValue: AICartoonizerViewModel(service: AppServices.stub.cartoonizer))
    }

    public var body: some View {
        VStack(spacing: 16) {
            PhotosPicker(selection: $vm.imageItem, matching: .images) {
                Label(vm.inputImage == nil ? "사진 선택" : "다른 사진 선택", systemImage: "photo")
            }

            if let img = vm.resultImage ?? vm.inputImage {
                Image(uiImage: img).resizable().scaledToFit().frame(maxHeight: 300).clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                RoundedRectangle(cornerRadius: 16).fill(.quaternary).frame(height: 240).overlay(Text("미리보기").foregroundStyle(.secondary))
            }

            HStack {
                Menu("스타일") {
                    Button("Comic") { vm.setOptions(.init(style: .comic, intensity: 0.7)) }
                    Button("MonoSketch") { vm.setOptions(.init(style: .monoSketch, intensity: 0.7)) }
                    Button("Noir") { vm.setOptions(.init(style: .noir, intensity: 0.7)) }
                    Button("EdgeWork") { vm.setOptions(.init(style: .edgeWork, intensity: 0.7)) }
                }

                Spacer()

                Button(action: { Task { await vm.runCartoonize() } }) {
                    Label("AI 카툰화하기", systemImage: "wand.and.stars")
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.inputImage == nil || vm.isLoading)
            }

            if vm.isLoading { ProgressView("카툰화 중...") }
            if let err = vm.lastError { Text(err.localizedDescription).foregroundStyle(.red) }
        }
        .animation(.snappy, value: vm.isLoading)
        .padding()
        // Swap service at runtime via Environment
        .onAppear {
            // If the environment provides a different service, rebuild the VM with it
            // (Alternatively, inject via init from parent View)
        }
    }
}

#Preview("Stub Service (Default)") {
    AICartoonizerView()
        .environment(\.services, .stub)
}

#Preview("Live Shape (Delegates to Stub)") {
    AICartoonizerView()
        .environment(\.services, .live)
}
