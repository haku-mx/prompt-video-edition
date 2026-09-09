//
//  LibraryStore.swift
//  Estado de sesión de la biblioteca: guarda las colecciones que el usuario crea
//  para que aparezcan en la lista durante la sesión. iOS-M1: persistencia ligera
//  en memoria (no sobrevive a reinicios; sin SwiftData todavía).
//

import SwiftUI

@MainActor
final class LibraryStore: ObservableObject {
    /// Colecciones creadas por el usuario (se muestran antes de las de ejemplo).
    @Published var userCollections: [LibraryFolder] = []

    /// Crea una colección desde el flujo de "Nueva colección" / "Crear colección".
    func addCollection(name: String, videos: [Video], enrichmentLabels: Set<String>) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let folder = LibraryFolder(
            name: clean.isEmpty ? "Colección sin título" : clean,
            enrichments: Self.enrichments(from: enrichmentLabels),
            subfolders: [],
            media: videos
        )
        userCollections.insert(folder, at: 0)
    }

    /// Mapea las etiquetas elegidas en la UI a enriquecimientos (valores mock).
    private static func enrichments(from labels: Set<String>) -> [Enrichment] {
        var out: [Enrichment] = []
        if labels.contains("Música") { out.append(.music(title: "Por definir", artist: "")) }
        if labels.contains("Lugar")  { out.append(.place(name: "Por definir")) }
        if labels.contains("Voz")    { out.append(.voice(label: "Nota de voz")) }
        if labels.contains("Enlace") { out.append(.social(source: "Enlace")) }
        if labels.contains("Nota")   { out.append(.text("Nota nueva")) }
        return out
    }
}
