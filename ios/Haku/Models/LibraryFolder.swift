//
//  LibraryFolder.swift
//  El único concepto de organización de la Biblioteca: la carpeta.
//
//  "Todo es carpetas": una carpeta puede ser normal o un "recuerdo" enriquecido
//  (música, lugar, notas, voz…). El enriquecimiento es una propiedad de la
//  carpeta. iOS-M1: árbol mock, sin persistencia — para vestir la navegación.
//

import SwiftUI

/// Tipo de referencia de contexto que enriquece una carpeta-recuerdo.
enum Enrichment: Hashable {
    case text(String)
    case voice(label: String)
    case place(name: String)
    case music(title: String, artist: String)
    case social(source: String)   // "Instagram", "TikTok", "Spotify"…

    var icon: String {
        switch self {
        case .text:   return "text.alignleft"
        case .voice:  return "waveform"
        case .place:  return "mappin.and.ellipse"
        case .music:  return "music.note"
        case .social: return "link"
        }
    }
}

/// Una carpeta de la biblioteca. Contiene subcarpetas y/o media (videos).
struct LibraryFolder: Identifiable, Hashable {
    let id = UUID()
    let name: String
    var enrichments: [Enrichment] = []
    var subfolders: [LibraryFolder] = []
    var media: [Video] = []

    /// Es un "recuerdo" si tiene enriquecimiento.
    var isMemory: Bool { !enrichments.isEmpty }

    /// Texto de la nota del recuerdo, si lo tiene (enriquecimiento `.text`).
    var noteText: String? {
        for e in enrichments { if case .text(let t) = e { return t.isEmpty ? nil : t } }
        return nil
    }

    /// Semillas para la portada en mosaico (de su media, o subcarpetas).
    var coverSeeds: [String] {
        let fromMedia = media.map(\.videoID)
        if !fromMedia.isEmpty { return Array(fromMedia.prefix(4)) }
        let fromSubs = subfolders.flatMap(\.media).map(\.videoID)
        if !fromSubs.isEmpty { return Array(fromSubs.prefix(4)) }
        return [name]
    }

    /// Conteo legible: subcarpetas + videos.
    var summary: String {
        var parts: [String] = []
        if !subfolders.isEmpty { parts.append("\(subfolders.count) colección\(subfolders.count == 1 ? "" : "es")") }
        let count = totalMediaCount
        if count > 0 { parts.append("\(count) video\(count == 1 ? "" : "s")") }
        return parts.isEmpty ? "Vacía" : parts.joined(separator: " · ")
    }

    /// Videos propios + de subcarpetas (para el resumen).
    var totalMediaCount: Int {
        media.count + subfolders.reduce(0) { $0 + $1.totalMediaCount }
    }
}

// MARK: - Datos mock

enum MockLibrary {
    /// Construye un Video mock con una fecha concreta (para poblar el zoom).
    private static func video(_ seed: String, _ name: String,
                              _ y: Int, _ mo: Int, _ d: Int, _ dur: Double) -> Video {
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d; c.hour = 12
        let date = Calendar.current.date(from: c) ?? Date()
        return Video(videoID: seed, filename: name, indexed: true,
                     durationSeconds: dur, modifiedAt: date.timeIntervalSince1970,
                     shotCount: nil)
    }

    /// Carpetas de nivel raíz que se muestran junto a la media real del backend.
    static let rootFolders: [LibraryFolder] = [
        LibraryFolder(
            name: "Viajes",
            enrichments: [.place(name: "Sayulita"), .music(title: "Ocean Eyes", artist: "Billie Eilish")],
            subfolders: [
                LibraryFolder(
                    name: "Costa 2025",
                    enrichments: [.place(name: "Sayulita"), .text("Los mejores días.")],
                    media: [
                        video("costa-1", "amanecer.mp4", 2025, 7, 3, 24),
                        video("costa-2", "surf.mp4", 2025, 7, 3, 58),
                        video("costa-3", "atardecer.mp4", 2025, 7, 5, 41),
                        video("costa-4", "malecon.mp4", 2025, 8, 12, 33),
                    ]
                ),
                LibraryFolder(
                    name: "Roadtrip norte",
                    enrichments: [.place(name: "Real de Catorce"), .music(title: "Motion", artist: "Tycho")],
                    media: [
                        video("road-1", "carretera.mp4", 2025, 1, 9, 72),
                        video("road-2", "desierto.mp4", 2025, 1, 10, 65),
                        video("road-3", "pueblo.mp4", 2025, 1, 11, 44),
                    ]
                ),
            ]
        ),
        LibraryFolder(
            name: "Familia",
            enrichments: [.voice(label: "Sus risas"), .text("No lo puedo creer.")],
            media: [
                video("bebe-1", "primeros_pasos.mp4", 2025, 3, 18, 51),
                video("bebe-2", "cumple.mp4", 2024, 11, 2, 88),
                video("fam-3", "cena.mp4", 2024, 12, 24, 120),
            ]
        ),
        LibraryFolder(
            name: "Skate sessions",
            enrichments: [.social(source: "TikTok"), .music(title: "MEGA", artist: "Blank Banshee")],
            media: [
                video("skate-1", "line_1.mp4", 2026, 5, 2, 19),
                video("skate-2", "line_2.mp4", 2026, 5, 2, 22),
                video("skate-3", "slam.mp4", 2026, 6, 14, 12),
                video("skate-4", "session.mp4", 2026, 6, 14, 34),
            ]
        ),
        LibraryFolder(
            name: "Sin clasificar",
            media: [
                video("misc-1", "clip_a.mp4", 2026, 2, 1, 15),
                video("misc-2", "clip_b.mp4", 2026, 2, 1, 27),
            ]
        ),
    ]

    /// Toda la media de la biblioteca, aplanada (para el calendario).
    static var allMedia: [Video] {
        func collect(_ f: LibraryFolder) -> [Video] {
            f.media + f.subfolders.flatMap(collect)
        }
        return rootFolders.flatMap(collect)
    }
}
