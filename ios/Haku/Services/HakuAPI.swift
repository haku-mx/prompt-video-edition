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
}
