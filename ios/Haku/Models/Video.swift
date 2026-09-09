//
//  Video.swift
//  Un video de la biblioteca local, tal como lo devuelve `GET /api/videos`.
//

import Foundation

/// Un video listado por el backend. El contrato base de `GET /api/videos` es
/// `{ "video_id": "...", "filename": "...", "indexed": true/false }`.
///
/// Los campos `duration_s`, `modified_at` y `shot_count` son **opcionales**: el
/// servidor puede enriquecer la respuesta con ellos (ver iOS-M1), pero la app
/// funciona igual si no llegan.
struct Video: Identifiable, Decodable, Hashable {
    let videoID: String
    let filename: String
    let indexed: Bool
    let durationSeconds: Double?
    let modifiedAt: Double?
    let shotCount: Int?

    /// `Identifiable` usa el id estable del backend.
    var id: String { videoID }

    enum CodingKeys: String, CodingKey {
        case videoID = "video_id"
        case filename
        case indexed
        case durationSeconds = "duration_s"
        case modifiedAt = "modified_at"
        case shotCount = "shot_count"
    }

    /// Duración formateada tipo `1:23`, o `nil` si no se conoce.
    var durationLabel: String? {
        guard let secs = durationSeconds, secs > 0 else { return nil }
        let total = Int(secs.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Respuesta completa de `GET /api/videos`.
struct VideosResponse: Decodable {
    let videosDir: String
    let videos: [Video]

    enum CodingKeys: String, CodingKey {
        case videosDir = "videos_dir"
        case videos
    }
}
