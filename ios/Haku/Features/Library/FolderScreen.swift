//
//  FolderScreen.swift
//  La ventana única de la Biblioteca: fusiona carpetas y rejilla de media.
//
//  Muestra las subcarpetas (navegables) y, debajo, los videos de la carpeta
//  organizados por fecha. El nivel temporal (Año/Mes/Día) NO tiene control de
//  segmentos: se cambia con gestos —pinch (como Fotos) o swipe horizontal— y un
//  indicador flotante confirma el nivel. En la raíz la media es real (backend);
//  en subcarpetas es mock.
//

import SwiftUI

struct FolderScreen: View {
    let title: String
    let folders: [LibraryFolder]
    /// `nil` ⇒ raíz (carga media real del backend); si no, media mock estática.
    let staticMedia: [Video]?
    /// Nota del recuerdo (si esta carpeta es un recuerdo con texto).
    var memoryNote: String? = nil
    var memorySeed: String? = nil

    private var isRoot: Bool { staticMedia == nil }

    @StateObject private var model = GalleryViewModel()
    @State private var zoom: GalleryViewMode = .months
    @State private var hintVisible = false
    @State private var hintTask: Task<Void, Never>?
    @State private var uploadPresented = false
    @State private var newCollectionPresented = false
    @State private var note: NotePayload?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HakuSpacing.xl) {
                if let memoryNote { noteCard(memoryNote) }
                if !folders.isEmpty { foldersSection }
                mediaSection
            }
            .padding(.horizontal, HakuSpacing.lg)
            .padding(.top, HakuSpacing.sm)
            .padding(.bottom, HakuLayout.bottomInset)
            .animation(.snappy(duration: 0.28), value: zoom)
        }
        .background(HakuColor.background)
        .scrollContentBackground(.hidden)
        .gesture(zoomPinch)
        .simultaneousGesture(zoomSwipe)
        .overlay(alignment: .top) { zoomIndicator }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(isRoot ? .large : .inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { addMenu }
        }
        .sheet(isPresented: $uploadPresented) { UploadSheet() }
        .sheet(isPresented: $newCollectionPresented) { NewCollectionSheet() }
        .sheet(item: $note) { NoteSheet(payload: $0) }
        .task {
            if isRoot { await model.load() }
        }
    }

    // MARK: - Nota del recuerdo

    private func noteCard(_ text: String) -> some View {
        Button {
            note = NotePayload(title: title, imageSeed: memorySeed ?? title, text: text)
        } label: {
            HStack(alignment: .top, spacing: HakuSpacing.md) {
                Image(systemName: "note.text")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(HakuColor.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nota del recuerdo")
                        .font(HakuFont.caption)
                        .foregroundStyle(HakuColor.textSecondary)
                    Text(text)
                        .font(HakuFont.body)
                        .foregroundStyle(HakuColor.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(HakuColor.textTertiary)
            }
            .padding(HakuSpacing.md)
            .background(HakuColor.surface, in: RoundedRectangle(cornerRadius: HakuRadius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HakuRadius.md, style: .continuous).stroke(HakuColor.hairline, lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Carpetas

    private var foldersSection: some View {
        VStack(alignment: .leading, spacing: HakuSpacing.md) {
            sectionHeader("Colecciones", count: folders.count)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: HakuSpacing.md),
                                GridItem(.flexible(), spacing: HakuSpacing.md)],
                      spacing: HakuSpacing.lg) {
                ForEach(folders) { folder in
                    NavigationLink {
                        FolderScreen(title: folder.name,
                                     folders: folder.subfolders,
                                     staticMedia: folder.media,
                                     memoryNote: folder.noteText,
                                     memorySeed: folder.coverSeeds.first)
                    } label: {
                        FolderCard(folder: folder)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    // MARK: - Media (con zoom temporal)

    @ViewBuilder
    private var mediaSection: some View {
        if isRoot {
            switch model.state {
            case .idle, .loading:
                SkeletonGallery()
            case .loaded(let videosDir, let videos, let total):
                if videos.isEmpty {
                    emptyMedia(videosDir: videosDir)
                } else {
                    mediaGrid(videos)
                    Text("\(total) video\(total == 1 ? "" : "s") · \(videosDir)")
                        .font(HakuFont.caption)
                        .foregroundStyle(HakuColor.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, HakuSpacing.sm)
                }
            case .failed(let message):
                errorMedia(message: message)
            }
        } else if let media = staticMedia, !media.isEmpty {
            mediaGrid(media)
        }
    }

    private func mediaGrid(_ videos: [Video]) -> some View {
        let sections = GalleryGrouping.sections(videos, mode: zoom)
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: HakuSpacing.md),
            count: zoom.columns
        )
        return LazyVStack(alignment: .leading, spacing: HakuSpacing.xl) {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: HakuSpacing.md) {
                    sectionHeader(section.title, count: section.videos.count)
                    LazyVGrid(columns: columns, spacing: HakuSpacing.lg) {
                        ForEach(section.videos) { video in
                            Button {
                                note = NotePayload(
                                    title: video.filename,
                                    imageSeed: video.videoID,
                                    text: "Nota de \(video.filename). Escribe aquí lo que quieras recordar de este clip."
                                )
                            } label: {
                                VideoTile(video: video, aspect: zoom.tileAspect)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                }
            }
        }
    }

    // MARK: - Encabezado y estados

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack(alignment: .center, spacing: HakuSpacing.sm) {
            Capsule().fill(HakuColor.accent).frame(width: 3, height: 18)
            Text(title)
                .font(HakuFont.sectionHeader)
                .foregroundStyle(HakuColor.textPrimary)
            Spacer()
            Text("\(count)")
                .font(HakuFont.caption)
                .foregroundStyle(HakuColor.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(HakuColor.surface, in: Capsule())
                .overlay(Capsule().stroke(HakuColor.hairline, lineWidth: 1))
        }
    }

    private func emptyMedia(videosDir: String) -> some View {
        ContentUnavailableView {
            Label("Sin videos", systemImage: "film.stack")
        } description: {
            Text("Coloca un video en:\n\(videosDir)\n\ny recarga.")
        } actions: {
            Button("Recargar") { Task { await model.load(isRefresh: true) } }
                .tint(HakuColor.accent)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
    }

    private func errorMedia(message: String) -> some View {
        ContentUnavailableView {
            Label("No se pudo cargar", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Reintentar") { Task { await model.load() } }
                .buttonStyle(.borderedProminent)
                .tint(HakuColor.accent)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
    }

    // MARK: - "+" menú

    private var addMenu: some View {
        Menu {
            Button { newCollectionPresented = true } label: {
                Label("Nueva colección", systemImage: "rectangle.stack.badge.plus")
            }
            Button { uploadPresented = true } label: {
                Label("Subir archivos", systemImage: "square.and.arrow.up")
            }
        } label: {
            Image(systemName: "plus")
        }
    }

    // MARK: - Zoom por gestos

    private var zoomIndicator: some View {
        Group {
            if hintVisible {
                Label(zoom.label, systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(HakuColor.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
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

    private var zoomSwipe: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > 60, abs(dx) > 2 * abs(dy) else { return }
                if dx < 0 { zoomIn() } else { zoomOut() }
            }
    }

    private func zoomIn() {  // más detalle: Año → Mes → Día
        switch zoom {
        case .years:  setZoom(.months)
        case .months: setZoom(.days)
        case .days:   break
        }
    }

    private func zoomOut() { // menos detalle: Día → Mes → Año
        switch zoom {
        case .days:   setZoom(.months)
        case .months: setZoom(.years)
        case .years:  break
        }
    }

    private func setZoom(_ mode: GalleryViewMode) {
        withAnimation(.snappy(duration: 0.28)) { zoom = mode }
        flashHint()
    }

    private func flashHint() {
        withAnimation(.easeOut(duration: 0.2)) { hintVisible = true }
        hintTask?.cancel()
        hintTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            if !Task.isCancelled {
                withAnimation(.easeIn(duration: 0.25)) { hintVisible = false }
            }
        }
    }
}

#Preview {
    ZStack {
        HakuColor.background.ignoresSafeArea()
        NavigationStack {
            FolderScreen(title: "Biblioteca", folders: MockLibrary.rootFolders, staticMedia: nil)
        }
        .tint(HakuColor.textPrimary)
    }
    .preferredColorScheme(.light)
}
