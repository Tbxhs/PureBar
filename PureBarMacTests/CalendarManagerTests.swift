//
//  CalendarManagerTests.swift
//  PureBarMacTests
//
//  Created for verifying completed reminders are anchored to due dates.
//

import XCTest
import EventKit
@testable import PureBar
import PureBarKit

@MainActor
final class CalendarManagerTests: XCTestCase {
  /// Pure logic: a completed reminder must be anchored to its due date by the overlap filter.
  /// This runs everywhere without EventKit access.
  func testCompletedReminderOverlapsItsDueDate() {
    let reminder = EKReminder(eventStore: EKEventStore())
    reminder.title = "PureBar-test-completed"
    let due = Calendar.solar.date(byAdding: .day, value: -3, to: .now) ?? .now
    reminder.dueDateComponents = Calendar.solar.dateComponents([.year, .month, .day], from: due)
    reminder.isCompleted = true

    let startOfDay = Calendar.solar.startOfDay(for: due)
    let endOfDay = Calendar.solar.endOfDay(for: due)
    let otherDay = Calendar.solar.date(byAdding: .day, value: -10, to: .now) ?? .now

    XCTAssertTrue(reminder.overlaps(startOfDay: startOfDay, endOfDay: endOfDay), "Should appear on its due date")
    XCTAssertFalse(
      reminder.overlaps(
        startOfDay: Calendar.solar.startOfDay(for: otherDay),
        endOfDay: Calendar.solar.endOfDay(for: otherDay)
      ),
      "Should not appear on unrelated days"
    )
  }

  /// Integration: a reminder due 3 days ago but completed today must show up on its due date,
  /// and must disappear when the completed reminders style is set to hidden.
  /// Skipped when the test host has no Reminders access (e.g. fresh debug builds).
  func testCompletedRemindersAnchoredToDueDate() async throws {
    let store = EKEventStore()
    let calendar = store.calendars(for: .reminder).first
    try XCTSkipIf(calendar == nil, "No reminder calendar available (Reminders access not granted)")

    let originalStyle = AppPreferences.Calendar.completedRemindersStyle
    defer {
      AppPreferences.Calendar.completedRemindersStyle = originalStyle
      CalendarManager.default.clearCaches()
    }

    // Create: due 3 days ago, completed now
    let reminder = EKReminder(eventStore: store)
    reminder.calendar = calendar
    reminder.title = "PureBar-test-completed"
    let due = Calendar.solar.date(byAdding: .day, value: -3, to: .now) ?? .now
    reminder.dueDateComponents = Calendar.solar.dateComponents([.year, .month, .day], from: due)
    reminder.isCompleted = true
    try store.save(reminder, commit: true)
    defer {
      try? store.remove(reminder, commit: true)
    }

    let startOfDay = Calendar.solar.startOfDay(for: due)
    let endOfDay = Calendar.solar.endOfDay(for: due)

    // With completed reminders visible: the item must appear on its due date
    AppPreferences.Calendar.completedRemindersStyle = .strikethrough
    CalendarManager.default.clearCaches()
    var items = try await CalendarManager.default.items(from: startOfDay, to: endOfDay)
    XCTAssertTrue(
      items.contains { $0.title == reminder.title },
      "A completed reminder should be visible on its due date"
    )

    // With completed reminders hidden: the item must not appear
    AppPreferences.Calendar.completedRemindersStyle = .hidden
    CalendarManager.default.clearCaches()
    items = try await CalendarManager.default.items(from: startOfDay, to: endOfDay)
    XCTAssertFalse(
      items.contains { $0.title == reminder.title },
      "A completed reminder should be hidden when the style is set to hidden"
    )
  }
}
