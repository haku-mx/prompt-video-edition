//
//  MediaTimeframeView.swift
//  Navegador de fotos y videos estilo app Fotos de iPhone: SIN selector — solo
//  las imágenes. Se cambia de temporalidad con PINCH (separar = más detalle:
//  Años → Meses → Días → Todas; juntar = menos). Encabezados de fecha sutiles;
//  "Todas" es un grid denso sin encabezados. Tocar un video lo abre.
//
//  `header` opcional se apila arriba dentro del mismo scroll (nota, subcolecciones).
//

import SwiftUI

struct MediaTimeframeView<Header: View>: View {
    let media: [Video]
    var playbackURL: (Video) -> URL? = { _ in nil }
    /// Muestra la barra de etiquetas para filtrar (como en Buscar).
    var showsTagFilter: Bool = false
    /// Colecciones existentes a las que se puede añadir la selección.
    var collections: [LibraryFolder] = []
    var onCreateCollection: (String, [Video], Set<String>) -> Void = { _, _, _ in }
    var onAddToCollection: (LibraryFolder, [Video]) -> Void = { _, _ in }
    private let header: Header

    init(media: [Video],
         playbackURL: @escaping (Video) -> URL? = { _ in nil },
         showsTagFilter: Bool = false,
         collections: [LibraryFolder] = [],
         onCreateCollection: @escaping (String, [Video], Set<String>) -> Void = { _, _, _ in },
         onAddToCollection: @escaping (LibraryFolder, [Video]) -> Void = { _, _ in },
         @ViewBuilder header: () -> Header = { EmptyView() }) {
        self.media = media
        self.playbackURL = playbackURL
        self.showsTagFilter = showsTagFilter
        self.collections = collections
        self.onCreateCollection = onCreateCollection
        self.onAddToCollection = onAddToCollection
        self.header = header()
    }

    @State private var zoom: GalleryViewMode = .months
    @State private var detailVideo: VideoDetailPayload?
    @State private var hintVisible = false
    @State private var hintTask: Task<Void, Never>?
    @State private var selectedTags: Set<String> = []

    // Selección múltiple (long-press), independiente de la temporalidad.
    @State private var selecting = false
    @State private var selectedIDs: Set<String> = []
    @State private var createFromSelection = false

    private var selectedVideos: [Video] { media.filter { selectedIDs.contains($0.id) } }

    /// Etiquetas sugeridas, ordenadas por frecuencia (arrangement inteligente).
    private var suggestedTags: [String] {
        var counts: [String: Int] = [:]
        for v in media { for t in v.tags { counts[t, default: 0] += 1 } }
        return counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.map(\.key)
    }

