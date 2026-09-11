//
//  TimelineEditorScreen.swift
//  Editor estilo CapCut/Premiere adaptado al estilo Haku (claro, minimal).
//
//  - Preview a borde completo arriba, que adapta su alto al formato del video.
//  - Timeline con eje de tiempo compartido: regla arriba, cabezal (playhead),
//    una pista de video secuencial y una pista opcional de música.
//  - Barra de herramientas inferior tipo iMovie (dividir, velocidad, filtro,
//    volumen, texto) — andamiaje de UX por ahora.
//
//  Se abre con un long swipe hacia arriba desde la colección (sin botón).
//  Front-end/mock: fotogramas, música, versiones, herramientas y guardado son UX.
//

import SwiftUI

struct TimelineEditorScreen: View {
    let folder: LibraryFolder
    let onClose: () -> Void

    @State private var tracks: [EditTrack]
    @State private var selectedClipID: String?
    @State private var playheadTime: Double = 0
    @State private var mutedTracks: Set<String> = []
    @State private var activeTool: String?
    @State private var detailVideo: VideoDetailPayload?
    // Escala del timeline: puntos por segundo (ajustable con pinch).
    @State private var scale: CGFloat = 9
    @State private var scaleAtPinchStart: CGFloat?
    @State private var previewWidth: CGFloat = 390

    private let laneHeight: CGFloat = 54
    private let laneGap: CGFloat = 8
    private let rulerHeight: CGFloat = 20
    private let gutterWidth: CGFloat = 60

    init(folder: LibraryFolder, onClose: @escaping () -> Void) {
        self.folder = folder
        self.onClose = onClose
        _tracks = State(initialValue: TimelineBuilder.tracks(for: folder))
    }

    init(video: Video, onClose: @escaping () -> Void) {
        self.init(
            folder: LibraryFolder(name: video.filename, media: [video]),
            onClose: onClose
        )
    }

    // MARK: - Derivados

    private struct Laid: Identifiable { let id: String; let clip: VideoClip; let start: Double; let width: CGFloat }

    private func laid(_ t: EditTrack) -> [Laid] {
        var out: [Laid] = []
        var acc = 0.0
        for c in t.clips {
            let d = TimelineBuilder.duration(of: c.video)
            out.append(Laid(id: c.id, clip: c, start: acc, width: CGFloat(d) * scale))
            acc += d
        }
        return out
    }
    private func duration(_ t: EditTrack) -> Double {
        t.clips.reduce(0) { $0 + TimelineBuilder.duration(of: $1.video) }
    }
    private var videoTracks: [EditTrack] { tracks.filter { $0.kind == .video } }
    private var timelineDuration: Double { max(1, videoTracks.map(duration).max() ?? 1) }
    private var contentWidth: CGFloat { max(240, CGFloat(timelineDuration) * scale) }
    private var primaryTrack: EditTrack? { tracks.first { $0.kind == .video } }

    private var allClips: [VideoClip] { tracks.flatMap(\.clips) }
    private var selectedClip: VideoClip? { allClips.first { $0.id == selectedClipID } }

    private func clipAt(_ time: Double, in t: EditTrack?) -> VideoClip? {
        guard let t else { return nil }
        let ls = laid(t)
        for l in ls where time >= l.start && time < l.start + Double(l.width / scale) { return l.clip }
        return ls.last?.clip
    }
    private var previewClip: VideoClip? { selectedClip ?? clipAt(playheadTime, in: primaryTrack) }

