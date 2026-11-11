// 验证计时器周期衔接及工作提醒等待闹钟确认等控制器行为。
import Foundation
import XCTest

final class TimerManagerTests: XCTestCase {
    @MainActor
    func testFinishingBreakStartsNextCycleOnSameManager() throws {
        let (manager, overlay, defaults, suite) = try makeManager()
        defer {
            manager.stop()
            defaults.removePersistentDomain(forName: suite)
        }

        manager.workDuration = 0.1
        let firstBreak = expectation(description: "第一轮休息提醒")
        overlay.onShow = { mode in
            XCTAssertEqual(mode, .breakReminder)
            firstBreak.fulfill()
        }
        manager.start()
        wait(for: [firstBreak], timeout: 4)
        XCTAssertTrue(manager.isOnBreak)

        let secondBreak = expectation(description: "第二轮休息提醒")
        overlay.onShow = { mode in
            XCTAssertEqual(mode, .breakReminder)
            secondBreak.fulfill()
        }
        try XCTUnwrap(overlay.dismiss)()
        XCTAssertTrue(manager.isRunning)
        XCTAssertFalse(manager.isOnBreak)
        wait(for: [secondBreak], timeout: 4)
    }

    @MainActor
    func testWorkReminderWaitsForAlarmAcknowledgment() throws {
        let (manager, overlay, defaults, suite) = try makeManager()
        defer {
            manager.stop()
            defaults.removePersistentDomain(forName: suite)
        }

        let alarmShown = expectation(description: "闹钟已显示")
        overlay.onShow = { mode in
            XCTAssertEqual(mode, .alarm)
            alarmShown.fulfill()
        }
        XCTAssertTrue(manager.addAlarm(time: Date().addingTimeInterval(0.1), reminderText: "喝水"))
        manager.workDuration = 1.5
        manager.start()
        wait(for: [alarmShown], timeout: 4)

        let alarmID = try XCTUnwrap(manager.alarms.first?.id)
        let alarmDismiss = try XCTUnwrap(overlay.dismiss)
        let workReminderWhileAlarmIsVisible = expectation(description: "闹钟不能被休息提醒替换")
        workReminderWhileAlarmIsVisible.isInverted = true
        overlay.onShow = { _ in workReminderWhileAlarmIsVisible.fulfill() }
        wait(for: [workReminderWhileAlarmIsVisible], timeout: 1.5)
        XCTAssertEqual(overlay.visibleMode, .alarm)
        XCTAssertEqual(manager.alarms.map(\.id), [alarmID])
        XCTAssertFalse(manager.isOnBreak)

        let workReminder = expectation(description: "确认闹钟后显示休息提醒")
        overlay.onShow = { mode in
            XCTAssertEqual(mode, .breakReminder)
            workReminder.fulfill()
        }
        alarmDismiss()
        XCTAssertTrue(manager.alarms.isEmpty)
        wait(for: [workReminder], timeout: 4)
    }

    @MainActor
    private func makeManager() throws -> (TimerManager, OverlaySpy, UserDefaults, String) {
        let suite = "StandUpTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let overlay = OverlaySpy()
        return (TimerManager(defaults: defaults, overlayManager: overlay), overlay, defaults, suite)
    }
}

@MainActor
private final class OverlaySpy: BreakOverlayPresenting {
    var onShow: ((OverlayDisplayMode) -> Void)?
    var dismiss: (() -> Void)?
    var visibleMode: OverlayDisplayMode?

    func show(customReminderText: String,
              presetReminder: String,
              breakDuration: TimeInterval,
              onDismiss: @escaping () -> Void,
              displayMode: OverlayDisplayMode) {
        dismiss = onDismiss
        visibleMode = displayMode
        onShow?(displayMode)
    }

    func hide() {
        dismiss = nil
        visibleMode = nil
    }
}
