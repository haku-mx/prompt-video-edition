//
//  TimelineModels.swift
//  El "timeline" de edición de una colección. Una colección NO recorta el video:
//  lo resume con FOTOGRAMAS CLAVE (key frames). Cada video aporta unos cuantos
//  fotogramas; la colección se compone de los fotogramas incluidos, en orden.
//
//  Cada fotograma se COLOREA según la subcolección de la que viene, para que al
//  editar "Viajes" completo se vea de un vistazo qué aporta cada subcolección.
//
//  Todo front-end/mock (iOS-M1): los fotogramas se derivan de una semilla; sin
//  extracción real ni exportación todavía.
//

import SwiftUI

/// Paleta determinista para colorear subcolecciones. Colores apagados que
/// funcionan sobre blanco y como tinte de fotograma.
enum CollectionPalette {
    static let palette: [UInt32] = [
        0xE07A5F, // terracota
        0x5C82B5, // azul polvo
        0x81A684, // salvia
        0xC98BB9, // malva
        0xD9A441, // ocre
        0x5FA8A3, // verdemar
        0x8E7CC3, // lavanda
        0xD46A73, // rosa
    ]

    static func hex(for name: String) -> UInt32 {
        var h: UInt64 = 1469598103934665603
        for b in name.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return palette[Int(h % UInt64(palette.count))]
    }

    static func color(for name: String) -> Color { Color(hex: hex(for: name)) }
}

/// Un fotograma clave dentro del resumen de la colección.
struct KeyFrame: Identifiable, Hashable {
    let id: String          // "collectionID::videoID#index"
    let video: Video
    let sourceName: String  // subcolección de origen (para color y etiqueta)
    let colorHex: UInt32
    let index: Int          // # de fotograma dentro del video
    let ofCount: Int        // fotogramas totales de ese video
    var included: Bool = true

    var color: Color { Color(hex: colorHex) }
    /// Semilla para la miniatura (distinta por fotograma).
    var seed: String { id }
}

/// Un CLIP del timeline = un video. Estilo CapCut: el clip es la unidad; dentro
/// muestra su tira de fotogramas. Su duración define el ancho en la pista.
struct VideoClip: Identifiable, Hashable {
    let id: String            // collectionID::videoID
    let video: Video
    let colorHex: UInt32
    var frames: [KeyFrame]    // fotogramas del video (para la tira interna y el resumen)
    var included: Bool = true

    var color: Color { Color(hex: colorHex) }
}

/// Tipo de pista del timeline.
enum TrackKind: Hashable { case video, music }

/// Una PISTA del timeline. La única forma de agrupar: 1 colección por pista.
/// Las pistas de video contienen sus CLIPS (videos); la música es su pista.
struct EditTrack: Identifiable, Hashable {
    let id: String
    let name: String
    let colorHex: UInt32
    let kind: TrackKind
    var clips: [VideoClip] = []   // pistas de video
    var subtitle: String? = nil   // p. ej. artista, en una pista de música

    var color: Color { Color(hex: colorHex) }
    var allFrames: [KeyFrame] { clips.flatMap(\.frames) }
    var includedFrames: Int {
        clips.filter(\.included).flatMap(\.frames).filter(\.included).count
    }
    var totalFrames: Int { allFrames.count }
    /// Versión mock estable por pista.
    var versionLabel: String { "v\(name.count % 3 + 1)" }
}

/// Deriva pistas de una carpeta: una pista de video por subcolección (o la
/// carpeta misma) y una pista de música si hay enriquecimiento musical.
enum TimelineBuilder {
    static let musicColorHex: UInt32 = 0x3A3A42 // grafito, distinto de las de video

    /// Normaliza duraciones ausentes o inválidas para que la geometría del
    /// timeline nunca produzca clips de ancho cero o negativo.
    static func duration(of video: Video) -> Double {
        guard let duration = video.durationSeconds, duration > 0 else { return 20 }
        return max(duration, 1)
    }

    /// Cuántos fotogramas resume un video (según su duración, acotado).
    private static func frameCount(_ v: Video) -> Int {
        let d = duration(of: v)
        return max(2, min(5, Int(d / 15) + 2))
    }

    private static func frames(of v: Video, clipID: String, source: String, hex: UInt32) -> [KeyFrame] {
        let n = frameCount(v)
        return (0..<n).map { i in
            KeyFrame(id: "\(clipID)#\(i)", video: v, sourceName: source,
                     colorHex: hex, index: i, ofCount: n)
        }
    }

    /// Clips de una colección, tintados con su color (para distinguir la
    /// procedencia dentro de la única pista de video).
    private static func clips(in folder: LibraryFolder) -> [VideoClip] {
        let hex = CollectionPalette.hex(for: folder.name)
        return folder.media.map { video in
            let id = "\(folder.id.uuidString)::\(video.videoID)"
            return VideoClip(
                id: id,
                video: video,
                colorHex: hex,
                frames: frames(of: video, clipID: id, source: folder.name, hex: hex)
            )
        }
    }

    /// Aplana el árbol completo: el editor de una colección incluye tanto su
    /// media directa como la de cualquier subcolección anidada.
    private static func clipsRecursively(in folder: LibraryFolder) -> [VideoClip] {
        clips(in: folder) + folder.subfolders.flatMap(clipsRecursively)
    }

    private static func firstMusic(in folder: LibraryFolder) -> (title: String, artist: String)? {
        for e in folder.enrichments { if case .music(let t, let a) = e { return (t, a) } }
        for s in folder.subfolders { if let m = firstMusic(in: s) { return m } }
        return nil
    }

    /// UNA pista de video (clips en secuencia, sin solaparse; coloreados por
    /// colección) emparejada con UNA pista de audio (la música). 1 video : 1 audio.
    static func tracks(for folder: LibraryFolder) -> [EditTrack] {
        var vclips = clipsRecursively(in: folder)
        // Orden cronológico: un solo hilo de tiempo, sin solapamientos.
        vclips.sort { ($0.video.modifiedAt ?? 0) < ($1.video.modifiedAt ?? 0) }

        var out: [EditTrack] = [
            EditTrack(id: "video", name: "Video", colorHex: 0x1C1C22, kind: .video, clips: vclips)
        ]
        if let music = firstMusic(in: folder) {
            out.append(EditTrack(id: "music", name: music.title,
                                 colorHex: musicColorHex, kind: .music, subtitle: music.artist))
        }
        return out
    }

    /// Relación de aspecto (ancho/alto) mock del video, estable por id. La mayoría
    /// horizontal, con algunos verticales/cuadrados para variar el formato.
    static func aspect(for videoID: String) -> CGFloat {
        let pool: [CGFloat] = [16.0/9.0, 16.0/9.0, 9.0/16.0, 1.0, 4.0/5.0]
        var h: UInt64 = 1469598103934665603
        for b in videoID.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return pool[Int(h % UInt64(pool.count))]
    }
}
