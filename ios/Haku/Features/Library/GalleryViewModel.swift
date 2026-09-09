//
//  GalleryViewModel.swift
//  Estado del apartado Galería: carga los videos del backend. La agrupación por
//  fecha (Año / Mes / Día, estilo "recuerdos") vive en `GalleryGrouping` y la
//  aplica la vista según el modo elegido, sin volver a pedir datos.
//

import Foundation

/// Una sección agrupada de la galería.
struct GallerySection: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let videos: [Video]
}

/// Modos de organización temporal, como los recuerdos de Instagram/Fotos.
enum GalleryViewMode: String, CaseIterable, Identifiable {
    // Orden de menor a mayor detalle; el pinch avanza en este orden
    // (como Fotos: Años → Meses → Días → Todas).
    case years, months, days, all
    var id: String { rawValue }
    var label: String {
        switch self {
        case .years:  return "Años"
        case .months: return "Meses"
        case .days:   return "Días"
        case .all:    return "Todas"
        }
    }
    /// Columnas por modo: más grande/cinemático en Años, denso en Todas.
    var columns: Int {
        switch self {
        case .years:  return 1
        case .months: return 2
        case .days:   return 3
        case .all:    return 5
        }
    }
    var tileAspect: CGFloat {
        switch self {
        case .years:  return 16.0 / 9.0
        default:      return 1
        }
    }
    /// `Todas` es un grid denso sin encabezados de fecha.
    var isDense: Bool { self == .all }
}

@MainActor
final class GalleryViewModel: ObservableObject {

    enum State {
        case idle
        case loading
        case loaded(videosDir: String, videos: [Video], total: Int)
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private let api: HakuAPI

    init(api: HakuAPI = .localhost) {
        self.api = api
    }

    func load(isRefresh: Bool = false) async {
        if !isRefresh { state = .loading }
        do {
            let response = try await api.fetchVideos()
            state = .loaded(
                videosDir: response.videosDir,
                videos: response.videos,
                total: response.videos.count
            )
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            state = .failed(message)
        }
    }
}

/// Agrupa los videos por granularidad temporal usando `modified_at`. Los que no
/// tienen fecha caen en una sección "Sin fecha" al final. Secciones ordenadas de
/// más reciente a más antigua.
enum GalleryGrouping {
    static func sections(_ videos: [Video], mode: GalleryViewMode) -> [GallerySection] {
        guard !videos.isEmpty else { return [] }
        let cal = Calendar.current

        var dated: [(date: Date, video: Video)] = []
        var undated: [Video] = []
        for v in videos {
            if let t = v.modifiedAt {
                dated.append((Date(timeIntervalSince1970: t), v))
            } else {
                undated.append(v)
            }
        }

        func key(_ d: Date) -> DateComponents {
            switch mode {
            case .years:  return cal.dateComponents([.year], from: d)
            case .months: return cal.dateComponents([.year, .month], from: d)
            case .days, .all: return cal.dateComponents([.year, .month, .day], from: d)
            }
        }

        var order: [DateComponents] = []
        var buckets: [DateComponents: [Video]] = [:]
        for (d, v) in dated.sorted(by: { $0.date > $1.date }) {
            let k = key(d)
            if buckets[k] == nil { buckets[k] = []; order.append(k) }
            buckets[k]?.append(v)
        }

        var sections = order.map { k in
            GallerySection(title: title(for: k, mode: mode), subtitle: nil, videos: buckets[k] ?? [])
        }
        if !undated.isEmpty {
            sections.append(GallerySection(title: "Sin fecha", subtitle: nil, videos: undated))
        }
        return sections
    }

    private static func title(for comp: DateComponents, mode: GalleryViewMode) -> String {
        let cal = Calendar.current
        switch mode {
        case .years:
            return "\(comp.year ?? 0)"
        case .months:
            guard let date = cal.date(from: comp) else { return "" }
            return monthFormatter.string(from: date).capitalizedFirst
        case .days, .all:
            guard let date = cal.date(from: comp) else { return "" }
            return dayFormatter.string(from: date).capitalizedFirst
        }
    }

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()
}

private extension String {
    /// Pone en mayúscula la primera letra (los meses en español van en minúscula).
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
