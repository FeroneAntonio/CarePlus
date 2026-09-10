//
//  FileStore.swift
//  Care+
//
//  Temporary file helpers
//

import Foundation

enum FileStore {

    private nonisolated static var mediaRoot: URL? {
        guard let applicationSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }

        let root = applicationSupport.appendingPathComponent("CarePlusMedia", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    nonisolated static func tempURL(ext: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
    }

    nonisolated static func writeTemp(data: Data, ext: String) -> URL? {
        let url = tempURL(ext: ext)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    nonisolated static func persist(url sourceURL: URL, folder: String) -> URL? {
        guard let mediaRoot else { return nil }
        let directory = mediaRoot.appendingPathComponent(folder, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            if sourceURL.path.hasPrefix(directory.path) {
                return sourceURL
            }

            let ext = sourceURL.pathExtension.isEmpty ? "bin" : sourceURL.pathExtension
            let destination = directory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            return destination
        } catch {
            return nil
        }
    }

    nonisolated static func removeManagedFile(at url: URL?) {
        guard let url, let mediaRoot, url.path.hasPrefix(mediaRoot.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
