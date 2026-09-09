//
//  LibraryScreen.swift
//  "Biblioteca": muestra el apartado activo (Colecciones o Videos) a pantalla
//  completa. El cambio de apartado NO vive aquí: se controla desde la botonera
//  de Liquid Glass (ver FloatingBottomBar), así la pantalla queda libre para el
//  contenido. Colecciones = tablero Pinterest; Videos = navegador estilo Fotos.
//

import SwiftUI

enum LibrarySegment: String, CaseIterable, Identifiable {
    case collections, videos
    var id: String { rawValue }
    var label: String { self == .collections ? "Colecciones" : "Videos" }
}

struct LibraryScreen: View {
    let segment: LibrarySegment
    let collections: [LibraryFolder]
    var onCreateCollection: (String, [Video], Set<String>) -> Void = { _, _, _ in }

    @State private var path = NavigationPath()
    @State private var newCollectionPresented = false
    @StateObject private var photos = GalleryViewModel()

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 0) {
                header
                content
            }
            .background(HakuColor.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: LibraryFolder.self) { folder in
                CollectionDetailScreen(folder: folder, onCreateCollection: onCreateCollection)
            }
        }
        .tint(HakuColor.textPrimary)
        .onChange(of: segment) { _, _ in path = NavigationPath() } // al cambiar de apartado, vuelve a la raíz
        .sheet(isPresented: $newCollectionPresented) {
            NewCollectionSheet(onCreate: onCreateCollection)
        }
        .task { await photos.load() }
    }

    /// Encabezado propio (en vez del large title del sistema) para controlar el
    /// espacio: poco margen arriba, título alineado con el contenido.
    private var header: some View {
        HStack(alignment: .center) {
            Text(segment.label)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(HakuColor.textPrimary)
            Spacer()
            if segment == .collections {
                Button { newCollectionPresented = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(HakuColor.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(HakuColor.surface, in: Circle())
                        .overlay(Circle().stroke(HakuColor.hairline, lineWidth: 1))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, HakuSpacing.sm)
        .padding(.bottom, HakuSpacing.md)
    }

    @ViewBuilder
    private var content: some View {
        switch segment {
        case .collections: collectionsBoard
        case .videos:      videosView
        }
    }

    // MARK: - Colecciones (tablero Pinterest)

    private var collectionsBoard: some View {
        ScrollView {
            MasonryColumns(items: collections, columns: 2, spacing: HakuSpacing.md) { folder in
                NavigationLink(value: folder) {
                    FolderCard(folder: folder, coverHeight: coverHeight(for: folder))
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, HakuSpacing.xs)
            .padding(.bottom, HakuLayout.bottomInset)
        }
        .scrollContentBackground(.hidden)
    }

    private func coverHeight(for folder: LibraryFolder) -> CGFloat {
        let seed = folder.name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        let steps: [CGFloat] = [150, 190, 220, 170, 240, 200]
        return steps[seed % steps.count]
    }

    // MARK: - Videos (estilo Fotos)

    @ViewBuilder
    private var videosView: some View {
        switch photos.state {
        case .idle, .loading:
            ScrollView { SkeletonGallery().padding(.top, HakuSpacing.sm) }
                .scrollDisabled(true)
                .scrollContentBackground(.hidden)
        case .loaded(_, let videos, _):
            let all = videos + MockLibrary.allMedia
            MediaTimeframeView(media: all,
                               playbackURL: { playbackURL(for: $0, realIDs: Set(videos.map(\.id))) })
        case .failed(let message):
            ContentUnavailableView {
                Label("No se pudo cargar", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Reintentar") { Task { await photos.load() } }
                    .buttonStyle(.borderedProminent).tint(HakuColor.accent)
            }
        }
    }

    private func playbackURL(for video: Video, realIDs: Set<String>) -> URL? {
        guard realIDs.contains(video.id) else { return nil }
        return HakuAPI.localhost.baseURL.appendingPathComponent("api/media/\(video.videoID)/salida.mp4")
    }
}

#Preview {
    LibraryScreen(segment: .collections, collections: MockLibrary.rootFolders)
        .preferredColorScheme(.light)
}
