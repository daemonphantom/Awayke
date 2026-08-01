//
//  NotificationBanner.swift
//  Awayke
//
//  A self-drawn notification banner. Used as a fallback when native
//  notifications are unavailable (ad-hoc signed builds are rejected by
//  Notification Center, so unsigned dev builds can't post them).
//

import AppKit

final class NotificationBanner {

    private static var activePanel: NSPanel?

    /// Shows a banner in the top-right corner of the main screen and
    /// fades it out after `duration` seconds. Must be called on main.
    static func show(title: String, body: String, duration: TimeInterval = 6) {
        activePanel?.orderOut(nil)

        let width: CGFloat = 340
        let padding: CGFloat = 14

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .boldSystemFont(ofSize: 13)

        let bodyLabel = NSTextField(wrappingLabelWithString: body)
        bodyLabel.font = .systemFont(ofSize: 12)
        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.preferredMaxLayoutWidth = width - padding * 2

        let stack = NSStackView(views: [titleLabel, bodyLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: padding, left: padding, bottom: padding, right: padding)

        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 12

        effect.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: effect.topAnchor),
            stack.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            effect.widthAnchor.constraint(equalToConstant: width),
        ])

        let height = effect.fittingSize.height
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = effect
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.isReleasedWhenClosed = false
        panel.hasShadow = true

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(
                x: frame.maxX - width - 16,
                y: frame.maxY - height - 16
            ))
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        activePanel = panel

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            panel.animator().alphaValue = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak panel] in
            guard let panel, panel === activePanel else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.5
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
                if panel === activePanel { activePanel = nil }
            })
        }
    }
}
