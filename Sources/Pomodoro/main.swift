import AppKit

let application = NSApplication.shared
let appDelegate = AppDelegate()
application.delegate = appDelegate
// Dock にもアプリスイッチャーにも出さない
application.setActivationPolicy(.accessory)
application.run()
