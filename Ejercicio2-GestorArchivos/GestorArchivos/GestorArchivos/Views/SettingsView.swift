//
//  SettingsView.swift
//  Preferencias: tema, ordenamiento, archivos ocultos, caché de miniaturas e historial.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var prefs: PreferencesStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var cacheSize: Int64 = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(AppTheme.allCases) { theme in
                        Button {
                            withAnimation { prefs.theme = theme }
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(theme.primary)
                                    .frame(width: 28, height: 28)
                                    .overlay(Circle().stroke(.white, lineWidth: 2))
                                    .shadow(radius: 1)
                                Text(theme.nombre)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if prefs.theme == theme {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(theme.primary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Tema")
                } footer: {
                    Text("Ambos temas se adaptan automáticamente al modo \(colorScheme == .dark ? "oscuro" : "claro") del sistema.")
                }

                Section("Ordenamiento") {
                    Picker("Ordenar por", selection: $prefs.sortOption) {
                        ForEach(SortOption.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Ascendente", isOn: $prefs.sortAscending)
                    Toggle("Mostrar archivos ocultos", isOn: $prefs.showHiddenFiles)
                }

                Section {
                    LabeledContent("Caché de miniaturas",
                                   value: ByteCountFormatter.string(fromByteCount: cacheSize, countStyle: .file))
                    Button("Vaciar caché de miniaturas", role: .destructive) {
                        Task {
                            await ThumbnailCache.shared.clear()
                            cacheSize = await ThumbnailCache.shared.diskUsage()
                        }
                    }
                    Button("Borrar historial de recientes", role: .destructive) {
                        prefs.clearRecents()
                    }
                } header: {
                    Text("Almacenamiento")
                }

                Section("Sandbox de la app") {
                    ForEach(SandboxLocation.allCases) { loc in
                        LabeledContent(loc.title, value: FileService.shared.displayPath(for: loc.url))
                            .font(.footnote)
                    }
                    Text("Los archivos de Documents también aparecen en la app Archivos › En mi iPhone › GestorArchivos (UIFileSharingEnabled y LSSupportsOpeningDocumentsInPlace).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Acerca de") {
                    LabeledContent("Práctica", value: "3 · Ejercicio 2")
                    LabeledContent("Unidad", value: "Apps móviles nativas")
                    LabeledContent("Escuela", value: "ESCOM - IPN")
                }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
            .task { cacheSize = await ThumbnailCache.shared.diskUsage() }
        }
        .tint(prefs.theme.primary)
    }
}
