//
//  NoteSheet.swift
//  Nota adjunta a un video o a una carpeta-recuerdo: una miniatura, el texto de
//  la nota (editable) y un campo tipo "preguntar" al pie, inspirado en la
//  captura de referencia. iOS-M1: no se persiste (solo UX).
//

import SwiftUI

/// Contenido de una nota, para presentarla con `.sheet(item:)`.
struct NotePayload: Identifiable {
    let id = UUID()
    let title: String
    let imageSeed: String
    let text: String
}

struct NoteSheet: View {
    let payload: NotePayload

    @Environment(\.dismiss) private var dismiss
    @State private var note: String
    @State private var ask: String = ""
    @State private var chosen: Set<String> = []
    @FocusState private var askFocused: Bool

    private let enrichOptions: [(icon: String, label: String)] = [
        ("music.note", "Música"),
        ("mappin.and.ellipse", "Lugar"),
        ("waveform", "Voz"),
        ("link", "Enlace"),
    ]

    init(payload: NotePayload) {
        self.payload = payload
        _note = State(initialValue: payload.text)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: HakuSpacing.lg) {
                header
                enrichRow
                Divider()
                TextEditor(text: $note)
                    .font(.system(size: 17))
                    .foregroundStyle(HakuColor.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(maxHeight: .infinity)
                askBar
            }
            .padding(HakuSpacing.lg)
            .navigationTitle("Nota")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: HakuSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(payload.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(HakuColor.textPrimary)
                Text("Nota del recuerdo")
                    .font(HakuFont.caption)
                    .foregroundStyle(HakuColor.textSecondary)
            }
            Spacer()
            PlaceholderThumbnail(seed: payload.imageSeed)
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: HakuRadius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: HakuRadius.md, style: .continuous)
                    .stroke(HakuColor.hairline, lineWidth: 1))
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
                        Label(on ? opt.label : "\(opt.label)", systemImage: opt.icon)
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

    private var askBar: some View {
        HStack(spacing: HakuSpacing.sm) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(HakuColor.textSecondary)
            TextField("Pregunta o agrega a la nota…", text: $ask)
                .focused($askFocused)
                .submitLabel(.send)
                .onSubmit { appendAsk() }
            Image(systemName: "mic.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(HakuColor.textSecondary)
        }
        .padding(.horizontal, HakuSpacing.md)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: Capsule())
        .overlay(Capsule().stroke(HakuColor.hairline, lineWidth: 1))
    }

    private func appendAsk() {
        let trimmed = ask.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        note += (note.isEmpty ? "" : "\n\n") + trimmed
        ask = ""
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        NoteSheet(payload: NotePayload(
            title: "surf.mp4",
            imageSeed: "costa-2",
            text: "Las mejores olas del viaje. Grabado justo antes del atardecer."
        ))
        .preferredColorScheme(.light)
    }
}
