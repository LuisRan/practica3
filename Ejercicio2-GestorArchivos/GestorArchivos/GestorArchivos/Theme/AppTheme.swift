//
//  AppTheme.swift
//  Temas personalizables: Guinda (IPN) y Azul (ESCOM).
//  Cada color es dinámico: cambia automáticamente entre modo claro y oscuro.
//

import SwiftUI
import UIKit

enum AppTheme: String, CaseIterable, Identifiable {
    case guinda
    case azul

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .guinda: return "Guinda IPN"
        case .azul: return "Azul ESCOM"
        }
    }

    /// Color principal (botones, barras, íconos de carpeta).
    var primary: Color {
        switch self {
        case .guinda:
            return Color(light: UIColor(hex: 0x6F1D46), dark: UIColor(hex: 0xC4668F))
        case .azul:
            return Color(light: UIColor(hex: 0x005B9F), dark: UIColor(hex: 0x5CA8E8))
        }
    }

    /// Color secundario para acentos suaves (fondos de chips, selección).
    var secondary: Color {
        switch self {
        case .guinda:
            return Color(light: UIColor(hex: 0xF4E4EC), dark: UIColor(hex: 0x3A1426))
        case .azul:
            return Color(light: UIColor(hex: 0xE1EEF9), dark: UIColor(hex: 0x0F2A42))
        }
    }

    /// Color de fondo para encabezados.
    var headerGradient: LinearGradient {
        LinearGradient(colors: [primary, primary.opacity(0.7)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

extension Color {
    /// Crea un color que se adapta al `userInterfaceStyle` del sistema.
    init(light: UIColor, dark: UIColor) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}
