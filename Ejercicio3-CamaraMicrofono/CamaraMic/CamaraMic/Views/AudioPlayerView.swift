//
//  AudioPlayerView.swift
//  Reproductor (AVAudioPlayer): reproducir/pausar, barra de progreso, ±10 s,
//  velocidad de reproducción, compartir y detalles.
//

import SwiftUI

struct AudioPlayerView: View {
    @ObservedObject var item: MediaItem
    @Environment(\.appTheme) private var theme
    @StateObject private var player = AudioPlayerService()
    @State private var share: ShareItems?
    @State private var showDetails = false
    @State private var isScrubbing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "waveform")
                    .font(.system(size: 70))
                    .foregroundStyle(theme.primary)
                    .symbolEffect(.variableColor.iterative, isActive: player.isPlaying)
                    .padding(.top)

                VStack(spacing: 4) {
                    Text(item.fileName).font(.headline).lineLimit(1)
                    Text(item.createdAt.formatted(date: .long, time: .shortened))
                        .font(.caption).foregroundStyle(.secondary)
                }

                VStack {
                    Slider(value: $player.currentTime, in: 0...max(player.duration, 0.1)) { editing in
                        isScrubbing = editing
                        if !editing { player.seek(to: player.currentTime) }
                    }
                    HStack {
                        Text(player.currentTime.mmss)
                        Spacer()
                        Text("-" + max(0, player.duration - player.currentTime).mmss)
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                HStack(spacing: 40) {
                    Button { player.skip(-10) } label: { Image(systemName: "gobackward.10") }
                        .accessibilityLabel("Retroceder 10 segundos")
                    Button { player.toggle() } label: {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64))
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .accessibilityLabel(player.isPlaying ? "Pausar" : "Reproducir")
                    Button { player.skip(10) } label: { Image(systemName: "goforward.10") }
                        .accessibilityLabel("Adelantar 10 segundos")
                }
                .font(.title)
                .foregroundStyle(theme.primary)

                Picker("Velocidad", selection: $player.rate) {
                    Text("0.5x").tag(Float(0.5))
                    Text("1x").tag(Float(1))
                    Text("1.5x").tag(Float(1.5))
                    Text("2x").tag(Float(2))
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 40)

                Spacer()
            }
            .navigationTitle("Reproductor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { share = ShareItems(urls: [item.fileURL]) } label: {
                            Label("Compartir / Exportar", systemImage: "square.and.arrow.up")
                        }
                        Button { showDetails = true } label: {
                            Label("Etiquetas y álbum", systemImage: "tag")
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .sheet(item: $share) { s in ShareSheet(items: s.urls) }
            .sheet(isPresented: $showDetails) { MetadataEditor(item: item) }
            .alert("Audio", isPresented: Binding(get: { player.errorMessage != nil },
                                                 set: { if !$0 { player.errorMessage = nil } })) {
                Button("Aceptar", role: .cancel) {}
            } message: { Text(player.errorMessage ?? "") }
        }
        .onAppear { player.load(item.fileURL) }
        .onDisappear { player.stop() }
    }
}
