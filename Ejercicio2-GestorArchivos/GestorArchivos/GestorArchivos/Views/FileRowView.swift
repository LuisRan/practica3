//
//  FileRowView.swift
//  Fila de la lista: ícono por UTType (o miniatura para imágenes/PDF), nombre y detalles.
//

import SwiftUI

struct FileRowView: View {
    @EnvironmentObject private var prefs: PreferencesStore
    let item: FileItem
    var showPath: Bool = false

    @State private var thumbnail: UIImage?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale(identifier: "es_MX")
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            icon
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(item.name)
                        .font(.body)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if prefs.isFavorite(item.url) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                            .accessibilityLabel("Favorito")
                    }
                }
                Text(showPath ? FileService.shared.displayPath(for: item.url.deletingLastPathComponent())
                              : "\(Self.dateFormatter.string(from: item.modificationDate)) · \(item.formattedSize)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
        }
        .task(id: item.url) {
            guard item.kind == .image || item.kind == .pdf || item.kind == .video else { return }
            thumbnail = await ThumbnailCache.shared.thumbnail(for: item.url)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(item.isDirectory ? "Carpeta" : item.typeDescription)
    }

    @ViewBuilder
    private var icon: some View {
        if let thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(item.isDirectory ? prefs.theme.secondary : Color(.secondarySystemFill))
                Image(systemName: item.iconName)
                    .font(.title3)
                    .foregroundStyle(item.isDirectory ? prefs.theme.primary : item.iconColor)
            }
        }
    }
}
