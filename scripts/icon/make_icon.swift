// Dessine l'icône de Borne (1024 px) : swiftc make_icon.swift -o make_icon && ./make_icon out.png
import AppKit
import SwiftUI

struct Icon: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 1024
            ctx.scaleBy(x: s, y: s)
            func rr(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> Path {
                Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r, style: .continuous)
            }
            func hex(_ v: UInt32) -> Color {
                Color(red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255)
            }

            // Fond : nuit violette, lueur derrière la borne, sol en grille.
            let bg = rr(100, 100, 824, 824, 185)
            ctx.fill(bg, with: .linearGradient(Gradient(colors: [hex(0x140a33), hex(0x3a0f63)]),
                                               startPoint: CGPoint(x: 512, y: 100), endPoint: CGPoint(x: 512, y: 924)))
            ctx.drawLayer { l in
                l.clip(to: bg)
                l.fill(Path(ellipseIn: CGRect(x: 170, y: 180, width: 684, height: 560)),
                       with: .radialGradient(Gradient(colors: [hex(0xff3ea5).opacity(0.45), .clear]),
                                             center: CGPoint(x: 512, y: 440), startRadius: 0, endRadius: 360))
                var grid = Path()
                for i in 0...12 {
                    let x = 100 + CGFloat(i) * 824 / 12
                    grid.move(to: CGPoint(x: 512 + (x - 512) * 0.35, y: 760))
                    grid.addLine(to: CGPoint(x: 512 + (x - 512) * 1.6, y: 924))
                }
                for y in [775.0, 800, 835, 880] {
                    grid.move(to: CGPoint(x: 100, y: y)); grid.addLine(to: CGPoint(x: 924, y: y))
                }
                l.stroke(grid, with: .color(hex(0x2de2e6).opacity(0.35)), lineWidth: 3)
            }

            // Ombre au sol.
            ctx.fill(Path(ellipseIn: CGRect(x: 270, y: 838, width: 484, height: 40)),
                     with: .color(.black.opacity(0.45)))

            // Caisse.
            let body = rr(300, 200, 424, 655, 26)
            ctx.fill(body, with: .linearGradient(Gradient(colors: [hex(0xff4d6d), hex(0xb0123f)]),
                                                 startPoint: CGPoint(x: 300, y: 200), endPoint: CGPoint(x: 724, y: 855)))
            ctx.stroke(body, with: .color(hex(0xffd1dc).opacity(0.55)), lineWidth: 6)

            // Fronton lumineux.
            let marquee = rr(282, 188, 460, 104, 22)
            ctx.fill(marquee, with: .linearGradient(Gradient(colors: [hex(0x2de2e6), hex(0x7b5cff), hex(0xff3ea5)]),
                                                    startPoint: CGPoint(x: 282, y: 240), endPoint: CGPoint(x: 742, y: 240)))
            ctx.fill(rr(296, 198, 432, 30, 14), with: .color(.white.opacity(0.28)))
            for (i, x) in stride(from: 330.0, through: 690, by: 60).enumerated() {
                let star = CGRect(x: x, y: i % 2 == 0 ? 232 : 252, width: 14, height: 14)
                ctx.fill(Path(star), with: .color(.white.opacity(0.85)))
            }

            // Écran.
            ctx.fill(rr(322, 308, 380, 290, 22), with: .color(hex(0x1a1426)))
            let screen = rr(348, 330, 328, 246, 34)
            ctx.fill(screen, with: .radialGradient(Gradient(colors: [hex(0x123a3a), hex(0x05090f)]),
                                                   center: CGPoint(x: 512, y: 440), startRadius: 10, endRadius: 220))
            ctx.drawLayer { l in
                l.clip(to: screen)
                let invader = ["..X.....X..", "...X...X...", "..XXXXXXX..", ".XX.XXX.XX.",
                               "XXXXXXXXXXX", "X.XXXXXXX.X", "X.X.....X.X", "...XX.XX..."]
                let px: CGFloat = 18
                let ox = 512 - px * 11 / 2, oy: CGFloat = 372
                var p = Path()
                for (r, row) in invader.enumerated() {
                    for (c, ch) in row.enumerated() where ch == "X" {
                        p.addRect(CGRect(x: ox + CGFloat(c) * px, y: oy + CGFloat(r) * px, width: px, height: px))
                    }
                }
                l.addFilter(.shadow(color: hex(0x5cff8a), radius: 12))
                l.fill(p, with: .color(hex(0x7dff9c)))
            }
            ctx.drawLayer { l in
                l.clip(to: screen)
                // Canon et ligne de sol.
                l.fill(Path(CGRect(x: 494, y: 530, width: 36, height: 14)), with: .color(hex(0x2de2e6)))
                l.fill(Path(CGRect(x: 506, y: 518, width: 12, height: 12)), with: .color(hex(0x2de2e6)))
                var scan = Path()
                for y in stride(from: 332.0, to: 576, by: 6) { scan.addRect(CGRect(x: 348, y: y, width: 328, height: 2)) }
                l.fill(scan, with: .color(.black.opacity(0.25)))
                l.fill(Path(ellipseIn: CGRect(x: 360, y: 336, width: 200, height: 90)),
                       with: .color(.white.opacity(0.10)))
            }

            // Panneau de commande, en saillie.
            var panel = Path()
            panel.move(to: CGPoint(x: 296, y: 612)); panel.addLine(to: CGPoint(x: 728, y: 612))
            panel.addLine(to: CGPoint(x: 770, y: 694)); panel.addLine(to: CGPoint(x: 254, y: 694))
            panel.closeSubpath()
            ctx.fill(panel, with: .linearGradient(Gradient(colors: [hex(0x3b2a5c), hex(0x221636)]),
                                                  startPoint: CGPoint(x: 512, y: 612), endPoint: CGPoint(x: 512, y: 694)))
            ctx.fill(Path(CGRect(x: 254, y: 694, width: 516, height: 22)), with: .color(hex(0x140c22)))
            // Joystick.
            ctx.fill(Path(CGRect(x: 368, y: 600, width: 10, height: 50)), with: .color(hex(0x111111)))
            ctx.fill(Path(ellipseIn: CGRect(x: 350, y: 640, width: 46, height: 18)), with: .color(.black.opacity(0.6)))
            ctx.fill(Path(ellipseIn: CGRect(x: 349, y: 572, width: 48, height: 48)),
                     with: .radialGradient(Gradient(colors: [hex(0xff8a8a), hex(0xd1001f)]),
                                           center: CGPoint(x: 365, y: 586), startRadius: 2, endRadius: 34))
            // Boutons.
            for (i, c) in [hex(0xffd23f), hex(0x2de2e6), hex(0x5cff8a)].enumerated() {
                let x = 500 + CGFloat(i) * 62, y: CGFloat = i == 1 ? 636 : 646
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y + 6, width: 42, height: 22)), with: .color(.black.opacity(0.5)))
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 42, height: 24)), with: .color(c))
                ctx.fill(Path(ellipseIn: CGRect(x: x + 8, y: y + 3, width: 18, height: 8)), with: .color(.white.opacity(0.6)))
            }

            // Porte à monnayeur.
            ctx.fill(rr(448, 748, 128, 88, 10), with: .color(hex(0x2a1a3e)))
            for x in [470.0, 526] {
                ctx.fill(rr(x, 768, 28, 44, 6), with: .color(hex(0x140c22)))
                ctx.fill(rr(x + 11, 774, 6, 32, 3), with: .color(hex(0xffa53f)))
            }
        }
        .frame(width: 1024, height: 1024)
    }
}

@MainActor func render() {
    let r = ImageRenderer(content: Icon())
    r.scale = 1
    guard let cg = r.cgImage else { fatalError("rendu impossible") }
    let rep = NSBitmapImageRep(cgImage: cg)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
}
MainActor.assumeIsolated { render() }
