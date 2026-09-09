//
//  CraftView.swift
//  "Create" (Haku Studio): apartado para crear videos con los assets de la
//  biblioteca por dictado de voz o escritura. iOS-M1: placeholder de UX (aún no
//  genera nada); es la puerta al futuro loop prompt → corte.
//
//  Diseño minimal (inspirado en asistentes tipo Nixtio / Verba): saludo
//  editorial a dos tonos arriba, mucho aire, sugerencias en chips sutiles y una
//  sola barra de entrada con micrófono abajo. Sin tarjetas ni marcos pesados.
//

import SwiftUI
import UIKit

/// Trazo de la "k" de Haku (recreación vectorial del isotipo). Fondo
/// transparente y tintable.
struct HakuKMark: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: r.minX + x * w, y: r.minY + y * h)
        }
        var path = Path()
        // Asta vertical con una leve curva (hecha a mano).
        path.move(to: pt(0.45, 0.06))
        path.addQuadCurve(to: pt(0.34, 0.94), control: pt(0.33, 0.50))
        // Brazo superior y pierna, saliendo de la unión sobre el asta.
        path.move(to: pt(0.83, 0.12))
        path.addLine(to: pt(0.39, 0.56))
        path.addLine(to: pt(0.87, 0.92))
        return path
    }
}

/// Isotipo de Haku Studio. Usa el PNG de marca `HakuMark` si está en el asset
/// catalog; si no, dibuja la "k" vectorial. Transparente y tintable.
struct HakuStudioMark: View {
    var size: CGFloat = 22
    var color: Color = HakuColor.textPrimary

    var body: some View {
        Group {
            if let ui = UIImage(named: "HakuMark") {
                Image(uiImage: ui)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
            } else {
                HakuKMark()
                    .stroke(style: StrokeStyle(lineWidth: size * 0.2, lineCap: .round, lineJoin: .round))
            }
        }
        .foregroundStyle(color)
        .frame(width: size, height: size)
    }
}

struct CraftView: View {
    @State private var prompt: String = ""
    @State private var listening = false
    @State private var selectedClipIDs: Set<String> = []
    @State private var selectedTags: Set<String> = []
    @State private var visibleClips: [Video] = []
    @State private var visibleTags: [String] = []
    @State private var appeared = false
    @State private var shuffleTick = 0
    @FocusState private var promptFocused: Bool

    /// Toda la biblioteca ordenada por recencia (mock): el pool de clips.
    private let clipPool: [Video] = MockLibrary.allMedia
        .sorted { ($0.modifiedAt ?? 0) > ($1.modifiedAt ?? 0) }

    /// Etiquetas por frecuencia en la biblioteca: el pool de etiquetas.
    private var tagPool: [String] {
        var counts: [String: Int] = [:]
        for v in MockLibrary.allMedia { for t in v.tags { counts[t, default: 0] += 1 } }
        return counts
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .map(\.key)
    }

    private var hasPrompt: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var selectionCount: Int { selectedClipIDs.count + selectedTags.count }
    private var canCreate: Bool { hasPrompt || selectionCount > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            eyebrow
            greeting
                .padding(.top, HakuSpacing.lg)

            Spacer(minLength: HakuSpacing.xl)

            recommendations
                .padding(.bottom, HakuSpacing.lg)
            inputBar
            hint
                .padding(.top, HakuSpacing.sm)
        }
        .padding(.horizontal, HakuSpacing.lg)
        .padding(.top, 72)
        .padding(.bottom, HakuLayout.bottomInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(HakuColor.background)
        .toolbar(.hidden, for: .navigationBar)
        .animation(.snappy(duration: 0.28), value: canCreate)
        .contentShape(Rectangle())
        .onTapGesture { promptFocused = false }
        .onAppear(perform: primeRecommendations)
    }

