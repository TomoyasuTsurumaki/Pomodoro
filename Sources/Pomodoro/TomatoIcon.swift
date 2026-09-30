import AppKit

/// トマト（ポモドーロ）アイコンの描画。
///
/// メニューバー用のテンプレート画像と、アプリアイコン用のフルカラー画像を
/// 同じ形状定義から作る。`.icns` の生成スクリプト（Tools/MakeAppIcon.swift）も
/// このファイルを直接コンパイルして使うので、AppKit 以外に依存させないこと。
enum TomatoIcon {

    // MARK: - 公開 API

    /// メニューバー用。単色シルエット（テンプレート画像）。
    static func menuBarImage(pointSize: CGFloat = 16) -> NSImage {
        let size = NSSize(width: pointSize, height: pointSize)
        let image = NSImage(size: size, flipped: false) { rect in
            drawSilhouette(in: rect)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "ポモドーロタイマー"
        return image
    }

    /// アプリアイコン用。角丸スクエアの台座 + フルカラーのトマト。
    static func appIconImage(pixelSize: CGFloat) -> NSImage {
        let size = NSSize(width: pixelSize, height: pixelSize)
        let image = NSImage(size: size, flipped: false) { rect in
            drawAppIcon(in: rect)
            return true
        }
        image.accessibilityDescription = "ポモドーロタイマー"
        return image
    }

    // MARK: - 形状

    /// 実の輪郭。横にわずかに潰した円。`rect` は実を収める矩形。
    private static func bodyPath(in rect: NSRect) -> NSBezierPath {
        NSBezierPath(ovalIn: rect)
    }

    /// ヘタ（萼）。`center` はヘタの中心、`radius` は葉の長さ。
    ///
    /// 中央から放射状に伸びる尖った葉。枚数は偶数にして真上を谷にし、
    /// そこに茎を通す。`spread` は葉を広げる角度（上向きが中心）。
    /// 広げすぎると葉先が実の肩からはみ出すので、小さいサイズでは絞る。
    private static func calyxPath(
        center: NSPoint,
        radius: CGFloat,
        leaves: Int = 6,
        spread: CGFloat = .pi * 1.16
    ) -> NSBezierPath {
        let path = NSBezierPath()
        let start = CGFloat.pi / 2 - spread / 2

        for i in 0..<leaves {
            let angle = start + spread * CGFloat(i) / CGFloat(leaves - 1)
            let tip = NSPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            // 葉の根元の幅。先端に向かって細くする。
            let halfWidth = CGFloat.pi / CGFloat(leaves) * 0.50
            let left = NSPoint(
                x: center.x + cos(angle + halfWidth) * radius * 0.52,
                y: center.y + sin(angle + halfWidth) * radius * 0.52
            )
            let right = NSPoint(
                x: center.x + cos(angle - halfWidth) * radius * 0.52,
                y: center.y + sin(angle - halfWidth) * radius * 0.52
            )
            path.move(to: center)
            path.line(to: left)
            path.line(to: tip)
            path.line(to: right)
            path.close()
        }
        // 葉の付け根を丸くまとめて、細かい隙間が出ないようにする。
        // 半径は葉に隠れる程度に留める（はみ出すと円板に見える）。
        path.appendOval(in: NSRect(
            x: center.x - radius * 0.24,
            y: center.y - radius * 0.24,
            width: radius * 0.48,
            height: radius * 0.48
        ))
        return path
    }

    /// 茎。ヘタの中心から上に伸びる短い線。
    private static func stemPath(center: NSPoint, length: CGFloat, width: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: center.x, y: center.y))
        path.curve(
            to: NSPoint(x: center.x + length * 0.16, y: center.y + length),
            controlPoint1: NSPoint(x: center.x - length * 0.08, y: center.y + length * 0.45),
            controlPoint2: NSPoint(x: center.x + length * 0.02, y: center.y + length * 0.78)
        )
        path.lineWidth = width
        path.lineCapStyle = .round
        return path
    }

    // MARK: - メニューバー（単色シルエット）

    private static func drawSilhouette(in rect: NSRect) {
        let scale = min(rect.width, rect.height)

        // 上に茎とヘタの分の余白を取り、実は下寄せに置く
        let bodyWidth = scale * 0.88
        let bodyHeight = scale * 0.74
        let body = NSRect(
            x: rect.midX - bodyWidth / 2,
            y: rect.minY + scale * 0.02,
            width: bodyWidth,
            height: bodyHeight
        )

        // ヘタの中心を実の上端に置く。同じ黒なので実に埋もれた部分は消え、
        // 上端から出た先端だけが「尖ったヘタ」として見える。
        // 16pt では葉を 4 枚に減らす（枚数が多いと谷が潰れて団子になる）。
        let calyxCenter = NSPoint(x: body.midX, y: body.maxY - bodyHeight * 0.20)
        let calyxRadius = bodyWidth * 0.38
        let calyxLeaves = 4
        let calyxSpread = CGFloat.pi * 0.62

        NSColor.black.setFill()
        bodyPath(in: body).fill()
        calyxPath(
            center: calyxCenter,
            radius: calyxRadius,
            leaves: calyxLeaves,
            spread: calyxSpread
        ).fill()

        // 茎。ヘタの谷（真上）を通す
        let stem = stemPath(
            center: calyxCenter,
            length: scale * 0.22,
            width: max(1.0, scale * 0.11)
        )
        NSColor.black.setStroke()
        stem.stroke()
    }

    // MARK: - アプリアイコン（フルカラー）

    private static func drawAppIcon(in rect: NSRect) {
        guard let context = NSGraphicsContext.current else { return }
        let scale = min(rect.width, rect.height)

        // macOS のアイコングリッドに合わせ、角丸スクエアの台座を少し内側に敷く
        let inset = scale * 0.055
        let plate = rect.insetBy(dx: inset, dy: inset)
        let corner = plate.width * 0.225

        let plateBackground = NSGradient(
            starting: NSColor(calibratedRed: 1.00, green: 0.98, blue: 0.94, alpha: 1),
            ending: NSColor(calibratedRed: 0.98, green: 0.93, blue: 0.86, alpha: 1)
        )
        let platePath = NSBezierPath(roundedRect: plate, xRadius: corner, yRadius: corner)
        plateBackground?.draw(in: platePath, angle: -90)

        // 実。台座の中でやや下寄せにして、上にヘタと茎の余白を作る
        let bodyWidth = plate.width * 0.72
        let bodyHeight = bodyWidth * 0.86
        let body = NSRect(
            x: plate.midX - bodyWidth / 2,
            y: plate.midY - bodyHeight / 2 - plate.height * 0.045,
            width: bodyWidth,
            height: bodyHeight
        )
        let bodyPath = self.bodyPath(in: body)

        let red = NSGradient(
            starting: NSColor(calibratedRed: 0.93, green: 0.29, blue: 0.24, alpha: 1),
            ending: NSColor(calibratedRed: 0.76, green: 0.13, blue: 0.13, alpha: 1)
        )
        red?.draw(in: bodyPath, angle: -90)

        // 左上のハイライト。実の中だけに効かせる
        context.saveGraphicsState()
        bodyPath.addClip()
        let highlight = NSBezierPath(ovalIn: NSRect(
            x: body.minX + body.width * 0.13,
            y: body.minY + body.height * 0.44,
            width: body.width * 0.32,
            height: body.height * 0.24
        ))
        NSColor(calibratedWhite: 1, alpha: 0.28).setFill()
        highlight.fill()
        context.restoreGraphicsState()

        // ヘタと茎
        let calyxCenter = NSPoint(x: body.midX, y: body.maxY - bodyHeight * 0.14)
        let calyxRadius = bodyWidth * 0.33

        let calyx = calyxPath(center: calyxCenter, radius: calyxRadius)
        let green = NSGradient(
            starting: NSColor(calibratedRed: 0.47, green: 0.71, blue: 0.30, alpha: 1),
            ending: NSColor(calibratedRed: 0.29, green: 0.51, blue: 0.20, alpha: 1)
        )
        green?.draw(in: calyx, angle: -90)

        // 茎は葉の谷（真上）を通すので、ヘタの後に描いて手前に出す
        let stem = stemPath(
            center: calyxCenter,
            length: plate.height * 0.13,
            width: max(1.0, scale * 0.048)
        )
        NSColor(calibratedRed: 0.30, green: 0.48, blue: 0.21, alpha: 1).setStroke()
        stem.stroke()
    }
}
