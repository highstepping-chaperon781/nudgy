import Cocoa

@main
struct NudgeApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // No dock icon
        app.run()
    }
}
