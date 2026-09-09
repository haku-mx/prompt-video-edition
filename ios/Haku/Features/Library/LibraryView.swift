//
//  LibraryView.swift
//  Raíz de la app. Dos secciones (Biblioteca y Create) más los subapartados de
//  Biblioteca (Colecciones / Videos), todo controlado desde la botonera de
//  Liquid Glass — que se expande al activar Biblioteca. La pantalla queda libre
//  para el contenido. Las colecciones creadas persisten en sesión (LibraryStore).
//

import SwiftUI

struct LibraryView: View {
    @State private var tab: AppTab = .library
    @State private var librarySegment: LibrarySegment = .collections
    @State private var searchPresented = false
    @StateObject private var store = LibraryStore()

    var body: some View {
        ZStack {
            HakuColor.background.ignoresSafeArea()

            TabView(selection: $tab) {
                LibraryScreen(
                    segment: librarySegment,
                    collections: store.collections,
                    onCreateCollection: create,
                    onAddToCollection: { folder, videos in store.addVideos(to: folder, videos: videos) }
                )
                .tag(AppTab.library)

                NavigationStack { CraftView() }
                    .tag(AppTab.create)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .tint(HakuColor.textPrimary)

            VStack {
                Spacer()
                FloatingBottomBar(tab: $tab, librarySegment: $librarySegment) {
                    searchPresented = true
                }
                .padding(.bottom, HakuSpacing.sm)
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $searchPresented) {
            SearchSheet(onCreateCollection: create)
        }
    }

    private func create(_ name: String, _ videos: [Video], _ labels: Set<String>) {
        store.addCollection(name: name, videos: videos, enrichmentLabels: labels)
        withAnimation(.snappy(duration: 0.3)) {
            tab = .library
            librarySegment = .collections
        }
    }
}

#Preview {
    LibraryView()
}
