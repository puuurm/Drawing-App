//
//  CartoonizerDiagnosticsView.swift
//  Drawingtoon
//
//  Created by Heejung Yang on 10/16/25.
//

import SwiftUI
import PhotosUI
import OSLog

private let diagLog = Logger(subsystem: "com.yourapp.DrawingToon", category: "GeminiDiagnostics")

struct CartoonizerDiagnosticsView: View {
    @Environment(\.services) private var services
    @State private var textPingResult: String = ""
    @State private var imageProbeResult: String = ""
    @State private var isBusy = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?

    var body: some View {
        List {
            Section("1. 텍스트 핑") {
                Button("텍스트 요청 보내기") { Task { await runTextPing() } }
                if !textPingResult.isEmpty { Text(textPingResult).font(.callout) }
            }

            Section("2. 이미지 라운드트립") {
                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Label("테스트 이미지 선택", systemImage: "photo")
                }
                if let img = pickedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 120)
                }
                Button("이미지 전송 (이미지 응답 기대)") {
                    Task { await runImageProbe() }
                }
                .disabled(pickedImage == nil || isBusy)

                if !imageProbeResult.isEmpty {
                    Text(imageProbeResult).font(.callout)
                }
            }
        }
        .navigationTitle("Gemini Diagnostics")
        .onChange(of: pickedItem) { _ in Task { await loadPicked() } }
    }

    private func loadPicked() async {
        guard let data = try? await pickedItem?.loadTransferable(type: Data.self),
              let img = UIImage(data: data) else { return }
        pickedImage = img
    }

    private func runTextPing() async {
        isBusy = true
        defer { isBusy = false }

        guard let live = services.cartoonizer as? GeminiCartoonizerService else {
            textPingResult = "❌ services.cartoonizer가 GeminiCartoonizerService가 아닙니다."
            return
        }

        do {
            let start = Date()
            let result = try await live.textPing()
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            textPingResult = "✅ OK (\(ms) ms)\\n\\(result)"
        } catch {
            textPingResult = "❌ 실패: \\(error.localizedDescription)"
        }
    }

    private func runImageProbe() async {
        guard let img = pickedImage else { return }
        isBusy = true
        defer { isBusy = false }

        guard let live = services.cartoonizer as? GeminiCartoonizerService else {
            imageProbeResult = "❌ services.cartoonizer가 GeminiCartoonizerService가 아닙니다."
            return
        }

        do {
            let start = Date()
            let ok = try await live.imageProbe(img)
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            imageProbeResult = ok ? "✅ 이미지 응답 성공 (\\(ms) ms)" : "⚠️ 이미지 응답 없음 (\\(ms) ms)"
        } catch {
            imageProbeResult = "❌ 실패: \(error.localizedDescription)"
            print("❌ 실패: \(error.localizedDescription)")
        }
    }
}

extension GeminiCartoonizerService {
    func textPing() async throws -> String {
        struct Part: Codable { var text: String? }
        struct Content: Codable { let role: String?; let parts: [Part] }
        struct Body: Codable { let contents: [Content] }

        let url = try makeURL()
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(
            Body(contents: [Content(role: "user", parts: [Part(text: "Say: pong (short)")])])
        )

        let (data, _) = try await URLSession.shared.data(for: req)
        struct Response: Codable {
            struct Candidate: Codable {
                struct Content: Codable {
                    struct Part: Codable { let text: String? }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]
        }

        let res = try JSONDecoder().decode(Response.self, from: data)
        return res.candidates.first?.content.parts.first?.text ?? "(no text)"
    }

    func imageProbe(_ image: UIImage) async throws -> Bool {
        guard let data = image.jpegData(compressionQuality: 0.85) else { throw CartoonizeError.encodeFailed }

        struct InlineData: Codable { let mime_type: String; let data: String }
        struct Part: Codable { var text: String?; var inline_data: InlineData? }
        struct Content: Codable { let role: String?; let parts: [Part] }
        struct GenerationConfig: Codable { var responseModalities: [String]?; var response_mime_type: String? }
        struct Body: Codable { let contents: [Content]; var generationConfig: GenerationConfig? }

        let body = Body(
            contents: [
                Content(role: "user", parts: [
                    Part(text: "Stylize this photo into clean comic style. Return the output as an image only (no text)."),
                    Part(inline_data: .init(mime_type: "image/jpeg", data: data.base64EncodedString()))
                ])
            ],
            generationConfig: GenerationConfig(responseModalities: ["IMAGE", "TEXT"])
        )
        
        let url = try makeURL()
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = config.timeout
        req.httpBody = try JSONEncoder().encode(body)

        let (dataResp, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw CartoonizeError.network("응답 형식 오류") }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: dataResp, encoding: .utf8) ?? "Unknown"
            throw CartoonizeError.server("HTTP \(http.statusCode): \(message)")
        }
        struct GenPart: Codable { let text: String?; let inline_data: InlineData? }
        struct GenContent: Codable { let parts: [GenPart]? }
        struct Candidate: Codable { let content: GenContent? }
        struct GenResponse: Codable { let candidates: [Candidate]? }
        let decoded = try JSONDecoder().decode(GenResponse.self, from: dataResp)
        for cand in decoded.candidates ?? [] {
            for p in cand.content?.parts ?? [] {
                if let blob = p.inline_data, blob.mime_type.hasPrefix("image/") { return true }
            }
        }
        return false
    }

    fileprivate func makeURL() throws -> URL {
        guard let url = URL(string: "\(config.endpoint)/models/\(config.model):generateContent?key=\(config.apiKey)") else {
            throw CartoonizeError.network("잘못된 URL")
        }
        return url
    }
}
