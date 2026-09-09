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

    var body: some View {
        MediaTimeframeView(media: folder.media, playbackURL: { _ in nil }) {
            VStack(alignment: .leading, spacing: HakuSpacing.lg) {
                if let text = folder.noteText { noteCard(text) }
                if !folder.subfolders.isEmpty { subcollections }
            }
        }
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $note) { NoteSheet(payload: $0) }
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
