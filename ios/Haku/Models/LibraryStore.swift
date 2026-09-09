//
//  LibraryStore.swift
//  Estado de sesión de la biblioteca: es la fuente de verdad de las colecciones
//  (parte de las de ejemplo y se le pueden crear nuevas o añadir videos).
//  iOS-M1: persistencia ligera en memoria (no sobrevive a reinicios).
//

import SwiftUI

@MainActor
final class LibraryStore: ObservableObject {
    /// Todas las colecciones visibles (ejemplo + creadas por el usuario).
    @Published var collections: [LibraryFolder] = MockLibrary.rootFolders

    /// Crea una colección desde "Nueva colección" / "Crear colección".
    func addCollection(name: String, videos: [Video], enrichmentLabels: Set<String>) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let folder = LibraryFolder(
            name: clean.isEmpty ? "Colección sin título" : clean,
            enrichments: Self.enrichments(from: enrichmentLabels),
            subfolders: [],
            media: videos
        )
        collections.insert(folder, at: 0)
    }

    /// Añade videos a una colección existente (sin duplicar).
    func addVideos(to folder: LibraryFolder, videos: [Video]) {
        guard let i = collections.firstIndex(where: { $0.id == folder.id }) else { return }
        let existing = Set(collections[i].media.map(\.id))
        collections[i].media.append(contentsOf: videos.filter { !existing.contains($0.id) })
    }

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
