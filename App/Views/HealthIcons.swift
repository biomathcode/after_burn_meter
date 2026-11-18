import SwiftUI
import AppKit

// MARK: - Health Icons SVG Helper
// Sourced from Health Icons (https://healthicons.org) - Open source CC0/MIT health icons.
public struct HealthIconView: View {
    public let name: String
    public var size: CGFloat = 24
    public var color: Color = .white

    public init(_ name: String, size: CGFloat = 24, color: Color = .white) {
        self.name = name
        self.size = size
        self.color = color
    }

    public var body: some View {
        if let image = loadIcon(name: name) {
            Image(nsImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundStyle(color)
        } else {
            Image(systemName: fallbackSymbol(for: name))
                .font(.system(size: size * 0.8))
                .foregroundStyle(color)
        }
    }

    private func loadIcon(name: String) -> NSImage? {
        // Try application bundle
        if let url = Bundle.main.url(forResource: name, withExtension: "svg", subdirectory: "HealthIcons") {
            return NSImage(contentsOf: url)
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "svg") {
            return NSImage(contentsOf: url)
        }
        // Try file path in resources
        let devPath = "Resources/HealthIcons/\(name).svg"
        if FileManager.default.fileExists(atPath: devPath) {
            return NSImage(contentsOfFile: devPath)
        }
        return nil
    }

    private func fallbackSymbol(for name: String) -> String {
        switch name {
        case "person": return "person.crop.circle"
        case "running": return "figure.run"
        case "exercise": return "dumbbell.fill"
        case "heartbeat": return "heart.fill"
        default: return "waveform.path.ecg"
        }
    }
}

// MARK: - NSImage JPEG Compression Helper
extension NSImage {
    public func jpegData(compressionQuality: CGFloat = 0.85) -> Data? {
        guard let tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
}
