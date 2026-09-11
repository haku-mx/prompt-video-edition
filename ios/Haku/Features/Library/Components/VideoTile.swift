//
//  VideoTile.swift
//  Un tile de la Galería: portada + insignia de reproducción, estado y duración.
//

import SwiftUI

struct VideoTile: View {
    let video: Video
    /// Relación de aspecto ancho:alto de la portada (1 = cuadrada).
    var aspect: CGFloat = 1
    /// Modo "las imágenes hablan": solo miniatura + duración (sin play/estado).
    var minimalOverlays: Bool = false
    /// Aplica el feedback de presión propio (desactívalo si el contenedor ya
    /// maneja gestos como long-press de selección).
    var pressable: Bool = true

    private var cornerRadius: CGFloat { minimalOverlays ? HakuRadius.sm : HakuRadius.lg }

    var body: some View {
        VStack(alignment: .leading, spacing: HakuSpacing.sm) {
            PlaceholderThumbnail(seed: video.videoID)
                .aspectRatio(aspect, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .overlay {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.35)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                }
                .overlay(alignment: .bottomLeading) {
                    if !minimalOverlays {
                        PlayBadge(size: 30).padding(HakuSpacing.sm)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if let duration = video.durationLabel {
                        Text(duration)
                            .font(.system(size: minimalOverlays ? 10 : 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, minimalOverlays ? 5 : 7)
                            .padding(.vertical, minimalOverlays ? 2 : 3)
                            .background(.black.opacity(0.5), in: Capsule())
                            .padding(minimalOverlays ? 4 : HakuSpacing.sm)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if !minimalOverlays, !video.indexed {
                        StatusPill(text: "Sin indexar").padding(HakuSpacing.sm)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if !minimalOverlays, video.indexed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(HakuColor.ready)
                            .padding(3)
                            .background(.black.opacity(0.35), in: Circle())
                            .padding(HakuSpacing.sm)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(HakuColor.hairline, lineWidth: 1)
                )
        }
        .modifier(OptionalPressable(enabled: pressable))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Video")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        [video.durationLabel, video.indexed ? "indexado" : "sin indexar"]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

/// Aplica `.pressable()` solo si está habilitado.
private struct OptionalPressable: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled { content.pressable() } else { content }
    }
}

/// Pequeña etiqueta redondeada sobre las portadas.
struct StatusPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(HakuFont.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.45), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
    }
}

#Preview {
    let cols = [GridItem(.flexible()), GridItem(.flexible())]
    return LazyVGrid(columns: cols, spacing: 16) {
        VideoTile(video: Video(videoID: "prueba-95208e7c", filename: "prueba.mp4",
                               indexed: true, durationSeconds: 94, modifiedAt: 1, shotCount: 12))
        VideoTile(video: Video(videoID: "viaje-01", filename: "viaje_a_la_playa.mp4",
                               indexed: false, durationSeconds: nil, modifiedAt: 2, shotCount: nil))
    }
    .padding()
    .background(HakuColor.background)
    .preferredColorScheme(.dark)
}
