//
//  BatteryMonitor.swift
//  Awayke
//
//  Watches the battery level via IOKit power source notifications.
//

import Foundation
import IOKit.ps

final class BatteryMonitor {

    /// Called on the main run loop whenever the power source state changes.
    var onChange: (() -> Void)?

    private var runLoopSource: CFRunLoopSource?

    func start() {
        guard runLoopSource == nil else { return }

        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
            monitor.onChange?()
        }, context)?.takeRetainedValue() else { return }

        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    func stop() {
        guard let source = runLoopSource else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        runLoopSource = nil
    }

    deinit {
        stop()
    }

    /// Current charge as a percentage (0–100) and whether the Mac is
    /// running on battery power. Returns nil on Macs without a battery.
    static func currentStatus() -> (percent: Int, onBattery: Bool)? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }

        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, source)?
                .takeUnretainedValue() as? [String: Any],
                let capacity = info[kIOPSCurrentCapacityKey] as? Int,
                let maxCapacity = info[kIOPSMaxCapacityKey] as? Int,
                maxCapacity > 0 else { continue }

            let percent = Int((Double(capacity) / Double(maxCapacity) * 100).rounded())
            let onBattery = (info[kIOPSPowerSourceStateKey] as? String) == kIOPSBatteryPowerValue
            return (percent, onBattery)
        }
        return nil
    }
}
