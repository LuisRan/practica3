//
//  TextFileView.swift
//  Visor/editor de archivos de texto (.txt, .md, .swift, .json, ...).
//  Markdown puede verse renderizado; JSON puede formatearse.
//

import SwiftUI

struct TextFileView: View {
    let url: URL

    @State private var text = ""
    @State private var original = ""
    @State private var truncated = false
    @State private var error: String?
    @State private var isEditing = false
    @State private var renderMarkdown = true
    @State private var fontSize: CGFloat = 14
    @State private var loaded = false
    @State private var jsonError = false

    private var ext: String { url.pathExtension.lowercased() }
    private var isMarkdown: Bool { ext == "md" || ext == "markdown" }
    private var isJSON: Bool { ext == "json" }

    var body: some View {
        Group {
            if let error {
                ContentUnavailableView("No se pudo abrir", systemImage: "doc.badge.exclamationmark",
                                       description: Text(error))
            } else if !loaded {
                ProgressView("Cargando…")
            } else if isEditing {
                TextEditor(text: $text)
                    .font(.system(size: fontSize, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, 8)
            } else {
                ScrollView([.vertical, .horizontal]) {
                    Group {
                        if isMarkdown && renderMarkdown,
                           let attributed = try? AttributedString(
                            markdown: text,
                            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                            Text(attributed)
                                .font(.system(size: fontSize + 2))
                        } else {
                            Text(text)
                                .font(.system(size: fontSize, design: .monospaced))
                        }
                    }
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
            }
        }
        .safeAreaInset(edge: .top) {
            if truncated {
                Label("Archivo grande: se muestran solo los primeros 2 MB (solo lectura).", systemImage: "info.circle")
                    .font(.caption)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.yellow.opacity(0.2))
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button { fontSize = max(10, fontSize - 2) } label: { Image(systemName: "textformat.size.smaller") }
                Button { fontSize = min(28, fontSize + 2) } label: { Image(systemName: "textformat.size.larger") }
                Spacer()
                if isMarkdown && !isEditing {
                    Toggle(isOn: $renderMarkdown) { Image(systemName: "text.badge.star") }
                        .toggleStyle(.button)
                }
                if isJSON && !isEditing {
                    Button("Formatear") { prettyPrintJSON() }
                }
                if !truncated {
                    if isEditing {
                        Button("Cancelar") { text = original; isEditing = false }
                        Button("Guardar") { save() }.bold()
                    } else {
                        Button("Editar") { isEditing = true }
                    }
                }
            }
        }
        .task { load() }
        .alert("JSON inválido", isPresented: $jsonError) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text("El contenido no es JSON válido o el archivo está dañado.")
        }
    }

    private func load() {
        guard !loaded else { return }
        do {
            let result = try FileService.shared.readText(url)
            text = result.text
            original = result.text
            truncated = result.truncated
        } catch {
            self.error = error.localizedDescription
        }
        loaded = true
    }

    private func save() {
        do {
            try FileService.shared.writeText(text, to: url)
            original = text
            isEditing = false
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func prettyPrintJSON() {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8) else {
            jsonError = true
            return
        }
        text = str
    }
}
