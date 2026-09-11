//
//  HakuAPI.swift
//  Capa de red: el único punto que habla con el servidor FastAPI de Haku.
//
//  La URL base es configurable (por defecto el servidor local que arranca con
//  `uvicorn server.main:app --reload`). Cuando exista un backend remoto, basta
//  cambiar `baseURL` — ningún otro archivo conoce endpoints.
//

import Foundation

/// Errores de red legibles para mostrar en la UI.
enum HakuAPIError: LocalizedError {
    case badURL
    case notConnected(String)
    case badStatus(Int)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .badURL:
            return "URL del servidor inválida."
        case .notConnected(let detail):
            return "No se pudo conectar con el servidor Haku. ¿Está corriendo "
                + "`uvicorn server.main:app --reload`?\n\n\(detail)"
        case .badStatus(let code):
            return "El servidor respondió con un error (HTTP \(code))."
        case .decoding(let detail):
            return "La respuesta del servidor no tuvo el formato esperado.\n\n\(detail)"
        }
    }
}

struct TimelineCommandResponse: Decodable {
    let results: [TimelineVideoDecision]
    let unavailableVideoIDs: [String]
    let summary: String

    enum CodingKeys: String, CodingKey {
        case results
        case unavailableVideoIDs = "unavailable_video_ids"
        case summary
    }
}

struct TimelineVideoDecision: Decodable {
    let videoID: String
    let clips: [TimelineClipDecision]
    let rationale: String

    enum CodingKeys: String, CodingKey {
        case videoID = "video_id"
        case clips
        case rationale
    }
}

struct TimelineClipDecision: Decodable {
    let startSeconds: Double
    let endSeconds: Double

    enum CodingKeys: String, CodingKey {
        case startSeconds = "in_s"
        case endSeconds = "out_s"
    }
}

/// Cliente ligero de la API de Haku. Async/await; sin dependencias externas.
struct HakuAPI {
    /// URL base del backend. Ajustable para desarrollo local o remoto.
    var baseURL: URL

    /// El servidor local por defecto (el simulador comparte la red del Mac).
    static let localhost = HakuAPI(baseURL: URL(string: "http://127.0.0.1:8000")!)

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    /// `GET /api/videos` — lista los videos locales con su estado de indexado.
    func fetchVideos() async throws -> VideosResponse {
        let url = baseURL.appendingPathComponent("api/videos")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw HakuAPIError.notConnected(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse,
           !(200...299).contains(http.statusCode) {
            throw HakuAPIError.badStatus(http.statusCode)
        }

        do {
            return try JSONDecoder().decode(VideosResponse.self, from: data)
        } catch {
            throw HakuAPIError.decoding(error.localizedDescription)
        }
    }


    /// `POST /api/timeline/command` — asks the AI engine for a reversible edit
    /// decision without rendering a new video.
    func applyTimelineCommand(_ prompt: String, videoIDs: [String]) async throws -> TimelineCommandResponse {
        let url = baseURL.appendingPathComponent("api/timeline/command")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            TimelineCommandPayload(videoIDs: videoIDs, prompt: prompt)
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw HakuAPIError.notConnected(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse,
           !(200...299).contains(http.statusCode) {
            throw HakuAPIError.badStatus(http.statusCode)
        }

        do {
            return try JSONDecoder().decode(TimelineCommandResponse.self, from: data)
        } catch {
            throw HakuAPIError.decoding(error.localizedDescription)
        }
    }
}

private struct TimelineCommandPayload: Encodable {
    let videoIDs: [String]
    let prompt: String

    enum CodingKeys: String, CodingKey {
        case videoIDs = "video_ids"
        case prompt
    }
}
