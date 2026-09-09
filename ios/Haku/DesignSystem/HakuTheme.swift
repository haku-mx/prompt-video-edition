//
//  HakuTheme.swift
//  Tokens de diseño de Haku: color, tipografía, espaciado, radios y layout.
//
//  "Haku" = blanco. La identidad visual es blanca: fondo y controles (glass)
//  claros, con tinta oscura para legibilidad. La chrome usa Liquid Glass
//  (iOS 26): controles flotantes translúcidos sobre el contenido.
//

import SwiftUI

enum HakuColor {
    /// Fondo base: blanco cálido apenas apagado (deja "ver" el glass encima).
    static let background = Color(hex: 0xF3F3F0)
    /// Superficie de tarjetas: blanco puro.
    static let surface = Color(hex: 0xFFFFFF)
    /// Superficie sutil (chips, esqueletos).
    static let surfaceMuted = Color(hex: 0xE9E9E4)
    /// Tinta primaria (casi negro).
    static let textPrimary = Color(hex: 0x1A1A1F)
    /// Tinta secundaria.
    static let textSecondary = Color(hex: 0x66666E)
    /// Tinta terciaria / apagada.
    static let textTertiary = Color(hex: 0x9A9AA0)
    /// Grafito para acentos mínimos (barra de sección, spinners).
    static let accent = Color(hex: 0x1C1C22)
    /// Verde de estado "indexado / listo".
    static let ready = Color(hex: 0x2FA968)
    /// Línea sutil sobre superficies claras.
    static let hairline = Color.black.opacity(0.10)
}

enum HakuSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum HakuRadius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 18
    static let pill: CGFloat = 999
}

/// Alturas que reserva la chrome flotante, para que el contenido no quede tapado.
enum HakuLayout {
    /// Inset superior: deja pasar el contenido bajo el control flotante de arriba.
    static let topInset: CGFloat = 62
    /// Inset inferior: deja espacio sobre la botonera flotante.
    static let bottomInset: CGFloat = 96
}

enum HakuFont {
    /// Título grande (editorial).
    static let display = Font.system(size: 32, weight: .bold, design: .default)
    /// Cabecera de sección.
    static let sectionHeader = Font.system(size: 20, weight: .semibold)
    /// Título de tarjeta.
    static let cardTitle = Font.system(size: 16, weight: .semibold)
    /// Cuerpo.
    static let body = Font.system(size: 15, weight: .regular)
    /// Etiqueta pequeña / chips.
    static let caption = Font.system(size: 12, weight: .medium)
}

// MARK: - Helpers

extension Color {
    /// Crea un color desde un entero hexadecimal (0xRRGGBB).
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
