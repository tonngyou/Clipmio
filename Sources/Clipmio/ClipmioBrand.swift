// Copyright (c) 2026 tonngyou. MIT License.
import AppKit
import SwiftUI

enum ClipmioTheme {
    static let purple = Color(red: 0.34, green: 0.31, blue: 0.83)
    static let panelSize = CGSize(width: 400, height: 520)
    static let previewPanelSize = CGSize(width: 640, height: 600)

    static func accent(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.68, green: 0.65, blue: 1) : purple
    }

    static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        .module
        #else
        .main
        #endif
    }
}

/// Original layered-paper / M clasp artwork; see docs/BRANDING.md for the brief.
struct ClipmioMark: View {
    var body: some View {
        Image(nsImage: ClipmioArtwork.logoImage)
            .resizable()
            .renderingMode(.original)
            .interpolation(.high)
            .scaledToFit()
            .accessibilityHidden(true)
    }
}

/// A deliberately simplified template mark stays crisp in the 18-point menu bar.
private struct MenuBarMark: View {
    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 3, y: 5))
                path.addQuadCurve(to: CGPoint(x: 1.5, y: 7), control: CGPoint(x: 1.5, y: 5))
                path.addLine(to: CGPoint(x: 1.5, y: 14))
                path.addQuadCurve(to: CGPoint(x: 4, y: 16.5), control: CGPoint(x: 1.5, y: 16.5))
                path.addLine(to: CGPoint(x: 12, y: 16.5))
            }
            .stroke(.black, style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
            RoundedRectangle(cornerRadius: 2.5)
                .strokeBorder(.black, lineWidth: 1.5)
                .frame(width: 12, height: 13)
                .offset(x: 1, y: 0)
            MClasp()
                .fill(.black)
                .frame(width: 10, height: 5)
                .offset(x: 1, y: -6)
        }
        .frame(width: 18, height: 18)
    }
}

private struct MClasp: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: rect.height))
            path.addLine(to: .zero)
            path.addLine(to: CGPoint(x: rect.width * 0.27, y: 0))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.height * 0.35))
            path.addLine(to: CGPoint(x: rect.width * 0.73, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width * 0.7, y: rect.height))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.height * 0.7))
            path.addLine(to: CGPoint(x: rect.width * 0.3, y: rect.height))
            path.closeSubpath()
        }
    }
}

@MainActor
enum ClipmioArtwork {
    static let logoImage: NSImage = {
        if let url = ClipmioTheme.resourceBundle.url(forResource: "ClipmioLogo", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipmio")!
    }()

    static func menuBarImage() -> NSImage? {
        let renderer = ImageRenderer(content: MenuBarMark())
        renderer.scale = 2
        guard let image = renderer.nsImage else { return nil }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        image.accessibilityDescription = "Clipmio"
        return image
    }
}
