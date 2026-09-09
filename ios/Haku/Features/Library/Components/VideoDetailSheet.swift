//
//  VideoDetailSheet.swift
//  Detalle de un video: reproductor arriba (AVPlayer si hay URL reproducible;
//  placeholder para clips de ejemplo) y debajo su enriquecimiento + nota.
//  Tocar un video abre esta hoja.
//

import SwiftUI
import AVKit

/// Payload para presentar el detalle con `.sheet(item:)`.
struct VideoDetailPayload: Identifiable {
    let id = UUID()
    let video: Video
    /// URL reproducible (backend) o `nil` si es un clip de ejemplo.
    let playbackURL: URL?
}

struct VideoDetailSheet: View {
    let payload: VideoDetailPayload

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var note: String = ""
    @State private var chosen: Set<String> = []

    private let enrichOptions: [(icon: String, label: String)] = [
        ("music.note", "Música"),
        ("mappin.and.ellipse", "Lugar"),
        ("waveform", "Voz"),
        ("link", "Enlace"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HakuSpacing.lg) {
                    playerArea
                    enrichRow
                    noteEditor
                }
                .padding(HakuSpacing.lg)
            }
            .background(HakuColor.background)
            .scrollContentBackground(.hidden)
            .navigationTitle(payload.video.filename)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } }
            }
        }
        .presentationDragIndicator(.visible)
        .onAppear { if let url = payload.playbackURL { player = AVPlayer(url: url) } }
        .onDisappear { player?.pause() }
    }

    @ViewBuilder
    private var playerArea: some View {
        if let player {
            VideoPlayer(player: player)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: HakuRadius.lg, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: HakuRadius.lg, style: .continuous).stroke(HakuColor.hairline, lineWidth: 1))
        } else {
            PlaceholderThumbnail(seed: payload.video.videoID)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .overlay {
                    VStack(spacing: HakuSpacing.sm) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.white.opacity(0.9))
                        Text("Vista previa · clip de ejemplo")
                            .font(HakuFont.caption)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .shadow(radius: 4)
                }
                .clipShape(RoundedRectangle(cornerRadius: HakuRadius.lg, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: HakuRadius.lg, style: .continuous).stroke(HakuColor.hairline, lineWidth: 1))
        }
    }

    private var enrichRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: HakuSpacing.sm) {
                ForEach(enrichOptions, id: \.label) { opt in
                    let on = chosen.contains(opt.label)
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            if on { chosen.remove(opt.label) } else { chosen.insert(opt.label) }
                        }
                    } label: {
                        Label(opt.label, systemImage: opt.icon)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(on ? .white : HakuColor.textSecondary)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(on ? HakuColor.accent : HakuColor.surfaceMuted, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var noteEditor: some View {
        VStack(alignment: .leading, spacing: HakuSpacing.sm) {
            Text("Nota")
                .font(HakuFont.caption)
                .foregroundStyle(HakuColor.textSecondary)
            ZStack(alignment: .topLeading) {
                if note.isEmpty {
                    Text("Escribe lo que quieras recordar de este clip…")
                        .font(.system(size: 15))
                        .foregroundStyle(HakuColor.textTertiary)
                        .padding(.top, 8).padding(.leading, 5)
                }
                TextEditor(text: $note)
                    .font(.system(size: 15))
                    .foregroundStyle(HakuColor.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
            }
            .padding(HakuSpacing.sm)
            .background(HakuColor.surface, in: RoundedRectangle(cornerRadius: HakuRadius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HakuRadius.md, style: .continuous).stroke(HakuColor.hairline, lineWidth: 1))
        }
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        VideoDetailSheet(payload: VideoDetailPayload(
            video: Video(videoID: "skate-3", filename: "slam.mp4", indexed: true,
                         durationSeconds: 12, modifiedAt: 1, shotCount: nil),
            playbackURL: nil))
        .preferredColorScheme(.light)
    }
}