    private var trackTags: [String: String] {
        var d: [String: String] = [:]; var v = 0; var a = 0
        for t in tracks { if t.kind == .video { v += 1; d[t.id] = "V\(v)" } else { a += 1; d[t.id] = "A\(a)" } }
        return d
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            preview
            timelineArea
            if let clip = selectedClip { inspector(clip) }
            toolbar
        }
        .background(HakuColor.background)
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onClose) {
                    Image(systemName: "xmark").foregroundStyle(.white)
                }
                .accessibilityLabel("Cerrar editor")
            }
            ToolbarItem(placement: .topBarTrailing) { versionsMenu }
        }
        .sheet(item: $detailVideo) { VideoDetailSheet(payload: $0) }
    }

    // MARK: - Preview (borde a borde, adapta al formato)

    private var previewSeed: String {
        previewClip?.frames.first?.seed ?? previewClip?.video.videoID ?? folder.name
    }
    private var previewRatio: CGFloat {
        TimelineBuilder.aspect(for: previewClip?.video.videoID ?? folder.name)
    }
    private var previewHeight: CGFloat {
        min(max(previewWidth / previewRatio, 190), 300)
    }

    private var preview: some View {
        ZStack {
            PlaceholderThumbnail(seed: previewSeed)
            if previewClip == nil {
                VStack(spacing: HakuSpacing.sm) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 34, weight: .medium))
                    Text("Esta colección no tiene videos")
                        .font(HakuFont.body)
                }
                .foregroundStyle(.white.opacity(0.9))
            }
        }
            .frame(maxWidth: .infinity)
            .frame(height: previewHeight)
            .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.size.width
            } action: { width in
                previewWidth = width
            }
            .clipped()
            .overlay { LinearGradient(colors: [.clear, .black.opacity(0.3)], startPoint: .center, endPoint: .bottom) }
            .overlay { PlayBadge(size: 46) }
            .overlay(alignment: .bottomLeading) { previewChip }
            .overlay(alignment: .bottomTrailing) { formatBadge }
            .background(Color.black)
            .animation(.snappy(duration: 0.28), value: previewHeight)
    }

    @ViewBuilder private var previewChip: some View {
        if let clip = previewClip {
            HStack(spacing: 6) {
                Circle().fill(clip.color).frame(width: 8, height: 8)
                Text(clip.video.filename).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                Text("· \(timecode(playheadTime))").font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.black.opacity(0.4), in: Capsule())
            .padding(HakuSpacing.md)
        }
    }
    private var formatBadge: some View {
        Text(formatLabel(previewRatio))
            .font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.black.opacity(0.4), in: Capsule())
            .padding(HakuSpacing.md)
    }

    // MARK: - Timeline multipista con eje compartido

    private var timelineArea: some View {
        ScrollView(.vertical, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                gutter
                ScrollView(.horizontal, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: laneGap) {
                            ruler
                            ForEach(tracks) { lane($0) }
                        }
                        playhead
                    }
                    .frame(width: contentWidth + 24, alignment: .topLeading)
                    .contentShape(Rectangle())
                    .simultaneousGesture(tapToScrub)
                    .simultaneousGesture(pinchToZoom)
                }
            }
            .padding(.vertical, HakuSpacing.sm)
        }
        .frame(maxHeight: .infinity)
    }

    /// Tap para mover el cabezal (no bloquea el scroll horizontal).
    private var tapToScrub: some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                playheadTime = min(max(0, Double(value.location.x / scale)), timelineDuration)
                Haptics.light()
            }
    }

    /// Pinch para expandir/comprimir el timeline.
    private var pinchToZoom: some Gesture {
        MagnifyGesture()
            .onChanged { v in
                let base = scaleAtPinchStart ?? scale
                scaleAtPinchStart = base
                scale = min(max(base * v.magnification, 4), 48)
            }
            .onEnded { _ in scaleAtPinchStart = nil }
    }

    private var gutter: some View {
        VStack(spacing: laneGap) {
            Color.clear.frame(height: rulerHeight)
            ForEach(tracks) { t in gutterHeader(t).frame(height: laneHeight) }
        }
        .frame(width: gutterWidth)
        .padding(.leading, 12)
    }

    private func gutterHeader(_ t: EditTrack) -> some View {
        let muted = mutedTracks.contains(t.id)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Text(trackTags[t.id] ?? "").font(.system(size: 12, weight: .bold)).foregroundStyle(HakuColor.textPrimary)
                Circle().fill(t.color).frame(width: 7, height: 7)
            }
            Button { toggleMute(t.id) } label: {
                Image(systemName: muted
                      ? (t.kind == .music ? "speaker.slash.fill" : "eye.slash.fill")
                      : (t.kind == .music ? "speaker.wave.2.fill" : "eye.fill"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(muted ? HakuColor.textTertiary : HakuColor.textSecondary)
            }.buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Intervalo de marcas adaptado al zoom (apunta a ~90 pt entre marcas).
    private var tickInterval: Double {
        let target = Double(90 / scale)
        let opts: [Double] = [1, 2, 5, 10, 15, 30, 60, 120, 300]
        return opts.first { $0 >= target } ?? 300
    }

    private var ruler: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(stride(from: 0.0, through: timelineDuration, by: tickInterval)), id: \.self) { t in
                VStack(alignment: .leading, spacing: 2) {
                    Rectangle().fill(HakuColor.textTertiary.opacity(0.5)).frame(width: 1, height: 5)
                    Text(timecode(t)).font(.system(size: 9, weight: .medium)).foregroundStyle(HakuColor.textTertiary)
                }
                .offset(x: CGFloat(t) * scale)
            }
        }
        .frame(width: contentWidth + 24, height: rulerHeight, alignment: .topLeading)
    }

    @ViewBuilder
    private func lane(_ t: EditTrack) -> some View {
        let muted = mutedTracks.contains(t.id)
        Group {
            if t.kind == .music {
                musicBar(t)
            } else {
                ZStack(alignment: .leading) {
                    ForEach(laid(t)) { l in
                        clipBlock(l.clip, width: l.width)
                            .offset(x: CGFloat(l.start) * scale)
                    }
                }
                .frame(width: contentWidth + 24, height: laneHeight, alignment: .leading)
            }
        }
        .opacity(muted ? 0.4 : 1)
    }

    private func clipBlock(_ clip: VideoClip, width: CGFloat) -> some View {
        let sel = clip.id == selectedClipID
        let n = max(clip.frames.count, 1)
        let stripWidth = max(width - 4, 1)
        return Button {
            selectClip(clip.id, selected: sel)
            Haptics.light()
        } label: {
            HStack(spacing: 0) {
                ForEach(clip.frames) { f in
                    PlaceholderThumbnail(seed: f.seed)
                        .frame(width: max(1, stripWidth / CGFloat(n)), height: laneHeight - 6)
                        .opacity(f.included ? 1 : 0.3)
                        .clipped()
                }
            }
            .frame(width: stripWidth, height: laneHeight - 6)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(sel ? HakuColor.accent : clip.color.opacity(0.5), lineWidth: sel ? 3 : 1.5))
            .overlay(alignment: .leading) { if sel { trimHandle(.leading) } }
            .overlay(alignment: .trailing) { if sel { trimHandle(.trailing) } }
            .overlay(alignment: .topLeading) {
                if !clip.included {
                    Image(systemName: "eye.slash.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                        .padding(3).background(.black.opacity(0.45), in: Circle()).padding(3)
                }
            }
            .opacity(clip.included ? 1 : 0.5)
            .padding(.horizontal, 2)
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.22), value: sel)
    }

    private func trimHandle(_ edge: HorizontalEdge) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(HakuColor.accent)
            .frame(width: 10, height: laneHeight - 6)
            .overlay {
                Image(systemName: edge == .leading ? "chevron.compact.left" : "chevron.compact.right")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
            }
    }

    private func musicBar(_ t: EditTrack) -> some View {
        HStack(alignment: .center, spacing: 2) {
            let bars = Int((contentWidth) / 5)
            ForEach(0..<max(bars, 1), id: \.self) { i in
                Capsule().fill(t.color.opacity(0.5)).frame(width: 2.5, height: waveHeight(seed: t.name, i: i))
            }
        }
        .frame(width: contentWidth, height: laneHeight - 6, alignment: .leading)
        .padding(.horizontal, 6)
        .background(HakuColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .leading) {
            HStack(spacing: 4) {
                Image(systemName: "music.note").font(.system(size: 10, weight: .bold))
                Text(t.name).font(.system(size: 11, weight: .semibold)).lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(t.color, in: Capsule())
            .padding(.leading, 6)
        }
        .frame(height: laneHeight, alignment: .center)
    }

    private var playhead: some View {
        Rectangle().fill(HakuColor.accent).frame(width: 2)
            .frame(maxHeight: .infinity)
            .overlay(alignment: .top) {
                Circle().fill(HakuColor.accent).frame(width: 11, height: 11).offset(y: -3)
            }
            .offset(x: CGFloat(playheadTime) * scale)
            .allowsHitTesting(false)
    }

    private func waveHeight(seed: String, i: Int) -> CGFloat {
        var h: UInt64 = 1469598103934665603
        for b in "\(seed)-\(i)".utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return 6 + CGFloat(h % 26)
    }

    // MARK: - Inspector del clip

    private func inspector(_ clip: VideoClip) -> some View {
        VStack(alignment: .leading, spacing: HakuSpacing.sm) {
            HStack(spacing: 8) {
                Circle().fill(clip.color).frame(width: 10, height: 10)
                Text(clip.video.filename).font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HakuColor.textPrimary).lineLimit(1)
                Spacer()
                Button { toggleClip(clip.id) } label: {
                    Image(systemName: clip.included ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(clip.included ? HakuColor.accent : HakuColor.textTertiary)
                }.buttonStyle(.plain)
                Button { detailVideo = VideoDetailPayload(video: clip.video, playbackURL: nil) } label: {
                    Image(systemName: "play.rectangle").foregroundStyle(HakuColor.textSecondary)
                }.buttonStyle(.plain)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HakuSpacing.sm) {
                    ForEach(clip.frames) { f in
                        Button { toggleFrame(f.id) } label: {
                            PlaceholderThumbnail(seed: f.seed)
                                .frame(width: 52, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(f.included ? HakuColor.accent : HakuColor.hairline, lineWidth: f.included ? 2.5 : 1))
                                .overlay(alignment: .topTrailing) {
                                    Image(systemName: f.included ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(f.included ? HakuColor.accent : .white)
                                        .padding(2)
                                }
                                .opacity(f.included ? 1 : 0.5)
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(HakuSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HakuColor.surface)
        .overlay(alignment: .top) { Rectangle().fill(HakuColor.hairline).frame(height: 1) }
    }

    // MARK: - Barra de herramientas (iMovie-style, andamiaje)

    private let tools: [(icon: String, label: String)] = [
        ("scissors", "Dividir"),
        ("gauge.with.dots.needle.bottom.50percent", "Velocidad"),
        ("camera.filters", "Filtro"),
        ("speaker.wave.2", "Volumen"),
        ("textformat", "Texto"),
    ]

    private var toolbar: some View {
        HStack(spacing: 0) {
            ForEach(tools, id: \.label) { tool in
                Button {
                    activeTool = tool.label
                    Haptics.light()
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tool.icon).font(.system(size: 18, weight: .regular))
                        Text(tool.label).font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(activeTool == tool.label ? HakuColor.accent : HakuColor.textSecondary)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .disabled(selectedClipID == nil)
                .opacity(selectedClipID == nil ? 0.4 : 1)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(HakuColor.surface)
        .overlay(alignment: .top) { Rectangle().fill(HakuColor.hairline).frame(height: 1) }
    }

    private var versionsMenu: some View {
        Menu {
            Button { } label: { Label("Guardar versión", systemImage: "square.and.arrow.down") }
            Button { } label: { Label("Historial de versiones", systemImage: "clock.arrow.circlepath") }
        } label: {
            Image(systemName: "ellipsis.circle").foregroundStyle(.white)
        }
    }

    // MARK: - Utilidades

    private func timecode(_ sec: Double) -> String {
        let s = Int(sec.rounded())
        return "\(s / 60):" + String(format: "%02d", s % 60)
    }
    private func formatLabel(_ r: CGFloat) -> String {
        if abs(r - 16.0/9.0) < 0.05 { return "16:9" }
        if abs(r - 9.0/16.0) < 0.05 { return "9:16" }
        if abs(r - 1.0) < 0.05 { return "1:1" }
        if abs(r - 4.0/5.0) < 0.05 { return "4:5" }
        return String(format: "%.2f", r)
    }

    // MARK: - Mutaciones

    private func toggleMute(_ id: String) {
        if mutedTracks.contains(id) { mutedTracks.remove(id) } else { mutedTracks.insert(id) }
        Haptics.light()
    }
    private func clipLocation(_ id: String) -> (Int, Int)? {
        for ti in tracks.indices {
            if let ci = tracks[ti].clips.firstIndex(where: { $0.id == id }) { return (ti, ci) }
        }
        return nil
    }
    private func selectClip(_ id: String, selected: Bool) {
        guard !selected, let (trackIndex, _) = clipLocation(id) else {
            selectedClipID = nil
            return
        }
        selectedClipID = id
        if let clip = laid(tracks[trackIndex]).first(where: { $0.id == id }) {
            playheadTime = min(clip.start, timelineDuration)
        }
        activeTool = nil
    }
    private func toggleClip(_ id: String) {
        guard let (ti, ci) = clipLocation(id) else { return }
        withAnimation(.snappy(duration: 0.25)) { tracks[ti].clips[ci].included.toggle() }
        Haptics.light()
    }
    private func toggleFrame(_ frameID: String) {
        for ti in tracks.indices {
            for ci in tracks[ti].clips.indices {
                if let fi = tracks[ti].clips[ci].frames.firstIndex(where: { $0.id == frameID }) {
                    withAnimation(.snappy(duration: 0.22)) { tracks[ti].clips[ci].frames[fi].included.toggle() }
                    Haptics.light(); return
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TimelineEditorScreen(folder: MockLibrary.rootFolders[0], onClose: {})
    }
    .preferredColorScheme(.light)
}
