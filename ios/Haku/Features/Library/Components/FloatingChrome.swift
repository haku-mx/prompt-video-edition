//
//  FloatingChrome.swift
//  Chrome flotante con Liquid Glass (iOS 26): la botonera + búsqueda abajo. No
//  son barras opacas: son piezas de vidrio que flotan sobre el contenido.
//

import SwiftUI

/// Secciones de nivel app (pestañas de la botonera).
enum AppTab: String, CaseIterable, Identifiable {
    case library, calendar
    var id: String { rawValue }
    var label: String { self == .library ? "Biblioteca" : "Calendario" }
    var icon: String { self == .library ? "square.grid.2x2.fill" : "calendar" }
}

// MARK: - Botonera + búsqueda flotantes (abajo)

struct FloatingBottomBar: View {
    @Binding var tab: AppTab
    var onSearch: () -> Void = {}

    var body: some View {
        GlassEffectContainer(spacing: 20) {
            HStack(spacing: 0) {
                // Botonera: pestañas de nivel app.
                HStack(spacing: 2) {
                    ForEach(AppTab.allCases) { t in
                        navItem(tab: t, active: t == tab) { tab = t }
                    }
                }
                .padding(6)
                .glassEffect(.regular, in: Capsule())
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)

                Spacer(minLength: HakuSpacing.md)

                // Búsqueda: independiente, a la misma altura que la botonera.
                Button(action: onSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(HakuColor.textPrimary)
                        .frame(width: 60, height: 60)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Circle())
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
            }
            .padding(.horizontal, HakuSpacing.lg)
        }
    }

    private func navItem(tab: AppTab, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(tab.label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(active ? HakuColor.textPrimary : HakuColor.textTertiary)
            .frame(width: 66, height: 48)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        HakuColor.background.ignoresSafeArea()
        VStack {
            Spacer()
            FloatingBottomBar(tab: .constant(.library))
        }
        .padding(.vertical, 8)
    }
    .preferredColorScheme(.light)
}
