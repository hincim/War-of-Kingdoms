import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    // Masaüstü arayüzü için geniş bir pencereyle, ekranın ortasında aç.
    let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    let width = min(1440, screen.width * 0.95)
    let height = min(900, screen.height * 0.95)
    let windowFrame = NSRect(x: screen.midX - width / 2, y: screen.midY - height / 2, width: width, height: height)
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.minSize = NSSize(width: 800, height: 560)
    self.title = "Krallıklar Savaşı"

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
