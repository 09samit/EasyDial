//
//  ImageDataOptimizer.swift
//  EasyDial
//
//  Downscales contact photos before SwiftData storage to limit memory use on the home grid.
//

import UIKit

enum ImageDataOptimizer {
  private static let maxPixelSide: CGFloat = 300
  private static let jpegQuality: CGFloat = 0.82

  /// Returns JPEG bytes sized for contact-card thumbnails, or nil when input is unusable.
  static func thumbnailJPEG(from data: Data?) -> Data? {
    guard let data, let image = UIImage(data: data) else { return nil }
    let longest = max(image.size.width, image.size.height)
    guard longest > 0 else { return nil }

    let scale = min(1, maxPixelSide / longest)
    let targetSize = CGSize(
      width: max(1, image.size.width * scale),
      height: max(1, image.size.height * scale)
    )

    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
    let resized = renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: targetSize))
    }
    return resized.jpegData(compressionQuality: jpegQuality)
  }
}
