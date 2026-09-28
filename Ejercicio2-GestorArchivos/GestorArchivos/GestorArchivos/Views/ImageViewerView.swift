//
//  ImageViewerView.swift
//  Visor de imágenes con:
//   - Zoom con gesto de pinza (MagnifyGesture)
//   - Rotación con dos dedos (RotateGesture) y botón de rotar 90°
//   - Desplazamiento (DragGesture) cuando hay zoom
//   - Doble toque para alternar zoom 2x / ajuste a pantalla
//

import SwiftUI

struct ImageViewerView: View {
    let url: URL

    @State private var image: UIImage?
    @State private var failed = false

    // Estado confirmado + estado del gesto en curso
    @State private var scale: CGFloat = 1
    @GestureState private var gestureScale: CGFloat = 1
    @State private var rotation: Angle = .zero
    @GestureState private var gestureRotation: Angle = .zero
    @State private var offset: CGSize = .zero
    @GestureState private var gestureOffset: CGSize = .zero
    @State private var fill = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.92).ignoresSafeArea()
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: fill ? .fill : .fit)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .scaleEffect(scale * gestureScale)
                        .rotationEffect(.radians(rotation.radians + gestureRotation.radians))
                        .offset(x: offset.width + gestureOffset.width, y: offset.height + gestureOffset.height)
                        .gesture(magnifyAndRotate.simultaneously(with: drag))
                        .onTapGesture(count: 2) { toggleZoom() }
                        .accessibilityLabel("Imagen \(url.lastPathComponent)")
                        .accessibilityAddTraits(.isImage)
                } else if failed {
                    ContentUnavailableView("Imagen dañada o no soportada", systemImage: "photo.badge.exclamationmark",
                                           description: Text("No se pudo decodificar “\(url.lastPathComponent)”."))
                        .foregroundStyle(.white)
                } else {
                    ProgressView().tint(.white)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button { withAnimation(.spring) { rotation = .degrees(rotation.degrees - 90) } } label: {
                    Image(systemName: "rotate.left")
                }
                .accessibilityLabel("Rotar a la izquierda")
                Button { withAnimation(.spring) { rotation = .degrees(rotation.degrees + 90) } } label: {
                    Image(systemName: "rotate.right")
                }
                .accessibilityLabel("Rotar a la derecha")
                Spacer()
                Text("\(Int(scale * 100))%")
                    .font(.caption.monospacedDigit())
                Spacer()
                Button { withAnimation(.spring) { fill.toggle() } } label: {
                    Image(systemName: fill ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
                .accessibilityLabel(fill ? "Ajustar a pantalla" : "Rellenar pantalla")
                Button("Ajustar") { reset() }
            }
        }
        .task { await loadImage() }
    }

    private var magnifyAndRotate: some Gesture {
        MagnifyGesture()
            .updating($gestureScale) { value, state, _ in state = value.magnification }
            .onEnded { value in
                scale = min(max(scale * value.magnification, 0.5), 8)
                if scale <= 1 { withAnimation(.spring) { offset = .zero } }
            }
            .simultaneously(with:
                RotateGesture()
                    .updating($gestureRotation) { value, state, _ in state = value.rotation }
                    .onEnded { value in rotation = .radians(rotation.radians + value.rotation.radians) }
            )
    }

    private var drag: some Gesture {
        DragGesture()
            .updating($gestureOffset) { value, state, _ in
                if scale > 1 { state = value.translation }
            }
            .onEnded { value in
                if scale > 1 {
                    offset.width += value.translation.width
                    offset.height += value.translation.height
                }
            }
    }

    private func toggleZoom() {
        withAnimation(.spring) {
            if scale > 1 { reset() } else { scale = 2 }
        }
    }

    private func reset() {
        withAnimation(.spring) {
            scale = 1
            rotation = .zero
            offset = .zero
            fill = false
        }
    }

    private func loadImage() async {
        let url = self.url
        let loaded: UIImage? = await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)?.preparingForDisplay()
        }.value
        if let loaded { image = loaded } else { failed = true }
    }
}
