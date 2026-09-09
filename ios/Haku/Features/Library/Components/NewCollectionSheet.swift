//
//  NewCollectionSheet.swift
//  Crear una colección (= álbum = carpeta): nombre, videos incluidos y
//  enriquecimiento opcional (música, lugar, nota, voz, enlaces). La usan tanto
//  el "+" de la biblioteca como la selección por etiquetas en Buscar.
//  iOS-M1: no se persiste (solo UX).
//

import SwiftUI

struct NewCollectionSheet: View {
    /// Videos que sembrarán la colección (puede venir vacío desde el "+").
    var selection: [Video] = []
    /// Se llama al confirmar (nombre, videos, etiquetas de enriquecimiento).
    var onCreate: (String, [Video], Set<String>) -> Void = { _, _, _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var chosen: Set<String> = []

    private let options: [(icon: String, label: String)] = [
        ("music.note", "Música"),
        ("mappin.and.ellipse", "Lugar"),
        ("text.alignleft", "Nota"),
        ("waveform", "Voz"),
        ("link", "Enlace"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HakuSpacing.xl) {
                    nameField
                    if !selection.isEmpty { selectedStrip }
                    enrichSection
                    Text("Aún no se guarda: vista previa del flujo de creación.")
                        .font(HakuFont.caption)
                        .foregroundStyle(HakuColor.textTertiary)
                }
                .padding(HakuSpacing.lg)
            }
            .background(HakuColor.background)
            .scrollContentBackground(.hidden)
            .navigationTitle("Nueva colección")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") {
                        onCreate(name, selection, chosen)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty && selection.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: HakuSpacing.sm) {
            Text("Nombre")
                .font(HakuFont.caption)
                .foregroundStyle(HakuColor.textSecondary)
            TextField("p. ej. Verano en la costa", text: $name)
                .padding(.horizontal, HakuSpacing.md)
                .padding(.vertical, 12)
                .background(HakuColor.surface, in: RoundedRectangle(cornerRadius: HakuRadius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: HakuRadius.md, style: .continuous).stroke(HakuColor.hairline, lineWidth: 1))
        }
    }

    private var selectedStrip: some View {
        VStack(alignment: .leading, spacing: HakuSpacing.sm) {
            Text("\(selection.count) video\(selection.count == 1 ? "" : "s")")
                .font(HakuFont.caption)
                .foregroundStyle(HakuColor.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HakuSpacing.sm) {
                    ForEach(selection) { v in
                        PlaceholderThumbnail(seed: v.videoID)
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: HakuRadius.sm, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: HakuRadius.sm, style: .continuous).stroke(HakuColor.hairline, lineWidth: 1))
                    }
                }
            }
        }
    }

    private var enrichSection: some View {
        VStack(alignment: .leading, spacing: HakuSpacing.sm) {
            Text("Enriquecer")
                .font(HakuFont.caption)
                .foregroundStyle(HakuColor.textSecondary)
            FlowLayout(spacing: HakuSpacing.sm) {
                ForEach(options, id: \.label) { opt in
                    let on = chosen.contains(opt.label)
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            if on { chosen.remove(opt.label) } else { chosen.insert(opt.label) }
                        }
                    } label: {
                        Label(opt.label, systemImage: opt.icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(on ? .white : HakuColor.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(on ? HakuColor.accent : HakuColor.surfaceMuted, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        NewCollectionSheet(selection: Array(MockLibrary.allMedia.prefix(4)))
            .preferredColorScheme(.light)
    }
}
