//
//  SearchSheet.swift
//  Buscar por título o etiqueta, con filtros/etiquetas y resultados de video
//  SELECCIONABLES: al elegir videos aparece "Crear colección (N)" para armar una
//  colección nueva desde la selección. iOS-M1: resultados mock, sin persistencia.
//

import SwiftUI

struct SearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var activeTags: [String] = ["grupo", "color"]
    @State private var selected: Set<String> = []
    @State private var createPresented = false

    private let suggested = ["retrato", "paisaje", "abstracto", "viaje", "familia", "noche"]
    private let pool = MockLibrary.allMedia

    private var results: [Video] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return pool }
        return pool.filter { $0.filename.lowercased().contains(q) }
    }
    private var selectedVideos: [Video] { pool.filter { selected.contains($0.id) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HakuSpacing.lg) {
                    searchField
                    if !activeTags.isEmpty { activeFilters }
                    suggestedTags
                    resultsSection
                }
                .padding(HakuSpacing.lg)
                .padding(.bottom, selected.isEmpty ? HakuSpacing.lg : 88)
            }
            .background(HakuColor.background)
            .scrollContentBackground(.hidden)
            .navigationTitle("Buscar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } }
            }
            .overlay(alignment: .bottom) { createBar }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $createPresented) {
            NewCollectionSheet(selection: selectedVideos)
        }
    }

    // MARK: - Buscador y filtros

    private var searchField: some View {
        HStack(spacing: HakuSpacing.sm) {
            Image(systemName: "magnifyingglass").foregroundStyle(HakuColor.textSecondary)
            TextField("Buscar por título o etiqueta…", text: $query)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(HakuColor.textTertiary)
                }
            }
        }
        .padding(.horizontal, HakuSpacing.md)
        .padding(.vertical, 12)
        .background(HakuColor.surface, in: Capsule())
        .overlay(Capsule().stroke(HakuColor.hairline, lineWidth: 1))
    }

    private var activeFilters: some View {
        FlowLayout(spacing: HakuSpacing.sm) {
            ForEach(activeTags, id: \.self) { tag in
                Button {
                    withAnimation(.snappy(duration: 0.2)) { activeTags.removeAll { $0 == tag } }
                } label: {
                    HStack(spacing: 6) {
                        Text(tag)
                        Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(HakuColor.accent, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            Button {} label: {
                HStack(spacing: 6) {
                    Text("ver todos los filtros")
                    Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold))
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(HakuColor.textPrimary)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(HakuColor.surface, in: Capsule())
                .overlay(Capsule().stroke(HakuColor.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var suggestedTags: some View {
        VStack(alignment: .leading, spacing: HakuSpacing.sm) {
            Text("Etiquetas sugeridas")
                .font(HakuFont.caption).foregroundStyle(HakuColor.textSecondary)
            FlowLayout(spacing: HakuSpacing.sm) {
                ForEach(suggested, id: \.self) { tag in
                    let on = activeTags.contains(tag)
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            if on { activeTags.removeAll { $0 == tag } } else { activeTags.append(tag) }
                        }
                    } label: {
                        Text(tag)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(on ? .white : HakuColor.textSecondary)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(on ? HakuColor.accent : HakuColor.surfaceMuted, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Resultados seleccionables

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: HakuSpacing.sm) {
            HStack {
                Text("Resultados")
                    .font(HakuFont.sectionHeader).foregroundStyle(HakuColor.textPrimary)
                Spacer()
                if !selected.isEmpty {
                    Button("Quitar selección") {
                        withAnimation(.snappy(duration: 0.2)) { selected.removeAll() }
                    }
                    .font(HakuFont.caption)
                    .tint(HakuColor.accent)
                }
            }
            Text("Toca para seleccionar y crear una colección")
                .font(HakuFont.caption).foregroundStyle(HakuColor.textTertiary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: HakuSpacing.sm), count: 3),
                      spacing: HakuSpacing.sm) {
                ForEach(results) { video in
                    resultTile(video)
                }
            }
        }
    }

    private func resultTile(_ video: Video) -> some View {
        let isSel = selected.contains(video.id)
        return Button {
            withAnimation(.snappy(duration: 0.18)) {
                if isSel { selected.remove(video.id) } else { selected.insert(video.id) }
            }
        } label: {
            PlaceholderThumbnail(seed: video.videoID)
                .aspectRatio(1, contentMode: .fill)
                .overlay {
                    if isSel {
                        RoundedRectangle(cornerRadius: HakuRadius.sm, style: .continuous)
                            .stroke(HakuColor.accent, lineWidth: 3)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: isSel ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(isSel ? HakuColor.accent : .white.opacity(0.9))
                        .padding(5)
                        .shadow(radius: 2)
                }
                .clipShape(RoundedRectangle(cornerRadius: HakuRadius.sm, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Barra de crear

    @ViewBuilder
    private var createBar: some View {
        if !selected.isEmpty {
            Button {
                createPresented = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.stack.badge.plus")
                    Text("Crear colección (\(selected.count))")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(HakuColor.accent, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, HakuSpacing.lg)
            .padding(.bottom, HakuSpacing.md)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

/// Layout de flujo (wrap horizontal) mínimo, reutilizable para chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        SearchSheet().preferredColorScheme(.light)
    }
}