    /// Media tras aplicar el filtro por etiquetas (unión).
    private var filteredMedia: [Video] {
        guard !selectedTags.isEmpty else { return media }
        return media.filter { !Set($0.tags).isDisjoint(with: selectedTags) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HakuSpacing.xl) {
                header
                if showsTagFilter, !suggestedTags.isEmpty {
                    TagFilterBar(suggestions: suggestedTags, selected: $selectedTags)
                }
                content
            }
            .padding(.horizontal, zoom.isDense ? HakuSpacing.sm : 20)
            .padding(.top, HakuSpacing.xs)
            .padding(.bottom, HakuLayout.bottomInset)
            .animation(.snappy(duration: 0.28), value: zoom)
        }
        .background(HakuColor.background)
        .scrollContentBackground(.hidden)
        .gesture(zoomPinch)
        .overlay(alignment: .top) {
            if selecting { selectionBar } else { zoomIndicator }
        }
        .sheet(item: $detailVideo) { VideoDetailSheet(payload: $0) }
        .sheet(isPresented: $createFromSelection) {
            NewCollectionSheet(selection: selectedVideos) { name, videos, labels in
                onCreateCollection(name, videos, labels)
                exitSelection()
            }
        }
    }

    // MARK: - Barra de selección

    private var selectionBar: some View {
        HStack(spacing: HakuSpacing.md) {
            Button("Cancelar") { exitSelection() }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(HakuColor.textPrimary)
            Spacer()
            Text("\(selectedIDs.count) seleccionado\(selectedIDs.count == 1 ? "" : "s")")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(HakuColor.textSecondary)
            Spacer()
            Menu {
                Button {
                    createFromSelection = true
                } label: { Label("Crear colección nueva", systemImage: "rectangle.stack.badge.plus") }
                if !collections.isEmpty {
                    Section("Añadir a") {
                        ForEach(collections) { c in
                            Button {
                                onAddToCollection(c, selectedVideos)
                                exitSelection()
                            } label: { Label(c.name, systemImage: "plus") }
                        }
                    }
                }
            } label: {
                Label("Guardar", systemImage: "tray.and.arrow.down.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(selectedIDs.isEmpty ? HakuColor.textTertiary : HakuColor.textPrimary)
            }
            .disabled(selectedIDs.isEmpty)
        }
        .padding(.horizontal, HakuSpacing.lg)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: Capsule())
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .padding(.horizontal, HakuSpacing.lg)
        .padding(.top, HakuSpacing.sm)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func toggle(_ video: Video) {
        if selectedIDs.contains(video.id) { selectedIDs.remove(video.id) }
        else { selectedIDs.insert(video.id) }
    }

    private func exitSelection() {
        withAnimation(.snappy(duration: 0.25)) {
            selecting = false
            selectedIDs.removeAll()
        }
    }

    @ViewBuilder
    private var content: some View {
        let items = filteredMedia
        if items.isEmpty {
            Text(selectedTags.isEmpty ? "Sin fotos ni videos."
                 : "Nada con esas etiquetas. Prueba con otras.")
                .font(HakuFont.caption).foregroundStyle(HakuColor.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center).padding(.top, HakuSpacing.xl)
        } else if zoom.isDense {
            denseGrid(items)
        } else {
            groupedGrid(items)
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: zoom.isDense ? 3 : HakuSpacing.md),
              count: zoom.columns)
    }

    /// Años / Meses / Días: secciones por fecha con encabezado sutil.
    private func groupedGrid(_ media: [Video]) -> some View {
        let sections = GalleryGrouping.sections(media, mode: zoom)
        return LazyVStack(alignment: .leading, spacing: HakuSpacing.xl) {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: HakuSpacing.sm) {
                    Text(section.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(HakuColor.textPrimary)
                    LazyVGrid(columns: columns, spacing: zoom.columns >= 3 ? HakuSpacing.sm : HakuSpacing.md) {
                        ForEach(section.videos) { tile($0) }
                    }
                }
            }
        }
    }

    /// Todas: un solo grid denso, sin encabezados, ordenado por fecha desc.
    private func denseGrid(_ media: [Video]) -> some View {
        let sorted = media.sorted { ($0.modifiedAt ?? 0) > ($1.modifiedAt ?? 0) }
        return LazyVGrid(columns: columns, spacing: 3) {
            ForEach(sorted) { tile($0) }
        }
    }

    private func tile(_ video: Video) -> some View {
        let isSel = selectedIDs.contains(video.id)
        return Button {
            if selecting { toggle(video) }
            else { detailVideo = VideoDetailPayload(video: video, playbackURL: playbackURL(video)) }
        } label: {
            VideoTile(video: video, aspect: zoom.tileAspect,
                      showsFilename: false, minimalOverlays: true, pressable: false)
                .overlay {
                    if selecting && isSel {
                        RoundedRectangle(cornerRadius: HakuRadius.sm, style: .continuous)
                            .stroke(HakuColor.accent, lineWidth: 3)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if selecting {
                        Image(systemName: isSel ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(isSel ? HakuColor.accent : .white)
                            .background(Circle().fill(.black.opacity(0.25)).padding(2))
                            .padding(6)
                    }
                }
                .opacity(selecting && !isSel ? 0.65 : 1)
        }
        .buttonStyle(ScaleButtonStyle())
        .highPriorityGesture(
            LongPressGesture(minimumDuration: 0.35).onEnded { _ in
                if !selecting { withAnimation(.snappy(duration: 0.25)) { selecting = true } }
                toggle(video)
            }
        )
    }

    // MARK: - Zoom por gestos (pinch)

    private var zoomIndicator: some View {
        Group {
            if hintVisible {
                Text(zoom.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(HakuColor.textPrimary)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .glassEffect(.regular, in: Capsule())
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                    .padding(.top, HakuSpacing.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var zoomPinch: some Gesture {
        MagnifyGesture()
            .onEnded { value in
                if value.magnification > 1.15 { zoomIn() }
                else if value.magnification < 0.85 { zoomOut() }
            }
    }

    private func zoomIn() { // más detalle (spread)
        let all = GalleryViewMode.allCases
        if let i = all.firstIndex(of: zoom), i + 1 < all.count { setZoom(all[i + 1]) }
    }

    private func zoomOut() { // menos detalle (pinch)
        let all = GalleryViewMode.allCases
        if let i = all.firstIndex(of: zoom), i > 0 { setZoom(all[i - 1]) }
    }

    private func setZoom(_ mode: GalleryViewMode) {
        withAnimation(.snappy(duration: 0.3)) { zoom = mode }
        flashHint()
    }

    private func flashHint() {
        withAnimation(.easeOut(duration: 0.2)) { hintVisible = true }
        hintTask?.cancel()
        hintTask = Task {
            try? await Task.sleep(for: .seconds(1.0))
            if !Task.isCancelled { withAnimation(.easeIn(duration: 0.25)) { hintVisible = false } }
        }
    }
}
