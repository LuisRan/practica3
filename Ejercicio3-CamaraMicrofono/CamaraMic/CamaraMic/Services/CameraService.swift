//
//  CameraService.swift
//  Captura de fotos con AVFoundation (AVCaptureSession + AVCapturePhotoOutput).
//  - Permisos de cámara en tiempo de ejecución.
//  - Flash (apagado / encendido / automático).
//  - Cambio de cámara frontal / trasera.
//  - Zoom (videoZoomFactor).
//  El simulador de iOS NO tiene cámara: `isCameraAvailable` es false y la UI
//  ofrece como alternativa la fototeca (PHPickerViewController).
//

import AVFoundation
import UIKit

final class CameraService: NSObject, ObservableObject {
    enum AuthState { case unknown, authorized, denied }

    @Published private(set) var auth: AuthState = .unknown
    @Published private(set) var isCameraAvailable = true
    @Published private(set) var isRunning = false
    @Published var flashMode: AVCaptureDevice.FlashMode = .auto
    @Published private(set) var position: AVCaptureDevice.Position = .back
    @Published private(set) var zoomFactor: CGFloat = 1
    @Published var errorMessage: String?

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var input: AVCaptureDeviceInput?
    private let queue = DispatchQueue(label: "mx.ipn.escom.camara.session")
    private var configured = false
    private var completion: ((Data?) -> Void)?

    // MARK: - Permisos

    @MainActor
    func requestAccess() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            auth = .authorized
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            auth = granted ? .authorized : .denied
        default:
            auth = .denied
        }
        isCameraAvailable = AVCaptureDevice.default(for: .video) != nil
        if auth == .authorized && isCameraAvailable {
            configureIfNeeded()
            start()
        }
    }

    // MARK: - Sesión

    private func configureIfNeeded() {
        queue.async { [self] in
            guard !configured else { return }
            session.beginConfiguration()
            session.sessionPreset = .photo
            if let device = Self.device(for: position),
               let newInput = try? AVCaptureDeviceInput(device: device),
               session.canAddInput(newInput) {
                session.addInput(newInput)
                input = newInput
            } else {
                publishError("No se pudo acceder a la cámara.")
            }
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                photoOutput.maxPhotoQualityPrioritization = .quality
            }
            session.commitConfiguration()
            configured = true
        }
    }

    func start() {
        queue.async { [self] in
            guard configured, !session.isRunning else { return }
            session.startRunning()
            let running = session.isRunning
            DispatchQueue.main.async { self.isRunning = running }
        }
    }

    func stop() {
        queue.async { [self] in
            guard session.isRunning else { return }
            session.stopRunning()
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    private static func device(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera],
            mediaType: .video, position: position)
        return discovery.devices.first ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }

    func switchCamera() {
        queue.async { [self] in
            let newPosition: AVCaptureDevice.Position = position == .back ? .front : .back
            guard let device = Self.device(for: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: device) else { return }
            session.beginConfiguration()
            if let input { session.removeInput(input) }
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                input = newInput
            } else if let input {
                session.addInput(input)
            }
            session.commitConfiguration()
            DispatchQueue.main.async {
                self.position = newPosition
                self.zoomFactor = 1
            }
        }
    }

    /// Zoom con gesto de pinza.
    func setZoom(_ factor: CGFloat) {
        queue.async { [self] in
            guard let device = input?.device else { return }
            let clamped = max(device.minAvailableVideoZoomFactor, min(factor, min(device.maxAvailableVideoZoomFactor, 10)))
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
                DispatchQueue.main.async { self.zoomFactor = clamped }
            } catch {}
        }
    }

    // MARK: - Captura

    func capturePhoto(completion: @escaping (Data?) -> Void) {
        queue.async { [self] in
            guard session.isRunning else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            self.completion = completion
            let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            if photoOutput.supportedFlashModes.contains(flashMode) {
                settings.flashMode = flashMode
            }
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func publishError(_ message: String) {
        DispatchQueue.main.async { self.errorMessage = message }
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let data = error == nil ? photo.fileDataRepresentation() : nil
        if let error { publishError("Error al capturar: \(error.localizedDescription)") }
        let done = completion
        completion = nil
        DispatchQueue.main.async { done?(data) }
    }
}
