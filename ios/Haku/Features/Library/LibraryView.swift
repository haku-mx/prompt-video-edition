//
//  LibraryView.swift
//  Pantalla inicial (iOS-M1): la Biblioteca de Haku.
//
//  Dos pestañas —Biblioteca (explorador de colecciones) y Calendario— navegables
//  por la botonera flotante o con un swipe horizontal (TabView paginado). La
//  chrome flotante (botonera + Buscar) se superpone y persiste. Las colecciones
//  que se crean aparecen en la lista durante la sesión (LibraryStore).
//  Tema blanco (haku).
//

import SwiftUI

struct LibraryView: View {
    @State private var tab: AppTab = .library
    @State private var searchPresented = false
    @StateObject private var store = LibraryStore()

    var body: some View {
        ZStack {
            HakuColor.background.ignoresSafeArea()

            TabView(selection: $tab) {
                NavigationStack {
                    FolderScreen(
                        title: "Biblioteca",
                        folders: store.userCollections + MockLibrary.rootFolders,
                        staticMedia: nil,
                        onCreateCollection: create
                    )
                }
                .tag(AppTab.library)

                NavigationStack { CalendarView() }
                    .tag(AppTab.calendar)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .tint(HakuColor.textPrimary)

            // Chrome inferior flotante, persistente sobre las pestañas.
            VStack {
                Spacer()
                FloatingBottomBar(tab: $tab) { searchPresented = true }
                    .padding(.bottom, HakuSpacing.sm)
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $searchPresented) {
            SearchSheet(onCreateCollection: create)
        }
    }

    /// Crea la colección en el store y lleva a la pestaña Biblioteca para verla.
    private func create(_ name: String, _ videos: [Video], _ labels: Set<String>) {
        store.addCollection(name: name, videos: videos, enrichmentLabels: labels)
        withAnimation(.snappy(duration: 0.3)) { tab = .library }
    }
}

#Preview {
    LibraryView()
}