    /// Llena las recomendaciones y dispara la entrada escalonada la 1ª vez.
    private func primeRecommendations() {
        if visibleClips.isEmpty {
            visibleClips = Array(clipPool.prefix(8))
            visibleTags = Array(tagPool.prefix(6))
        }
        guard !appeared else { return }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) { appeared = true }
    }

    /// Baraja las sugerencias de Haku: nuevas ideas con un resorte.
    private func reshuffle() {
        Haptics.light()
        shuffleTick += 1
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            visibleClips = Array(clipPool.shuffled().prefix(8))
            visibleTags = Array(tagPool.shuffled().prefix(6))
        }
    }

    // MARK: - Encabezado

    private var eyebrow: some View {
        HStack(spacing: 6) {
            HakuStudioMark(size: 18, color: HakuColor.textTertiary)
            Text("Haku Studio")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(HakuColor.textTertiary)
        }
    }

    /// Saludo editorial a dos tonos, grande y aireado.
    private var greeting: some View {
        (Text("Hola,\n").foregroundColor(HakuColor.textTertiary)
         + Text("¿qué quieres\ncrear hoy?").foregroundColor(HakuColor.textPrimary))
            .font(.system(size: 38, weight: .bold))
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Recomendaciones de Haku

    /// Bloque minimal: clips y etiquetas que Haku sugiere usar. Lo seleccionado
    /// alimenta la creación (junto con el prompt).
    private var recommendations: some View {
        VStack(alignment: .leading, spacing: HakuSpacing.md) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(HakuColor.textTertiary)
                    .symbolEffect(.variableColor.iterative, options: .repeating)
                Text("Haku sugiere")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(HakuColor.textTertiary)
                Spacer()
                exploreButton
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HakuSpacing.sm) {
                    ForEach(Array(visibleClips.enumerated()), id: \.element.id) { i, v in
                        clipTile(v, index: i)
                    }
                }
                .padding(.vertical, 3) // aire para el borde de selección
            }

            FlowLayout(spacing: HakuSpacing.sm) {
                ForEach(Array(visibleTags.enumerated()), id: \.element) { i, t in
                    tagChip(t, index: i)
                }
            }
        }
    }

    /// "Explorar": baraja las sugerencias; el ícono gira con resorte al tocar.
    private var exploreButton: some View {
        Button(action: reshuffle) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .bold))
                    .rotationEffect(.degrees(Double(shuffleTick) * 180))
                Text("Explorar")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(HakuColor.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(HakuColor.surfaceMuted, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: shuffleTick)
    }

    private func clipTile(_ v: Video, index: Int) -> some View {
        let sel = selectedClipIDs.contains(v.id)
        return Button {
            Haptics.light()
            if sel { selectedClipIDs.remove(v.id) } else { selectedClipIDs.insert(v.id) }
        } label: {
            PlaceholderThumbnail(seed: v.videoID)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: HakuRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: HakuRadius.md, style: .continuous)
                        .stroke(sel ? HakuColor.accent : HakuColor.hairline, lineWidth: sel ? 2.5 : 1)
                )
                .overlay(alignment: .topTrailing) {
                    if sel {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(HakuColor.accent)
                            .background(Circle().fill(.white).padding(1))
                            .padding(4)
                            .symbolEffect(.bounce, value: sel)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if let d = v.durationLabel {
                        Text(d)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(.black.opacity(0.45), in: Capsule())
                            .padding(4)
                    }
                }
                .opacity(sel ? 1 : 0.92)
        }
        .buttonStyle(ScaleButtonStyle())
        .scaleEffect(sel ? 1.05 : 1)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(Double(index) * 0.05), value: appeared)
        .animation(.spring(response: 0.32, dampingFraction: 0.6), value: sel)
        .transition(.scale.combined(with: .opacity))
    }

    private func tagChip(_ t: String, index: Int) -> some View {
        let sel = selectedTags.contains(t)
        return Button {
            Haptics.light()
            if sel { selectedTags.remove(t) } else { selectedTags.insert(t) }
        } label: {
            Text(t)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(sel ? .white : HakuColor.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(sel ? HakuColor.accent : HakuColor.surfaceMuted, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .scaleEffect(sel ? 1.06 : 1)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.2 + Double(index) * 0.04), value: appeared)
        .animation(.spring(response: 0.3, dampingFraction: 0.58), value: sel)
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Entrada

    private var inputBar: some View {
        HStack(spacing: HakuSpacing.sm) {
            ZStack(alignment: .leading) {
                if prompt.isEmpty {
                    Text("Describe tu video…")
                        .font(.system(size: 16))
                        .foregroundStyle(HakuColor.textTertiary)
                }
                TextField("", text: $prompt, axis: .vertical)
                    .font(.system(size: 16))
                    .foregroundStyle(HakuColor.textPrimary)
                    .tint(HakuColor.textPrimary)
                    .lineLimit(1...4)
                    .focused($promptFocused)
            }
            .padding(.horizontal, HakuSpacing.lg)
            .padding(.vertical, 14)
            .background(HakuColor.surface, in: Capsule())
            .overlay(Capsule().stroke(HakuColor.hairline, lineWidth: 1))

            trailingButton
        }
    }

    /// Un solo botón que se transforma: micrófono cuando no hay nada; flecha de
    /// crear cuando hay prompt o selección. El símbolo hace morph al cambiar.
    private var trailingButton: some View {
        let filled = canCreate || listening
        return Button {
            Haptics.light()
            if canCreate {
                promptFocused = false // iOS-M3: enviar el prompt al motor.
            } else {
                listening.toggle()
            }
        } label: {
            Image(systemName: canCreate ? "arrow.up" : (listening ? "waveform" : "mic.fill"))
                .font(.system(size: canCreate ? 20 : 19, weight: .semibold))
                .foregroundStyle(filled ? .white : HakuColor.textPrimary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 52, height: 52)
                .background(Circle().fill(filled ? HakuColor.accent : HakuColor.surface))
                .overlay {
                    if !filled { Circle().stroke(HakuColor.hairline, lineWidth: 1) }
                }
        }
        .buttonStyle(ScaleButtonStyle())
        .animation(.snappy(duration: 0.28), value: canCreate)
        .animation(.snappy(duration: 0.28), value: listening)
    }

    @ViewBuilder
    private var hint: some View {
        Group {
            if selectionCount > 0 {
                Text("\(selectionCount) sugerencia\(selectionCount == 1 ? "" : "s") de Haku para tu video")
                    .foregroundStyle(HakuColor.textSecondary)
            } else {
                Text("Vista previa del apartado · pronto conectará con el motor de Haku.")
                    .foregroundStyle(HakuColor.textTertiary)
            }
        }
        .font(.system(size: 11, weight: .medium))
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

/// Feedback háptico ligero para que seleccionar/explorar se sienta táctil.
enum Haptics {
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

#Preview {
    NavigationStack { CraftView() }.preferredColorScheme(.light)
}
