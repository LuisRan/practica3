//
//  AudioRecorderView.swift
//  Grabadora: sensibilidad, calidad, temporizador de grabación, medidor de nivel
//  animado y lista de las últimas grabaciones.
//

import SwiftUI
import CoreData

struct AudioRecorderView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.appTheme) private var theme
    @StateObject private var recorder = AudioRecorderService()
    @StateObject private var location = LocationProvider()
    @AppStorage("saveLocation") private var saveLocation = true

    @FetchRequest(entity: PersistenceController.mediaEntity,
                  sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)],
                  predicate: NSPredicate(format: "kind == %@", "audio"))
    private var recordings: FetchedResults<MediaItem>

    @State private var pulse = false
    @State private var playing: MediaItem?

    private let durations: [TimeInterval] = [0, 15, 30, 60, 120]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 18) {
                        LevelMeter(levels: recorder.levelHistory, color: theme.primary)
                            .frame(height: 80)
                            .accessibilityLabel("Nivel de audio")

                        Text(recorder.elapsed.mmss)
                            .font(.system(size: 48, weight: .semibold, design: .monospaced))
                            .contentTransition(.numericText())
                        if recorder.maxDuration > 0 {
                            ProgressView(value: min(recorder.elapsed, recorder.maxDuration), total: recorder.maxDuration)
                            Text("Límite: \(recorder.maxDuration.mmss)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        controls
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section {
                    Picker("Sensibilidad", selection: $recorder.sensitivity) {
                        ForEach(MicSensitivity.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Calidad", selection: $recorder.quality) {
                        ForEach(AudioQuality.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Temporizador", selection: $recorder.maxDuration) {
                        ForEach(durations, id: \.self) { d in
                            Text(d == 0 ? "Sin límite" : "\(Int(d)) s").tag(d)
                        }
                    }
                } header: {
                    Text("Opciones de captura")
                } footer: {
                    Text("La sensibilidad ajusta la ganancia del micrófono (si el dispositivo lo permite) y el umbral del medidor. El temporizador detiene la grabación automáticamente.")
                }
                .disabled(recorder.isRecording)

                Section("Últimas grabaciones") {
                    if recordings.isEmpty {
                        Text("Aún no hay grabaciones.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(recordings.prefix(5)) { item in
                        Button {
                            playing = item
                        } label: {
                            HStack {
                                Image(systemName: "waveform.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(theme.primary)
                                VStack(alignment: .leading) {
                                    Text(item.fileName).lineLimit(1).foregroundStyle(.primary)
                                    Text("\(item.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(item.duration.mmss)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Grabadora")
            .sheet(item: $playing) { item in
                AudioPlayerView(item: item)
                    .presentationDetents([.medium, .large])
            }
            .alert("Micrófono", isPresented: Binding(get: { recorder.errorMessage != nil },
                                                     set: { if !$0 { recorder.errorMessage = nil } })) {
                Button("Aceptar", role: .cancel) {}
            } message: {
                Text(recorder.errorMessage ?? "")
            }
            .overlay {
                if recorder.permissionDenied {
                    ContentUnavailableView {
                        Label("Sin acceso al micrófono", systemImage: "mic.slash.fill")
                    } description: {
                        Text("Activa el permiso en Ajustes › Privacidad › Micrófono.")
                    } actions: {
                        Button("Abrir Ajustes") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .background(.background)
                }
            }
        }
        .onAppear {
            if saveLocation { location.start() }
            recorder.onFinished = { url, duration in
                _ = MediaStore.registerAudio(at: url, duration: duration,
                                         location: saveLocation ? location.lastLocation : nil,
                                         album: nil, context: context)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 36) {
            Button {
                recorder.cancel()
            } label: {
                Image(systemName: "xmark.circle.fill").font(.system(size: 40))
            }
            .disabled(!recorder.isRecording)
            .opacity(recorder.isRecording ? 1 : 0.3)
            .accessibilityLabel("Descartar grabación")

            Button {
                if recorder.isRecording {
                    recorder.stop()
                } else {
                    Task { await recorder.start() }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(theme.primary.opacity(0.25))
                        .frame(width: 96, height: 96)
                        .scaleEffect(recorder.isRecording && !recorder.isPaused ? (pulse ? 1.25 : 1) : 1)
                    Circle()
                        .fill(theme.primary)
                        .frame(width: 76, height: 76)
                    Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(recorder.isRecording ? "Detener" : "Grabar")
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true }
            }

            Button {
                recorder.pauseOrResume()
            } label: {
                Image(systemName: recorder.isPaused ? "play.circle.fill" : "pause.circle.fill")
                    .font(.system(size: 40))
            }
            .disabled(!recorder.isRecording)
            .opacity(recorder.isRecording ? 1 : 0.3)
            .accessibilityLabel(recorder.isPaused ? "Reanudar" : "Pausar")
        }
        .buttonStyle(.borderless)
    }
}

/// Medidor de nivel tipo barras (historial de los últimos niveles).
struct LevelMeter: View {
    let levels: [Float]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 3) {
                ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                    Capsule()
                        .fill(color.opacity(0.35 + Double(level) * 0.65))
                        .frame(height: max(4, CGFloat(level) * geo.size.height))
                        .animation(.linear(duration: 0.05), value: level)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
