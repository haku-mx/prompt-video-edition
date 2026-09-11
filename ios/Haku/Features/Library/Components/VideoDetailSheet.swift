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
    @State private var stageWidth: CGFloat = 390
    @State private var showEditor = false

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
                    playerArea // borde a borde
                    VStack(alignment: .leading, spacing: HakuSpacing.lg) {
                        enrichRow
                        noteEditor
                    }
                    .padding(.horizontal, HakuSpacing.lg)
                }
                .padding(.bottom, HakuSpacing.lg)
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
        .overlay {
            SwipeToTimelineOverlay(bottomPadding: HakuSpacing.lg) {
                showEditor = true
            }
        }
        .fullScreenCover(isPresented: $showEditor) {
            NavigationStack {
                TimelineEditorScreen(video: payload.video) {
                    showEditor = false
                }
            }
        }
        .onAppear { if let url = payload.playbackURL { player = AVPlayer(url: url) } }
        .onDisappear { player?.pause() }
    }

    private var ratio: CGFloat { TimelineBuilder.aspect(for: payload.video.videoID) }
    private var stageHeight: CGFloat {
        min(max(stageWidth / ratio, 190), 360)
    }

    /// Reproductor a borde completo que adapta su alto al formato del video.
    private var playerArea: some View {
        ZStack {
            Color.black
            if let player {
                VideoPlayer(player: player).aspectRatio(ratio, contentMode: .fit)
            } else {
                PlaceholderThumbnail(seed: payload.video.videoID)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay {
                        VStack(spacing: HakuSpacing.sm) {
                            Image(systemName: "play.circle.fill").font(.system(size: 44)).foregroundStyle(.white.opacity(0.9))
                            Text("Vista previa · clip de ejemplo").font(HakuFont.caption).foregroundStyle(.white.opacity(0.9))
                        }
                        .shadow(radius: 4)
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: stageHeight)
        .onGeometryChange(for: CGFloat.self) { geometry in
            geometry.size.width
        } action: { width in
            stageWidth = width
        }
        .clipped()
        .overlay(alignment: .topTrailing) {
            Text(formatLabel(ratio)).font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(.black.opacity(0.4), in: Capsule())
                .padding(HakuSpacing.md)
        }
    }

    private func formatLabel(_ r: CGFloat) -> String {
        if abs(r - 16.0/9.0) < 0.05 { return "16:9" }
        if abs(r - 9.0/16.0) < 0.05 { return "9:16" }
        if abs(r - 1.0) < 0.05 { return "1:1" }
        if abs(r - 4.0/5.0) < 0.05 { return "4:5" }
        return String(format: "%.2f", r)
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
