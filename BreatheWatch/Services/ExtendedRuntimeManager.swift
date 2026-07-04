import WatchKit
import os

/// Wrist-down keep-alive (specs.md §3): a .mindfulness (self-care) extended
/// runtime session so haptics keep firing when the wrist drops. Note the OS
/// caps this session type at ~1 hour; for 60+ minute sessions the concurrent
/// HKWorkoutSession is what actually keeps the app alive.
final class ExtendedRuntimeManager: NSObject {
    private var session: WKExtendedRuntimeSession?
    private let log = Logger(subsystem: "com.ezragubbay.breathe", category: "runtime")

    func start() {
        guard session == nil else { return }
        let session = WKExtendedRuntimeSession()
        session.delegate = self
        session.start()
        self.session = session
        log.info("extended runtime session requested (self-care/mindfulness)")
    }

    func stop() {
        session?.invalidate()
        session = nil
        log.info("extended runtime session invalidated")
    }
}

extension ExtendedRuntimeManager: WKExtendedRuntimeSessionDelegate {
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        log.info("extended runtime session started")
    }

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        // The workout session keeps us alive past this; nothing to do.
        log.info("extended runtime session will expire (workout session continues keep-alive)")
    }

    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession,
                                didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
                                error: Error?) {
        log.info("extended runtime session invalidated, reason \(reason.rawValue)")
        session = nil
    }
}
