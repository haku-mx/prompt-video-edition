//
//  CraftView.swift
//  "Craft" (Haku Studio): apartado para crear videos con los assets de la
//  biblioteca por dictado de voz o escritura. iOS-M1: placeholder de UX (aún no
//  genera nada); es la puerta al futuro loop prompt → corte.
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

    private let examples = [
        "Un resumen de 30s del viaje a la costa con música alegre",
        "Los mejores momentos de la boda, cortes al ritmo",
        "Reel vertical de skate con los mejores trucos",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HakuSpacing.lg) {
                HStack(spacing: HakuSpacing.sm) {
                    HakuStudioMark(size: 32)
                    Text("Haku Studio")
                        .font(HakuFont.caption)
                        .foregroundStyle(HakuColor.textSecondary)
                }

                Text("Crea un video con tu biblioteca")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(HakuColor.textPrimary)
                Text("Dicta o escribe qué quieres armar. Haku Studio usará tus fotos y videos para proponer un primer corte.")
                    .font(HakuFont.body)
                    .foregroundStyle(HakuColor.textSecondary)

                promptCard

                VStack(alignment: .leading, spacing: HakuSpacing.sm) {
                    Text("Ejemplos")
                        .font(HakuFont.caption).foregroundStyle(HakuColor.textSecondary)
                    ForEach(examples, id: \.self) { ex in
                        Button { prompt = ex } label: {
                            HStack {
                                Image(systemName: "text.quote").foregroundStyle(HakuColor.textTertiary)
                                Text(ex).font(HakuFont.body).foregroundStyle(HakuColor.textPrimary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding(HakuSpacing.md)
                            .background(HakuColor.surface, in: RoundedRectangle(cornerRadius: HakuRadius.md, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: HakuRadius.md, style: .continuous).stroke(HakuColor.hairline, lineWidth: 1))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
            .padding(.horizontal, HakuSpacing.lg)
            .padding(.top, HakuSpacing.sm)
            .padding(.bottom, HakuLayout.bottomInset)
        }
        .background(HakuColor.background)
        .scrollContentBackground(.hidden)
        .navigationTitle("Create")
        .navigationBarTitleDisplayMode(.large)
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: HakuSpacing.md) {
            ZStack(alignment: .topLeading) {
                if prompt.isEmpty {
                    Text("p. ej. Un reel de mi verano con las mejores olas…")
                        .font(.system(size: 16))
                        .foregroundStyle(HakuColor.textTertiary)
                        .padding(.top, 10).padding(.leading, 6)
                }
                TextEditor(text: $prompt)
                    .font(.system(size: 16))
                    .foregroundStyle(HakuColor.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
            }
            HStack {
                Button {
                    withAnimation(.snappy) { listening.toggle() }
                } label: {
                    Label(listening ? "Escuchando…" : "Dictar",
                          systemImage: listening ? "waveform" : "mic.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(listening ? .white : HakuColor.textPrimary)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(listening ? HakuColor.accent : HakuColor.surfaceMuted, in: Capsule())
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    // iOS-M3: enviar el prompt al motor (prompt → corte).
                } label: {
                    Label("Crear", systemImage: "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(HakuColor.textPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(prompt.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(prompt.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            }
            Text("Aún no genera cortes: vista previa del apartado. Próximamente conectará con el motor de Haku.")
                .font(HakuFont.caption).foregroundStyle(HakuColor.textTertiary)
        }
        .padding(HakuSpacing.md)
        .background(HakuColor.surface, in: RoundedRectangle(cornerRadius: HakuRadius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: HakuRadius.lg, style: .continuous).stroke(HakuColor.hairline, lineWidth: 1))
    }
}

#Preview {
    NavigationStack { CraftView() }.preferredColorScheme(.light)
}
