//
//  AppDelegate.swift
//  Awayke
//

import AppKit
import ServiceManagement
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let powerManager = PowerManager()
    private let helper = HelperManager.shared
    private let displayKeeper = DisplayWakeKeeper()
    private let batteryMonitor = BatteryMonitor()

    private static let batteryLimitKey = "BatteryLimit"

    /// Battery percentage at which Awayke turns itself off. 0 = disabled.
    private var batteryLimit: Int {
        get { UserDefaults.standard.integer(forKey: Self.batteryLimitKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.batteryLimitKey) }
    }

    private var isActive: Bool = false {
        didSet {
            if isActive { displayKeeper.prevent() } else { displayKeeper.allow() }
            refreshStatusItem()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        helper.register()

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // Tightens the horizontal slot around the icon.
        item.length = 14
        statusItem = item

        if let button = item.button {
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        refreshStatusItem()

        // Recovery from crash / force-kill: pmset disablesleep is a
        // persistent system setting, so a previous instance that died
        // without running its quit cleanup leaves SleepDisabled = 1.
        // Silently reset it via the helper. Skipped if the helper isn't
        // approved (no password prompt for cleanup the user didn't ask for).
        if helper.isUsable {
            powerManager.disableSleep(false) { _ in }
        }

        batteryMonitor.onChange = { [weak self] in
            self?.enforceBatteryLimit()
        }
        batteryMonitor.start()

        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Turns Awayke off when the battery drains to the configured limit.
    /// Only acts while discharging, so a plugged-in Mac sitting below the
    /// limit isn't affected.
    private func enforceBatteryLimit() {
        guard isActive, batteryLimit > 0,
              let status = BatteryMonitor.currentStatus(),
              status.onBattery, status.percent <= batteryLimit else { return }

        let percent = status.percent
        powerManager.disableSleep(false) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, case .success = result else { return }
                self.isActive = false
                self.postBatteryLimitNotification(percent: percent)
            }
        }
    }

    private func postBatteryLimitNotification(percent: Int) {
        let title = "Awayke turned off"
        let body = "Battery reached \(percent)%, at or below your \(batteryLimit)% limit. Sleep is enabled again."

        // Native notifications require a valid signing identity; ad-hoc
        // builds are rejected by Notification Center. Try native first,
        // fall back to osascript (shows as "Script Editor") otherwise.
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if granted {
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default
                let request = UNNotificationRequest(
                    identifier: "awayke.batteryLimit",
                    content: content,
                    trigger: nil
                )
                UNUserNotificationCenter.current().add(request)
            } else {
                DispatchQueue.main.async {
                    NotificationBanner.show(title: title, body: body)
                    NSSound.beep()
                }
            }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Never leave the system with sleep disabled. Defer termination
        // until the helper (or osascript fallback) finishes flipping
        // pmset back off, so the main run loop stays alive for any auth
        // UI the fallback path may need to show.
        guard isActive else { return .terminateNow }

        powerManager.disableSleep(false) { _ in
            DispatchQueue.main.async {
                self.displayKeeper.allow()
                NSApp.reply(toApplicationShouldTerminate: true)
            }
        }
        return .terminateLater
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            toggle()
        }
    }

    private func toggle() {
        let target = !isActive
        powerManager.disableSleep(target) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success:
                    self.isActive = target
                    if target { self.enforceBatteryLimit() }
                case .failure(let error): self.presentError(error)
                }
            }
        }
    }

    private func showMenu() {
        let menu = NSMenu()

        let stateItem = NSMenuItem(title: isActive ? "Awayke: Active" : "Awayke: Inactive", action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: isActive ? "Turn Off" : "Turn On", action: #selector(menuToggle), keyEquivalent: ""))

        menu.addItem(.separator())
        menu.addItem(batteryLimitMenuItem())

        if let helperRow = helperStatusMenuItem() {
            menu.addItem(.separator())
            menu.addItem(helperRow)
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Uninstall Awayke…", action: #selector(menuUninstall), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Awayke", action: #selector(menuQuit), keyEquivalent: "q"))

        for item in menu.items where item.action != nil {
            item.target = self
        }
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    private func batteryLimitMenuItem() -> NSMenuItem {
        let submenu = NSMenu()

        let offItem = NSMenuItem(title: "Never", action: #selector(menuSetBatteryLimit(_:)), keyEquivalent: "")
        offItem.tag = 0
        offItem.target = self
        offItem.state = batteryLimit == 0 ? .on : .off
        submenu.addItem(offItem)
        submenu.addItem(.separator())

        for percent in stride(from: 10, through: 90, by: 10) {
            let item = NSMenuItem(title: "\(percent)%", action: #selector(menuSetBatteryLimit(_:)), keyEquivalent: "")
            item.tag = percent
            item.target = self
            item.state = batteryLimit == percent ? .on : .off
            submenu.addItem(item)
        }

        let title = batteryLimit > 0 ? "Turn Off at Battery Level (\(batteryLimit)%)" : "Turn Off at Battery Level"
        let root = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        root.submenu = submenu
        return root
    }

    @objc private func menuSetBatteryLimit(_ sender: NSMenuItem) {
        batteryLimit = sender.tag
        if batteryLimit > 0 {
            UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        enforceBatteryLimit()
    }

    private func helperStatusMenuItem() -> NSMenuItem? {
        switch helper.state {
        case .enabled:
            return nil
        case .awaitingApproval:
            return NSMenuItem(title: "Approve helper in System Settings…", action: #selector(menuApproveHelper), keyEquivalent: "")
        case .notRegistered:
            let item = NSMenuItem(title: "Installing helper…", action: nil, keyEquivalent: "")
            item.isEnabled = false
            return item
        case .notFound:
            let item = NSMenuItem(title: "Helper not found (using fallback)", action: nil, keyEquivalent: "")
            item.isEnabled = false
            return item
        }
    }

    @objc private func menuToggle() { toggle() }
    @objc private func menuApproveHelper() { helper.revealInSystemSettings() }
    @objc private func menuQuit() { NSApp.terminate(nil) }

    @objc private func menuUninstall() {
        let alert = NSAlert()
        alert.messageText = "Uninstall Awayke?"
        alert.informativeText = "This will remove Awayke's background helper from System Settings and quit the app. You can then move Awayke.app to the Trash."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        helper.unregister()
        NSApp.terminate(nil)
    }

    private func refreshStatusItem() {
        guard let button = statusItem?.button else { return }
        guard let base = NSImage(named: "StatusIcon") else { return }
        base.size = NSSize(width: 16, height: 14)

        if isActive {
            button.image = orangeTinted(base)
        } else {
            base.isTemplate = true
            button.image = base
        }
        button.contentTintColor = nil
        button.title = ""
        button.toolTip = isActive ? "Awayke is on!" : "Awayke is off. Click to turn it on."
    }

    private func orangeTinted(_ source: NSImage) -> NSImage {
        let image = source.copy() as! NSImage
        image.isTemplate = false
        image.lockFocus()
        NSColor(red: 1, green: 0.6, blue: 0.1, alpha: 1).set()
        NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
        image.unlockFocus()
        return image
    }

    private func presentError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Awayke couldn't toggle sleep."
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
