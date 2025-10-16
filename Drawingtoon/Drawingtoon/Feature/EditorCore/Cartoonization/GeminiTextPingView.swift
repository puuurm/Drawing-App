//
//  GeminiTextPingView.swift
//  Drawingtoon
//
//  Created by Heejung Yang on 10/16/25.
//

import SwiftUI

struct GeminiTextPingView: View {
    @State private var status = "대기 중…"
    @State private var isLoading = false

    // 필요 시 수정
    private let endpoint = "https://generativelanguage.googleapis.com/v1beta"
    private let model = "gemini-2.5-flash"

    var body: some View {
        VStack(spacing: 16) {
            Text("Gemini REST Text Ping")
                .font(.title3).bold()

            Button {
                Task { await ping() }
            } label: {
                if isLoading { ProgressView() }
                else { Text("Ping 보내기") }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)

            ScrollView {
                Text(status).font(.callout).monospaced()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 240)
        }
        .padding()
    }

    private func ping() async {
        isLoading = true
        defer { isLoading = false }
        
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dic = plist as? [String: Any],
              let apiKey = dic["GEMINI_API_KEY"] as? String,
              !apiKey.isEmpty else {
            status = "❌ GEMINI_API_KEY 누락 (Info.plist 확인)"
            return
        }

        // 요청 모델 (텍스트만)
        struct Part: Codable { var text: String? }
        struct Content: Codable { let role: String?; let parts: [Part] }
        struct Body: Codable { let contents: [Content] }

        // 응답 모델 (텍스트만 뽑기)
        struct GenPart: Codable { let text: String? }
        struct GenContent: Codable { let parts: [GenPart]? }
        struct Candidate: Codable { let content: GenContent? }
        struct GenResponse: Codable { let candidates: [Candidate]? }

        guard let url = URL(string: "\(endpoint)/models/\(model):generateContent?key=\(apiKey)") else {
            status = "❌ URL 생성 실패"; return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30

        let body = Body(contents: [
            Content(role: "user", parts: [ Part(text: "Say: pong (short)") ])
        ])

        do {
            let start = Date()
            req.httpBody = try JSONEncoder().encode(body)
            let (data, resp) = try await URLSession.shared.data(for: req)

            guard let http = resp as? HTTPURLResponse else {
                status = "❌ HTTP 응답 형식 아님"; return
            }
            guard (200..<300).contains(http.statusCode) else {
                let msg = String(data: data, encoding: .utf8) ?? "Unknown"
                status = "❌ HTTP \(http.statusCode)\n\(msg)"
                return
            }

            let decoded = try JSONDecoder().decode(GenResponse.self, from: data)
            let text = decoded.candidates?.first?.content?.parts?
                .compactMap { $0.text }
                .joined(separator: " ") ?? "(no text)"
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            status = "✅ OK (\(ms) ms)\n\(text.prefix(200))"
        } catch {
            status = "❌ \(error.localizedDescription)"
        }
    }
}
