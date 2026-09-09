//
//  AddSheet.swift
//  Hoja de "Subir archivos" (Desde Fotos / Desde Archivos). iOS-M1 = solo UX
//  (no sube nada todavía). La creación de colecciones vive en `NewCollectionSheet`.
//

import SwiftUI

struct UploadSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: HakuSpacing.md) {
                sourceRow(icon: "photo.on.rectangle", title: "Desde Fotos",
                          subtitle: "Elegir videos de tu carrete")
                sourceRow(icon: "folder", title: "Desde Archivos",
                          subtitle: "Importar de iCloud u otras apps")
                Spacer()
                Text("Aún no sube nada: la subida real llega en un próximo hito.")
                    .font(HakuFont.caption)
                    .foregroundStyle(HakuColor.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(HakuSpacing.lg)
            .background(HakuColor.background)
            .navigationTitle("Subir archivos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func sourceRow(icon: String, title: String, subtitle: String) -> some View {
        Button {
            // UX only.
        } label: {
            HStack(spacing: HakuSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(HakuColor.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(HakuColor.surfaceMuted, in: RoundedRectangle(cornerRadius: HakuRadius.md, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(HakuFont.cardTitle).foregroundStyle(HakuColor.textPrimary)
                    Text(subtitle).font(HakuFont.caption).foregroundStyle(HakuColor.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(HakuColor.textTertiary)
            }
            .padding(HakuSpacing.md)
            .background(HakuColor.surface, in: RoundedRectangle(cornerRadius: HakuRadius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HakuRadius.md, style: .continuous).stroke(HakuColor.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) { UploadSheet() }
}
