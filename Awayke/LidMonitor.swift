//
//  LidMonitor.swift
//  Awayke
//
//  Observes the IOPMrootDomain clamshell property. A normal system-wake
//  notification is not sufficient here: while Awayke is active the Mac does
//  not sleep when the lid closes, so there may be no wake event when it opens.
//

import Foundation
import IOKit
import IOKit.pwr_mgt

// kIOPMMessageClamshellStateChange is defined in IOPM.h in terms of nested C
// macros, so Swift cannot import it. This is the same public IOKit message ID:
// iokit_family_msg(sub_iokit_powermanagement, 0x100).
private let clamshellStateChangeMessage =
    (UInt32(0x38) << 26) | (UInt32(13) << 14) | UInt32(0x100)

// IOPM.h documents the clamshell message as carrying the state in its message
// argument: "Check bits 0 and 1 using kClamshellStateBit & kClamshellSleepBit".
private let clamshellStateBit = UInt(1 << 0)

final class LidMonitor {

    /// Called on the main queue whenever the physical lid state changes.
    var onChange: ((Bool) -> Void)?

    private(set) var isClosed: Bool?

    private var rootDomain: io_service_t = IO_OBJECT_NULL
    private var notificationPort: IONotificationPortRef?
    private var notifier: io_object_t = IO_OBJECT_NULL

    /// Returns false when the clamshell notification could not be registered.
    /// No lid change is reported at all in that case, so a caller that relies
    /// on lid events needs to know.
    func start() -> Bool {
        guard notificationPort == nil else { return true }

        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPMrootDomain")
        )
        guard service != IO_OBJECT_NULL else { return false }

        guard let port = IONotificationPortCreate(kIOMainPortDefault) else {
            IOObjectRelease(service)
            return false
        }

        rootDomain = service
        notificationPort = port
        IONotificationPortSetDispatchQueue(port, .main)

        let context = Unmanaged.passUnretained(self).toOpaque()
        let result = IOServiceAddInterestNotification(
            port,
            service,
            kIOGeneralInterest,
            { context, _, messageType, messageArgument in
                guard messageType == clamshellStateChangeMessage,
                      let context else { return }
                let monitor = Unmanaged<LidMonitor>
                    .fromOpaque(context)
                    .takeUnretainedValue()
                // The lid state travels with the message. Reading the registry
                // here would instead report the state at delivery time, which
                // drops a close/open pair that queues up while the main queue
                // is busy.
                let closed = (UInt(bitPattern: messageArgument) & clamshellStateBit) != 0
                monitor.emit(closed: closed)
            },
            context,
            &notifier
        )

        guard result == kIOReturnSuccess else {
            stop()
            return false
        }

        if let closed = readClamshellState() {
            emit(closed: closed)
        }
        return true
    }

    func stop() {
        if notifier != IO_OBJECT_NULL {
            IOObjectRelease(notifier)
            notifier = IO_OBJECT_NULL
        }
        if let port = notificationPort {
            IONotificationPortDestroy(port)
            notificationPort = nil
        }
        if rootDomain != IO_OBJECT_NULL {
            IOObjectRelease(rootDomain)
            rootDomain = IO_OBJECT_NULL
        }
        isClosed = nil
    }

    deinit {
        stop()
    }

    private func emit(closed: Bool) {
        guard closed != isClosed else { return }
        isClosed = closed
        onChange?(closed)
    }

    /// Only used for the initial reading; later states arrive with the message.
    private func readClamshellState() -> Bool? {
        guard rootDomain != IO_OBJECT_NULL,
              let property = IORegistryEntryCreateCFProperty(
                rootDomain,
                kAppleClamshellStateKey as CFString,
                kCFAllocatorDefault,
                0
              )?.takeRetainedValue() as? NSNumber else { return nil }

        return property.boolValue
    }
}
