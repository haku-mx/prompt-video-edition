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
    private let header: Header

    init(media: [Video],
         playbackURL: @escaping (Video) -> URL? = { _ in nil },
         @ViewBuilder header: () -> Header = { EmptyView() }) {
        self.media = media
        self.playbackURL = playbackURL
        self.header = header()
    }

    @State private var zoom: GalleryViewMode = .months
    @State private var detailVideo: VideoDetailPayload?
    @State private var hintVisible = false
    @State private var hintTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HakuSpacing.xl) {
                header
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
        .overlay(alignment: .top) { zoomIndicator }
        .sheet(item: $detailVideo) { VideoDetailSheet(payload: $0) }
    }

    @ViewBuilder
    private var content: some View {
        if media.isEmpty {
            Text("Sin fotos ni videos.")
                .font(HakuFont.caption).foregroundStyle(HakuColor.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center).padding(.top, HakuSpacing.xl)
        } else if zoom.isDense {
            denseGrid
        } else {
            groupedGrid
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: zoom.isDense ? 3 : HakuSpacing.md),
              count: zoom.columns)
    }

    /// Años / Meses / Días: secciones por fecha con encabezado sutil.
    private var groupedGrid: some View {
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
    private var denseGrid: some View {
        let sorted = media.sorted { ($0.modifiedAt ?? 0) > ($1.modifiedAt ?? 0) }
        return LazyVGrid(columns: columns, spacing: 3) {
            ForEach(sorted) { tile($0) }
        }
    }

    private func tile(_ video: Video) -> some View {
        Button {
            detailVideo = VideoDetailPayload(video: video, playbackURL: playbackURL(video))
        } label: {
            VideoTile(video: video, aspect: zoom.tileAspect,
                      showsFilename: false, minimalOverlays: true)
        }
        .buttonStyle(ScaleButtonStyle())
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
