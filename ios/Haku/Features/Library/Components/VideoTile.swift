//
//  VideoTile.swift
//  Un tile de la Galería: portada + insignia de reproducción, estado y duración.
//

import SwiftUI

struct VideoTile: View {
    let video: Video
    /// Relación de aspecto ancho:alto de la portada (1 = cuadrada).
    var aspect: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: HakuSpacing.sm) {
            PlaceholderThumbnail(seed: video.videoID)
                .aspectRatio(aspect, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .overlay {
                    // Scrim inferior para que las insignias siempre se lean.
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.35)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                }
                .overlay(alignment: .bottomLeading) {
                    PlayBadge(size: 30).padding(HakuSpacing.sm)
                }
                .overlay(alignment: .bottomTrailing) {
                    if let duration = video.durationLabel {
                        Text(duration)
                            .font(HakuFont.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.5), in: Capsule())
                            .padding(HakuSpacing.sm)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if !video.indexed {
                        StatusPill(text: "Sin indexar")
                            .padding(HakuSpacing.sm)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if video.indexed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(HakuColor.ready)
                            .padding(3)
                            .background(.black.opacity(0.35), in: Circle())
                            .padding(HakuSpacing.sm)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: HakuRadius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: HakuRadius.lg, style: .continuous)
                        .stroke(HakuColor.hairline, lineWidth: 1)
                )

            Text(video.filename)
                .font(HakuFont.body)
                .foregroundStyle(HakuColor.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .pressable()
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
