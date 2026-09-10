//
//  CollectionDetailScreen.swift
//  Detalle de una colección: su nota (si es recuerdo), sus subcolecciones
//  (navegables) y su media con los mismos gestos temporales (pinch to zoom).
//

import SwiftUI

struct CollectionDetailScreen: View {
    let folder: LibraryFolder
    var onCreateCollection: (String, [Video], Set<String>) -> Void = { _, _, _ in }

    @State private var note: NotePayload?
    @State private var showEditor = false
    @State private var showSwipeHint = true

    // Gesto interactivo: swipe hacia arriba para abrir el editor.
    @State private var pull: CGFloat = 0
    @State private var armed = false
    private let threshold: CGFloat = 96

    private var pullProgress: CGFloat { min(1, max(0, pull / threshold)) }
    private var pullOffset: CGFloat {
        // Un poco de resistencia mantiene el gesto contenido y elegante.
        min(pull * 0.48, 52)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            MediaTimeframeView(media: folder.media, playbackURL: { _ in nil },
                               onCreateCollection: onCreateCollection) {
                VStack(alignment: .leading, spacing: HakuSpacing.lg) {
                    if let text = folder.noteText { noteCard(text) }
                    if !folder.subfolders.isEmpty { subcollections }
                }
            }

            Color.black.opacity(Double(pullProgress) * 0.055)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            pullTab
        }
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $note) { NoteSheet(payload: $0) }
        .fullScreenCover(isPresented: $showEditor) {
            NavigationStack {
                TimelineEditorScreen(folder: folder) {
                    showEditor = false
                }
            }
        }
    }

    // MARK: - Swipe up para editar

    private var pullTab: some View {
        VStack(spacing: 4) {
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(HakuColor.textPrimary)
                .rotationEffect(.degrees(-90))
                .offset(y: -pullProgress * 2)

            Text("swipe up\nto edit")
                .font(.system(size: 11, weight: .medium))
                .tracking(0.2)
                .multilineTextAlignment(.center)
                .foregroundStyle(HakuColor.textSecondary)
        }
        .frame(width: 100, height: 52, alignment: .top)
        .opacity(showSwipeHint ? 0.58 + Double(pullProgress) * 0.2 : 0)
        .blur(radius: showSwipeHint ? 0 : 3)
        .contentShape(Rectangle())
        .gesture(pullGesture)
        .offset(y: -pullOffset)
        .padding(.bottom, HakuLayout.bottomInset)
        .animation(.easeOut(duration: 0.18), value: armed)
        .task {
            do {
                try await Task.sleep(for: .seconds(2))
                withAnimation(.easeOut(duration: 0.5)) {
                    showSwipeHint = false
                }
            } catch { }
        }
    }

    private var pullGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                pull = max(0, -value.translation.height)
                let nowArmed = pull >= threshold
                if nowArmed && !armed {
                    Haptics.light()
                }
                armed = nowArmed
            }
            .onEnded { value in
                let dy: CGFloat = value.translation.height
                let predictedDy: CGFloat = value.predictedEndTranslation.height
                let committed = (-dy) >= threshold || (-predictedDy) >= threshold * 1.15
                if committed {
                    showEditor = true
                }
                withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
                    pull = 0
                    armed = false
                }
            }
    }

    private var subcollections: some View {
        VStack(alignment: .leading, spacing: HakuSpacing.md) {
            HStack(spacing: HakuSpacing.sm) {
                Capsule().fill(HakuColor.accent).frame(width: 3, height: 18)
                Text("Colecciones").font(HakuFont.sectionHeader).foregroundStyle(HakuColor.textPrimary)
            }
            MasonryColumns(items: folder.subfolders, columns: 2, spacing: HakuSpacing.md) { sub in
                NavigationLink(value: sub) {
                    FolderCard(folder: sub)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    private func noteCard(_ text: String) -> some View {
        Button {
            note = NotePayload(title: folder.name, imageSeed: folder.coverSeeds.first ?? folder.name, text: text)
        } label: {
            HStack(alignment: .top, spacing: HakuSpacing.md) {
                Image(systemName: "note.text").font(.system(size: 18, weight: .semibold)).foregroundStyle(HakuColor.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nota del recuerdo").font(HakuFont.caption).foregroundStyle(HakuColor.textSecondary)
                    Text(text).font(HakuFont.body).foregroundStyle(HakuColor.textPrimary).lineLimit(2).multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(HakuColor.textTertiary)
            }
            .padding(HakuSpacing.md)
            .background(HakuColor.surface, in: RoundedRectangle(cornerRadius: HakuRadius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HakuRadius.md, style: .continuous).stroke(HakuColor.hairline, lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
