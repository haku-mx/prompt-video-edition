//
//  LibraryView.swift
//  Pantalla inicial (iOS-M1): la Biblioteca de Haku.
//
//  Ventana única de carpetas (`FolderScreen`) + una pestaña de Calendario, con
//  chrome flotante Liquid Glass abajo (botonera Biblioteca/Calendario + Buscar)
//  que persiste sobre la navegación. Tema blanco (haku).
//

import SwiftUI

struct LibraryView: View {
    @State private var tab: AppTab = .library
    @State private var searchPresented = false

    var body: some View {
        ZStack {
            HakuColor.background.ignoresSafeArea()

            Group {
                switch tab {
                case .library:
                    NavigationStack {
                        FolderScreen(
                            title: "Biblioteca",
                            folders: MockLibrary.rootFolders,
                            staticMedia: nil
                        )
                    }
                case .calendar:
                    NavigationStack { CalendarView() }
                }
            }
            .tint(HakuColor.textPrimary)

            // Chrome inferior flotante, persistente sobre la navegación.
            VStack {
                Spacer()
                FloatingBottomBar(tab: $tab) { searchPresented = true }
                    .padding(.bottom, HakuSpacing.sm)
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $searchPresented) { SearchSheet() }
    }
}

#Preview {
    LibraryView()
}
