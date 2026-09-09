//
//  PlaceholderThumbnail.swift
//  Portada abstracta determinista para un video.
//
//  Mientras el backend no sirva frames reales (ver PLAN.md → iOS-M1), cada video
//  se representa con una portada de gradiente estable derivada de un "seed" (su
//  video_id). Se diseña para leerse como una portada intencional —no como una
//  imagen faltante—: gradiente de tres tonos + un brillo suave en diagonal. El
//  mismo video siempre produce la misma portada.
//

import SwiftUI

struct PlaceholderThumbnail: View {
    /// Semilla estable (típicamente `video_id`) para derivar el color.
    let seed: String

    var body: some View {
        let palette = Self.palette(for: seed)
        LinearGradient(
            colors: palette,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            // Brillo suave en la esquina superior para dar volumen.
            RadialGradient(
                colors: [.white.opacity(0.22), .clear],
                center: .init(x: 0.2, y: 0.15),
                startRadius: 2,
                endRadius: 260
            )
            .blendMode(.softLight)
        }
        .overlay {
            // Sombra sutil en la esquina opuesta.
            RadialGradient(
                colors: [.clear, .black.opacity(0.28)],
                center: .init(x: 0.9, y: 0.95),
                startRadius: 20,
                endRadius: 300
            )
        }
    }

    /// Deriva tres tonos HSB estables desde el hash FNV-1a de la semilla.
    static func palette(for seed: String) -> [Color] {
        var hash: UInt64 = 1469598103934665603 // FNV-1a offset basis
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        let hue = Double(hash % 360) / 360
        let hueB = (hue + 0.06).truncatingRemainder(dividingBy: 1)
        let hueC = (hue + 0.90).truncatingRemainder(dividingBy: 1) // ligero salto complementario
        return [
            Color(hue: hue, saturation: 0.52, brightness: 0.72),
            Color(hue: hueB, saturation: 0.64, brightness: 0.50),
            Color(hue: hueC, saturation: 0.72, brightness: 0.30),
        ]
    }
}

/// Insignia de reproducción translúcida, señal de "esto es un video".
struct PlayBadge: View {
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: "play.fill")
            .font(.system(size: size * 0.4, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
    }
}

/// Insignia circular con un glyph, sobre un velo oscuro para leerse sobre
/// cualquier portada. Se usa para el play y las señales de enriquecimiento.
struct GlyphBadge: View {
    let system: String
    var size: CGFloat = 26

    var body: some View {
        Image(systemName: system)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(.black.opacity(0.38), in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
        ForEach(["alpha", "prueba-95208e7c", "boda-2024", "viaje", "sunset", "skate-2"], id: \.self) { s in
            PlaceholderThumbnail(seed: s)
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
    .padding()
    .background(HakuColor.background)
}
