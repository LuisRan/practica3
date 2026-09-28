//
//  CameraView.swift
//  Pantalla de cámara: vista previa, flash, temporizador, filtros, zoom con pinza,
//  doble toque para cambiar de cámara y animación de obturador.
//  En el simulador (sin cámara) ofrece la fototeca (PHPickerViewController).
//

import SwiftUI
import AVFoundation
import CoreData

struct CameraView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.appTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var camera = CameraService()
    @StateObject private var location = LocationProvider()

    @FetchRequest(entity: PersistenceController.albumEntity,
                  sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)])
    private var albums: FetchedResults<Album>

    @AppStorage("saveLocation") private var saveLocation = true
    @State private var filter: PhotoFilter = .none
    @State private var timerSeconds = 0
    @State private var countdown: Int?
    @State private var shutterFlash = false
    @State private var lastThumbnail: UIImage?
    @State private var showLibrary = false
    @State private var targetAlbum: Album?
    @State private var pinchBase: CGFloat = 1
    @State private var savedToast = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            preview
                .ignoresSafeArea(edges: .top)

            // Destello del obturador
            Color.white
                .opacity(shutterFlash ? 0.85 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            if let countdown {
                Text("\(countdown)")
                    .font(.system(size: 120, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(radius: 10)
                    .transition(.scale.combined(with: .opacity))
                    .id(countdown)
            }

            VStack {
                topBar
                Spacer()
                if savedToast {
                    Label("Guardado en la galería", systemImage: "checkmark.circle.fill")
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                filterStrip
                bottomBar
            }
        }
        .task {
            await camera.requestAccess()
            if saveLocation { location.start() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { camera.start() } else { camera.stop() }
        }
        .onDisappear { camera.stop() }
        .onAppear { if camera.auth == .authorized { camera.start() } }
        .sheet(isPresented: $showLibrary) {
            PhotoLibraryPicker { datas in
                showLibrary = false
                for data in datas { save(data) }
            }
            .ignoresSafeArea()
        }
        .alert("Cámara", isPresented: Binding(get: { camera.errorMessage != nil },
                                              set: { if !$0 { camera.errorMessage = nil } })) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(camera.errorMessage ?? "")
        }
    }

    // MARK: - Vista previa / alternativa

    @ViewBuilder
    private var preview: some View {
        switch (camera.auth, camera.isCameraAvailable) {
        case (.denied, _):
            permissionDeniedView
        case (_, false):
            noCameraView
        case (.authorized, true):
            CameraPreview(session: camera.session)
                .modifier(LiveFilterPreview(filter: filter))
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in camera.setZoom(pinchBase * value.magnification) }
                        .onEnded { _ in pinchBase = camera.zoomFactor }
                )
                .onTapGesture(count: 2) {
                    withAnimation { camera.switchCamera() }
                    pinchBase = 1
                }
                .overlay(alignment: .bottom) {
                    if camera.zoomFactor > 1.05 {
                        Text(String(format: "%.1fx", camera.zoomFactor))
                            .font(.caption.bold())
                            .padding(6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(.bottom, 8)
                    }
                }
        default:
            ProgressView().tint(.white)
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill.badge.ellipsis")
                .font(.system(size: 56))
            Text("Sin acceso a la cámara")
                .font(.title2.bold())
            Text("Activa el permiso en Ajustes › Privacidad › Cámara para tomar fotos. Mientras tanto puedes importar desde la fototeca.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
            Button("Abrir Ajustes") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .buttonStyle(.borderedProminent)
        }
        .foregroundStyle(.white)
        .padding(32)
    }

    private var noCameraView: some View {
        VStack(spacing: 16) {
            Image(systemName: "iphone.gen3.slash")
                .font(.system(size: 56))
            Text("Cámara no disponible")
                .font(.title2.bold())
            Text("El simulador de iOS no tiene cámara física. Usa la fototeca (PHPickerViewController) como fuente alternativa: el filtro seleccionado se aplicará al importar.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
            Button {
                showLibrary = true
            } label: {
                Label("Elegir de la fototeca", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.borderedProminent)
        }
        .foregroundStyle(.white)
        .padding(32)
    }

    // MARK: - Controles

    private var topBar: some View {
        HStack(spacing: 18) {
            Button { cycleFlash() } label: {
                Image(systemName: flashIcon)
                    .foregroundStyle(camera.flashMode == .on ? .yellow : .white)
            }
            .accessibilityLabel("Flash: \(flashName)")

            Button { cycleTimer() } label: {
                HStack(spacing: 2) {
                    Image(systemName: "timer")
                    if timerSeconds > 0 { Text("\(timerSeconds)s").font(.caption.bold()) }
                }
                .foregroundStyle(timerSeconds > 0 ? .yellow : .white)
            }
            .accessibilityLabel("Temporizador \(timerSeconds) segundos")

            Spacer()

            Menu {
                Button("Sin álbum") { targetAlbum = nil }
                ForEach(albums) { album in
                    Button(album.name) { targetAlbum = album }
                }
            } label: {
                Label(targetAlbum?.name ?? "Sin álbum", systemImage: "rectangle.stack")
                    .font(.caption.bold())
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
            }

            if saveLocation {
                Image(systemName: location.lastLocation != nil ? "location.fill" : "location.slash")
                    .foregroundStyle(location.lastLocation != nil ? .green : .white.opacity(0.6))
                    .accessibilityLabel(location.lastLocation != nil ? "Ubicación activa" : "Sin ubicación")
            }
        }
        .font(.title3)
        .foregroundStyle(.white)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(PhotoFilter.allCases) { f in
                    Button {
                        withAnimation(.snappy) { filter = f }
                    } label: {
                        VStack(spacing: 4) {
                            Circle()
                                .fill(Color(uiColor: f.swatch))
                                .frame(width: 38, height: 38)
                                .overlay(Circle().stroke(filter == f ? theme.primary : .clear, lineWidth: 3))
                                .scaleEffect(filter == f ? 1.12 : 1)
                            Text(f.title)
                                .font(.caption2)
                                .foregroundStyle(.white)
                        }
                    }
                    .accessibilityLabel("Filtro \(f.title)")
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 6)
    }

    private var bottomBar: some View {
        HStack {
            // Miniatura de la última captura
            Group {
                if let lastThumbnail {
                    Image(uiImage: lastThumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.15))
                }
            }
            .frame(width: 54, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.6), lineWidth: 1))

            Spacer()

            // Obturador
            Button { shutterPressed() } label: {
                ZStack {
                    Circle().stroke(.white, lineWidth: 5).frame(width: 78, height: 78)
                    Circle().fill(theme.primary).frame(width: 64, height: 64)
                    if countdown != nil {
                        Image(systemName: "xmark").foregroundStyle(.white).font(.title2.bold())
                    }
                }
            }
            .disabled(camera.auth != .authorized || !camera.isCameraAvailable)
            .opacity(camera.auth == .authorized && camera.isCameraAvailable ? 1 : 0.4)
            .accessibilityLabel(countdown == nil ? "Tomar foto" : "Cancelar temporizador")

            Spacer()

            VStack(spacing: 14) {
                Button { withAnimation { camera.switchCamera() }; pinchBase = 1 } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                }
                .disabled(!camera.isCameraAvailable)
                .accessibilityLabel("Cambiar cámara")
                Button { showLibrary = true } label: {
                    Image(systemName: "photo.on.rectangle")
                }
                .accessibilityLabel("Importar de la fototeca")
            }
            .font(.title2)
            .foregroundStyle(.white)
            .frame(width: 54)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    // MARK: - Lógica

    private var flashIcon: String {
        switch camera.flashMode {
        case .on: return "bolt.fill"
        case .off: return "bolt.slash.fill"
        default: return "bolt.badge.automatic.fill"
        }
    }

    private var flashName: String {
        switch camera.flashMode {
        case .on: return "encendido"
        case .off: return "apagado"
        default: return "automático"
        }
    }

    private func cycleFlash() {
        switch camera.flashMode {
        case .auto: camera.flashMode = .on
        case .on: camera.flashMode = .off
        default: camera.flashMode = .auto
        }
    }

    private func cycleTimer() {
        timerSeconds = timerSeconds == 0 ? 3 : (timerSeconds == 3 ? 10 : 0)
    }

    private func shutterPressed() {
        if countdown != nil {
            countdown = nil // cancelar temporizador
            return
        }
        guard timerSeconds > 0 else { takePhoto(); return }
        countdown = timerSeconds
        tick()
    }

    private func tick() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            guard let current = countdown else { return }
            if current <= 1 {
                withAnimation { countdown = nil }
                takePhoto()
            } else {
                withAnimation(.spring) { countdown = current - 1 }
                tick()
            }
        }
    }

    private func takePhoto() {
        withAnimation(.easeOut(duration: 0.08)) { shutterFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeIn(duration: 0.25)) { shutterFlash = false }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        camera.capturePhoto { data in
            guard let data else { return }
            save(data)
        }
    }

    private func save(_ raw: Data) {
        let data = ImageProcessor.applyFilter(filter, to: raw)
        do {
            let item = try MediaStore.savePhoto(
                data,
                filter: filter == .none ? nil : filter.title,
                location: saveLocation ? location.lastLocation : nil,
                album: targetAlbum,
                context: context)
            withAnimation(.spring) {
                lastThumbnail = ThumbnailStore.shared.thumbnail(for: item)
                savedToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { savedToast = false }
            }
        } catch {
            camera.errorMessage = "No se pudo guardar la foto: \(error.localizedDescription)"
        }
    }
}

/// Aproximación en vivo del filtro sobre la vista previa (el filtro real
/// de Core Image se aplica al guardar la foto).
struct LiveFilterPreview: ViewModifier {
    let filter: PhotoFilter

    @ViewBuilder
    func body(content: Content) -> some View {
        switch filter {
        case .none: content
        case .mono, .noir: content.grayscale(1).contrast(filter == .noir ? 1.3 : 1)
        case .sepia: content.grayscale(0.9).colorMultiply(Color(red: 1, green: 0.88, blue: 0.7))
        case .chrome: content.contrast(1.2).saturation(1.2)
        case .fade: content.saturation(0.6).brightness(0.05)
        case .instant: content.colorMultiply(Color(red: 1, green: 0.95, blue: 0.85))
        case .vivid: content.saturation(1.6)
        }
    }
}
