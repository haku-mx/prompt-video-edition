//
//  FolderCard.swift
//  Tarjeta de una carpeta en la Biblioteca. Portada en mosaico de su contenido,
//  con el NOMBRE visible (la navegación entre carpetas es la prioridad) y, si es
//  un "recuerdo", el cluster de enriquecimiento. Tocarla entra en la carpeta.
//

import SwiftUI

struct FolderCard: View {
    let folder: LibraryFolder

    var body: some View {
        MosaicCover(seeds: folder.coverSeeds)
            .frame(height: 150)
            .overlay {
                LinearGradient(
                    colors: [.black.opacity(0.15), .clear, .black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .topLeading) {
                GlyphBadge(system: "folder.fill", size: 26).padding(HakuSpacing.sm)
            }
            .overlay(alignment: .topTrailing) {
                if folder.isMemory {
                    EnrichmentCluster(enrichments: folder.enrichments)
                        .padding(HakuSpacing.sm)
                }
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(folder.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(folder.summary)
                        .font(HakuFont.caption)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
                .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
                .padding(HakuSpacing.md)
            }
            .clipShape(RoundedRectangle(cornerRadius: HakuRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: HakuRadius.lg, style: .continuous)
                    .stroke(HakuColor.hairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }
}

/// Señales de enriquecimiento agrupadas en una sola cápsula translúcida
/// (lugar, música, links, notas, voz…). Íconos sin texto.
struct EnrichmentCluster: View {
    let enrichments: [Enrichment]

    var body: some View {
        HStack(spacing: 9) {
            ForEach(Array(enrichments.enumerated()), id: \.offset) { _, e in
                Image(systemName: e.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 28)
        .background(.black.opacity(0.4), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
    }
}

/// Mosaico de portadas: 1 pane a pantalla completa; 2 en columnas; 3 con una
/// grande + dos apiladas; 4+ en cuadrícula 2×2.
struct MosaicCover: View {
    let seeds: [String]
    private let gap: CGFloat = 2

    var body: some View {
        let s = seeds.isEmpty ? ["_"] : seeds
        switch s.count {
        case 1:
            pane(s[0])
        case 2:
            HStack(spacing: gap) { pane(s[0]); pane(s[1]) }
        case 3:
            HStack(spacing: gap) {
                pane(s[0])
                VStack(spacing: gap) { pane(s[1]); pane(s[2]) }
                    .frame(maxWidth: 70)
            }
        default:
            VStack(spacing: gap) {
                HStack(spacing: gap) { pane(s[0]); pane(s[1]) }
                HStack(spacing: gap) { pane(s[2]); pane(s[3]) }
            }
        }
    }

    private func pane(_ seed: String) -> some View {
        PlaceholderThumbnail(seed: seed)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
    }
}

#Preview {
    let cols = [GridItem(.flexible()), GridItem(.flexible())]
    return LazyVGrid(columns: cols, spacing: 16) {
        ForEach(MockLibrary.rootFolders) { FolderCard(folder: $0) }
    }
    .padding()
    .background(HakuColor.background)
    .preferredColorScheme(.light)
}
