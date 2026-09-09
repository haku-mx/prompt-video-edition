//
//  FloatingChrome.swift
//  Chrome flotante con Liquid Glass (iOS 26): una botonera cápsula + búsqueda.
//  La botonera es dinámica: al activar "Biblioteca" se EXPANDE para mostrar sus
//  subapartados (Colecciones / Videos) dentro del mismo vidrio; así la pantalla
//  queda libre para el contenido. "Create" (isotipo "k") está siempre presente.
//

import SwiftUI

/// Secciones de nivel app.
enum AppTab: String, CaseIterable, Identifiable {
    case library, create
    var id: String { rawValue }
}

struct FloatingBottomBar: View {
    @Binding var tab: AppTab
    @Binding var librarySegment: LibrarySegment
    var onSearch: () -> Void = {}

    var body: some View {
        GlassEffectContainer(spacing: 18) {
            HStack(spacing: 0) {
                cluster
                    .padding(5)
                    .glassEffect(.regular, in: Capsule())
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 4)

                Spacer(minLength: HakuSpacing.sm)

                Button(action: onSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(HakuColor.textPrimary)
                        .frame(width: 56, height: 56)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Circle())
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
            }
            .padding(.horizontal, HakuSpacing.lg)
            .animation(.snappy(duration: 0.3), value: tab)
        }
    }

    private var cluster: some View {
        HStack(spacing: 4) {
            if tab == .library {
                // Subapartados desplegados de Biblioteca.
                pill(label: "Colecciones", icon: "square.stack.3d.up.fill",
                     active: librarySegment == .collections) { librarySegment = .collections }
                pill(label: "Videos", icon: "play.rectangle.fill",
                     active: librarySegment == .videos) { librarySegment = .videos }
            } else {
                // Colapsado: botón para volver a Biblioteca.
                pill(label: "Biblioteca", icon: "square.grid.2x2.fill", active: false) {
                    tab = .library
                }
            }
            pill(label: "Create", mark: true, active: tab == .create) { tab = .create }
        }
    }

    /// Pill con énfasis en el ícono: la etiqueta aparece SOLO cuando está activo.
    private func pill(label: String, icon: String? = nil, mark: Bool = false,
                      active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if mark {
                    // Más grande que un ícono SF porque el PNG trae márgenes:
                    // así la "k" visible queda proporcional al resto de íconos.
                    HakuStudioMark(size: 30, color: active ? HakuColor.textPrimary : HakuColor.textSecondary)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(active ? HakuColor.textPrimary : HakuColor.textSecondary)
                }
                if active {
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(HakuColor.textPrimary)
                        .fixedSize()
                }
            }
            .frame(height: 46)
            .padding(.horizontal, active ? 15 : 13)
            .background {
                if active {
                    Capsule().fill(HakuColor.surface)
                        .shadow(color: .black.opacity(0.10), radius: 5, y: 2)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.28), value: active)
    }
}

#Preview {
    ZStack {
        HakuColor.background.ignoresSafeArea()
        VStack {
            Spacer()
            FloatingBottomBar(tab: .constant(.library), librarySegment: .constant(.collections))
        }
        .padding(.vertical, 8)
    }
    .preferredColorScheme(.light)
}
