import AppKit
import Foundation
import ImageIO

// Recolour the locally supplied vendor icon; no Joplin image is distributed.
func buildIcon() throws {
    guard CommandLine.arguments.count == 3 else {
        throw NSError(domain: "DarkIcon", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Usage: darken-icon.swift input.icns output-directory"])
    }
    let input = URL(fileURLWithPath: CommandLine.arguments[1])
    let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
    guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
          let space = CGColorSpace(name: CGColorSpace.sRGB) else {
        throw NSError(domain: "DarkIcon", code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Cannot read the source icon."])
    }
    var largest: CGImage?
    for index in 0..<CGImageSourceGetCount(source) {
        if let candidate = CGImageSourceCreateImageAtIndex(source, index, nil),
           candidate.width > (largest?.width ?? 0) {
            largest = candidate
        }
    }
    guard let original = largest else {
        throw NSError(domain: "DarkIcon", code: 3,
            userInfo: [NSLocalizedDescriptionKey: "The source contains no icon images."])
    }
    let width = original.width, height = original.height
    let flags = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
    guard let context = CGContext(data: nil, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: width * 4, space: space, bitmapInfo: flags),
        let data = context.data else {
        throw NSError(domain: "DarkIcon", code: 4)
    }
    context.draw(original, in: CGRect(x: 0, y: 0, width: width, height: height))
    let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
    for offset in stride(from: 0, to: width * height * 4, by: 4) {
        let alpha = Double(pixels[offset + 3])
        if alpha == 0 { continue }
        let red = Double(pixels[offset]) * 255 / alpha
        let green = Double(pixels[offset + 1]) * 255 / alpha
        let blue = Double(pixels[offset + 2]) * 255 / alpha
        // Preserve the white letter, neutral shadows, and transparency.
        if blue > red + 15 && blue > green + 10 {
            pixels[offset] = UInt8((4 * alpha / 255).rounded())
            pixels[offset + 1] = UInt8((18 * alpha / 255).rounded())
            pixels[offset + 2] = UInt8((35 * alpha / 255).rounded())
        }
    }
    guard let dark = context.makeImage() else {
        throw NSError(domain: "DarkIcon", code: 5)
    }
    let iconset = output.appendingPathComponent("icon.iconset", isDirectory: true)
    try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
    for size in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let n = size * scale
            guard let resized = CGContext(data: nil, width: n, height: n,
                bitsPerComponent: 8, bytesPerRow: n * 4, space: space, bitmapInfo: flags) else {
                throw NSError(domain: "DarkIcon", code: 6)
            }
            resized.interpolationQuality = .high
            resized.draw(dark, in: CGRect(x: 0, y: 0, width: n, height: n))
            let suffix = scale == 2 ? "@2x" : ""
            let file = iconset.appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
            guard let image = resized.makeImage(),
                  let destination = CGImageDestinationCreateWithURL(file as CFURL,
                      "public.png" as CFString, 1, nil) else {
                throw NSError(domain: "DarkIcon", code: 7)
            }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else {
                throw NSError(domain: "DarkIcon", code: 8)
            }
        }
    }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", iconset.path, "-o", output.appendingPathComponent("icon.icns").path]
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw NSError(domain: "DarkIcon", code: 9,
            userInfo: [NSLocalizedDescriptionKey: "iconutil could not package the icon."])
    }
}

do {
    try buildIcon()
} catch {
    fputs("Cannot generate the dark icon: \(error.localizedDescription)\n", stderr)
    exit(1)
}
