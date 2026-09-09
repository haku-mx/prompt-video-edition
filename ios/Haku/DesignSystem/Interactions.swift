//
//  Interactions.swift
//  Micro-interacciones y estados de carga reutilizables: feedback táctil al
//  presionar, brillo "shimmer" y tiles esqueleto para la carga.
//

import SwiftUI

// MARK: - Pressable (feedback táctil)

private struct PressableModifier: ViewModifier {
    @State private var pressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed ? 0.97 : 1)
            .opacity(pressed ? 0.92 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pressed)
            // No bloquea el scroll ni el tap; solo refleja el estado presionado.
            .onLongPressGesture(minimumDuration: 100, pressing: { pressed = $0 }, perform: {})
    }
}

extension View {
    /// Da al elemento un sutil hundido al presionarlo (sin navegar).
    func pressable() -> some View { modifier(PressableModifier()) }
}

/// Estilo de botón con hundido al presionar. Úsalo en botones/NavigationLink
/// para dar feedback táctil SIN interferir con el tap (a diferencia de
/// `.pressable()`, que usa un gesto y puede tragarse el toque de un link).
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Shimmer (brillo de carga)

private struct ShimmerModifier: ViewModifier {
    @State private var offset: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.12), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 1.4)
                    .offset(x: offset * geo.size.width * 1.4)
                }
            }
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
                    offset = 1.4
                }
            }
    }
}

extension View {
    /// Añade un brillo animado de izquierda a derecha (para esqueletos de carga).
    func shimmering() -> some View { modifier(ShimmerModifier()) }
}

// MARK: - Esqueleto de la Galería

/// Rejilla esqueleto que se muestra mientras carga la Galería. Evita el salto
/// visual de un spinner y comunica la forma del contenido que viene.
struct SkeletonGallery: View {
    private let columns = [
        GridItem(.flexible(), spacing: HakuSpacing.md),
        GridItem(.flexible(), spacing: HakuSpacing.md),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: HakuSpacing.xl) {
            ForEach(0..<2, id: \.self) { section in
                VStack(alignment: .leading, spacing: HakuSpacing.md) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(HakuColor.surfaceMuted)
                        .frame(width: 130, height: 20)
                        .shimmering()
                    LazyVGrid(columns: columns, spacing: HakuSpacing.lg) {
                        ForEach(0..<(section == 0 ? 2 : 4), id: \.self) { _ in
                            VStack(alignment: .leading, spacing: HakuSpacing.sm) {
                                RoundedRectangle(cornerRadius: HakuRadius.lg, style: .continuous)
                                    .fill(HakuColor.surface)
                                    .aspectRatio(1, contentMode: .fit)
                                    .shimmering()
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(HakuColor.surfaceMuted)
                                    .frame(width: 100, height: 13)
                                    .shimmering()
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, HakuSpacing.lg)
        .padding(.top, HakuSpacing.sm)
    }
}

#Preview {
    SkeletonGallery()
        .frame(maxHeight: .infinity, alignment: .top)
        .background(HakuColor.background)
        .preferredColorScheme(.dark)
}
