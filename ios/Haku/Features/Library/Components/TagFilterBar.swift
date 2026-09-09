//
//  TagFilterBar.swift
//  Fila de etiquetas para filtrar (como en Buscar): las seleccionadas se marcan
//  con acento y una "×"; las sugerencias se muestran con estilos variados para
//  sentirse como recomendaciones inteligentes. Scroll horizontal.
//

import SwiftUI

struct TagFilterBar: View {
    let suggestions: [String]
    @Binding var selected: Set<String>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: HakuSpacing.sm) {
                ForEach(Array(suggestions.enumerated()), id: \.element) { index, tag in
                    let isOn = selected.contains(tag)
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            if isOn { selected.remove(tag) } else { selected.insert(tag) }
                        }
                    } label: {
                        chip(tag, isOn: isOn, style: index % 3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func chip(_ tag: String, isOn: Bool, style: Int) -> some View {
        HStack(spacing: 5) {
            Text(tag)
                .font(.system(size: 14, weight: .semibold))
            if isOn {
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
            }
        }
        .foregroundStyle(foreground(isOn: isOn, style: style))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(background(isOn: isOn, style: style), in: Capsule())
        .overlay {
            if !isOn, style == 0 {
                Capsule().stroke(HakuColor.hairline, lineWidth: 1)
            }
        }
    }

    private func foreground(isOn: Bool, style: Int) -> Color {
        if isOn { return .white }
        switch style {
        case 2:  return HakuColor.accent
        default: return HakuColor.textSecondary
        }
    }

    private func background(isOn: Bool, style: Int) -> Color {
        if isOn { return HakuColor.accent }
        switch style {
        case 0:  return HakuColor.surface                 // contorno
        case 1:  return HakuColor.surfaceMuted            // relleno suave
        default: return HakuColor.accent.opacity(0.12)    // acento tenue
        }
    }
}

#Preview {
    StatefulTagPreview()
        .padding()
        .background(HakuColor.background)
        .preferredColorScheme(.light)
}

private struct StatefulTagPreview: View {
    @State var selected: Set<String> = ["playa"]
    var body: some View {
        TagFilterBar(suggestions: ["playa", "viaje", "familia", "skate", "noche", "paisaje", "retrato"],
                     selected: $selected)
    }
}
