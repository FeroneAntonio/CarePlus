//
//  MediaLoader.swift
//  Care+
//
//  PhotosPicker media loader (image or video)
//

import Foundation
import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers

struct MediaLoader {
    struct Result {
        let imageData: Data?
        let videoURL: URL?
    }

    private struct Movie: Transferable {
        let url: URL

        static var transferRepresentation: some TransferRepresentation {
            FileRepresentation(importedContentType: .movie) { received in
                guard let persistentURL = FileStore.persist(url: received.file, folder: "videos") else {
                    throw CocoaError(.fileWriteUnknown)
                }
                return Self(url: persistentURL)
            }
        }
    }

    /// Loads media from a PhotosPickerItem asynchronously.
    /// - Returns: image data OR video url (best effort).
    static func load(from item: PhotosPickerItem?) async -> Result {
        guard let item else {
            return Result(imageData: nil, videoURL: nil)
        }

        // Try image first
        if let imageData = try? await item.loadTransferable(type: Data.self) {
            return Result(imageData: optimizedImageData(imageData), videoURL: nil)
        }

        // Determine content type (best-effort, iOS16+)
        let preferredContentType: UTType? = {
            if #available(iOS 16, *) {
                return item.supportedContentTypes.first
            } else {
                return nil
            }
        }()

        func isMovieType(_ type: UTType) -> Bool {
            type.conforms(to: .movie)
        }

        // Try direct URL
        if let videoURL = try? await item.loadTransferable(type: URL.self),
           let persistentURL = FileStore.persist(url: videoURL, folder: "videos") {
            return Result(imageData: nil, videoURL: persistentURL)
        }

        // Try custom transferable movie
        if let movie = try? await item.loadTransferable(type: Movie.self) {
            return Result(imageData: nil, videoURL: movie.url)
        }

        // Fallback: raw Data -> temp .mov
        if let contentType = preferredContentType, isMovieType(contentType) {
            if let videoData = try? await item.loadTransferable(type: Data.self) {
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mov")
                do {
                    try videoData.write(to: tempURL, options: .atomic)
                    let persistentURL = FileStore.persist(url: tempURL, folder: "videos")
                    return Result(imageData: nil, videoURL: persistentURL)
                } catch {
                    // fall through
                }
            }
        }

        return Result(imageData: nil, videoURL: nil)
    }

    private static func optimizedImageData(_ data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let longestSide = max(image.size.width, image.size.height)
        let scale = min(1, 1_600 / max(longestSide, 1))
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.82) ?? data
    }
}
