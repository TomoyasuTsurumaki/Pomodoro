import AppKit
import Foundation

// Resources/AppIcon.icns を生成するスタンドアロンスクリプト。
// Sources/ の外にあるので SPM のターゲットには含まれない。
//
//   swiftc Tools/MakeAppIcon.swift Sources/Pomodoro/TomatoIcon.swift -o "$TMPDIR/makeicon" \
//     && "$TMPDIR/makeicon"
//
// デザイン（TomatoIcon.appIconImage）を変えたときだけ実行して、
// 生成された .icns をコミットする。

@main
struct MakeAppIcon {

    /// iconset に必要な (ファイル名, ピクセルサイズ) の一覧
    static let variants: [(name: String, pixels: CGFloat)] = [
        ("icon_16x16", 16),
        ("icon_16x16@2x", 32),
        ("icon_32x32", 32),
        ("icon_32x32@2x", 64),
        ("icon_128x128", 128),
        ("icon_128x128@2x", 256),
        ("icon_256x256", 256),
        ("icon_256x256@2x", 512),
        ("icon_512x512", 512),
        ("icon_512x512@2x", 1024),
    ]

    static func main() throws {
        let fileManager = FileManager.default

        // リポジトリのルート（このスクリプトの 1 つ上）を基準にする。
        // 実行バイナリは $TMPDIR に置かれるので #filePath を使う。
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Tools/
            .deletingLastPathComponent()   // リポジトリのルート
        let outputURL = repoRoot.appendingPathComponent("Resources/AppIcon.icns")

        let iconsetURL = fileManager.temporaryDirectory
            .appendingPathComponent("Pomodoro-AppIcon-\(UUID().uuidString).iconset")
        try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: iconsetURL) }

        for variant in variants {
            let url = iconsetURL.appendingPathComponent("\(variant.name).png")
            try pngData(pixels: variant.pixels).write(to: url)
            print("  \(variant.name).png (\(Int(variant.pixels))px)")
        }

        try fileManager.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let iconutil = Process()
        iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        iconutil.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
        try iconutil.run()
        iconutil.waitUntilExit()
        guard iconutil.terminationStatus == 0 else {
            fail("iconutil が失敗しました (終了コード \(iconutil.terminationStatus))")
        }

        print("完成: \(outputURL.path)")
    }

    /// TomatoIcon の描画をそのピクセル数のビットマップに焼き込む。
    /// NSImage をそのまま TIFF 化すると論理サイズでしか描かれないので、
    /// 明示的に 1:1 の NSBitmapImageRep を作ってそこへ描画する。
    static func pngData(pixels: CGFloat) -> Data {
        let side = Int(pixels)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: side,
            pixelsHigh: side,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            fail("ビットマップを用意できませんでした (\(side)px)")
        }
        rep.size = NSSize(width: pixels, height: pixels)

        guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
            fail("描画コンテキストを用意できませんでした (\(side)px)")
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high

        let image = TomatoIcon.appIconImage(pixelSize: pixels)
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))

        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        guard let data = rep.representation(using: .png, properties: [:]) else {
            fail("PNG に変換できませんでした (\(side)px)")
        }
        return data
    }

    static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data(("エラー: " + message + "\n").utf8))
        exit(1)
    }
}
