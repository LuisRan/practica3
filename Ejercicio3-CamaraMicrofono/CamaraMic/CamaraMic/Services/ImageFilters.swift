//
//  ImageFilters.swift
//  Filtros y edición básica con Core Image.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum PhotoFilter: String, CaseIterable, Identifiable {
    case none, mono, noir, sepia, chrome, fade, instant, vivid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Original"
        case .mono: return "Mono"
        case .noir: return "Noir"
        case .sepia: return "Sepia"
        case .chrome: return "Chrome"
        case .fade: return "Fade"
        case .instant: return "Instant"
        case .vivid: return "Vívido"
        }
    }

    /// Color de muestra para el selector (vista previa simplificada).
    var swatch: UIColor {
        switch self {
        case .none: return .systemGray5
        case .mono, .noir: return .darkGray
        case .sepia: return UIColor(red: 0.62, green: 0.48, blue: 0.3, alpha: 1)
        case .chrome: return .systemTeal
        case .fade: return .systemGray3
        case .instant: return .systemOrange
        case .vivid: return .systemPink
        }
    }

    func apply(to image: CIImage) -> CIImage {
        switch self {
        case .none: return image
        case .mono:
            let f = CIFilter.photoEffectMono(); f.inputImage = image; return f.outputImage ?? image
        case .noir:
            let f = CIFilter.photoEffectNoir(); f.inputImage = image; return f.outputImage ?? image
        case .sepia:
            let f = CIFilter.sepiaTone(); f.inputImage = image; f.intensity = 0.9; return f.outputImage ?? image
        case .chrome:
            let f = CIFilter.photoEffectChrome(); f.inputImage = image; return f.outputImage ?? image
        case .fade:
            let f = CIFilter.photoEffectFade(); f.inputImage = image; return f.outputImage ?? image
        case .instant:
            let f = CIFilter.photoEffectInstant(); f.inputImage = image; return f.outputImage ?? image
        case .vivid:
            let f = CIFilter.vibrance(); f.inputImage = image; f.amount = 1.0; return f.outputImage ?? image
        }
    }
}

struct PhotoAdjustments: Equatable {
    var brightness: Float = 0      // -0.5 ... 0.5
    var contrast: Float = 1        // 0.5 ... 1.5
    var saturation: Float = 1      // 0 ... 2
    var rotationQuarterTurns: Int = 0
    var cropSquare = false
    var filter: PhotoFilter = .none
}

enum ImageProcessor {
    static let context = CIContext(options: [.useSoftwareRenderer: false])

    /// Aplica filtro + ajustes y devuelve JPEG.
    static func render(_ image: UIImage, adjustments: PhotoAdjustments, maxDimension: CGFloat? = nil) -> UIImage? {
        guard var ci = CIImage(image: image) else { return nil }
        // Respeta la orientación EXIF original.
        ci = ci.oriented(CGImagePropertyOrientation(image.imageOrientation))

        if let maxDimension {
            let scale = min(1, maxDimension / max(ci.extent.width, ci.extent.height))
            if scale < 1 { ci = ci.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) }
        }

        ci = adjustments.filter.apply(to: ci)

        let controls = CIFilter.colorControls()
        controls.inputImage = ci
        controls.brightness = adjustments.brightness
        controls.contrast = adjustments.contrast
        controls.saturation = adjustments.saturation
        ci = controls.outputImage ?? ci

        let turns = ((adjustments.rotationQuarterTurns % 4) + 4) % 4
        if turns != 0 {
            let orientations: [CGImagePropertyOrientation] = [.up, .left, .down, .right]
            ci = ci.oriented(orientations[turns])
        }

        if adjustments.cropSquare {
            let side = min(ci.extent.width, ci.extent.height)
            let rect = CGRect(x: ci.extent.midX - side / 2, y: ci.extent.midY - side / 2, width: side, height: side)
            ci = ci.cropped(to: rect)
        }

        guard let cg = context.createCGImage(ci, from: ci.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    static func applyFilter(_ filter: PhotoFilter, to data: Data) -> Data {
        guard filter != .none, let image = UIImage(data: data),
              let out = render(image, adjustments: PhotoAdjustments(filter: filter)),
              let jpeg = out.jpegData(compressionQuality: 0.92) else { return data }
        return jpeg
    }
}

extension CGImagePropertyOrientation {
    init(_ ui: UIImage.Orientation) {
        switch ui {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
