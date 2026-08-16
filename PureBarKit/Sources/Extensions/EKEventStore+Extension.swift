//
//  EKEventStore+Extension.swift
//
//  Created by cyan on 10/28/24.
//

import EventKit

public extension EKEventStore {
  func events(from startDate: Date, to endDate: Date, calendars: [EKCalendar]) async throws -> [EKCalendarItem] {
    try await items(for: .event, predicate: predicateForEvents(
      withStart: startDate,
      end: endDate,
      calendars: calendars
    ))
  }

  func reminders(
    from startDate: Date,
    to endDate: Date,
    calendars: [EKCalendar],
    includingCompleted: Bool = true
  ) async throws -> [EKCalendarItem] {
    let incomplete = try await items(
      for: .reminder,
      predicate: predicateForIncompleteReminders(
        withDueDateStarting: startDate,
        ending: endDate,
        calendars: calendars
      )
    )

    guard includingCompleted else {
      return incomplete
    }

    // EventKit matches completed reminders by their completion date, but users expect
    // them on the date they were due, like the Calendar app does. Fetch everything
    // completed since the range started (open-ended), and let the per-day overlap
    // filtering, which is anchored on due dates, place them on the correct days.
    let completed = try await items(
      for: .reminder,
      predicate: predicateForCompletedReminders(
        withCompletionDateStarting: startDate,
        ending: nil,
        calendars: calendars
      )
    )

    return incomplete + completed
  }
}

// MARK: - Private

private extension EKEventStore {
  func items(for type: EKEntityType, predicate: NSPredicate) async throws -> [EKCalendarItem] {
    try await withCheckedThrowingContinuation { continuation in
      switch type {
      case .event:
        continuation.resume(returning: events(matching: predicate))
      case .reminder:
        fetchReminders(matching: predicate) { reminders in
          continuation.resume(returning: reminders ?? [])
        }
      default:
        Logger.assertFail("Invalid type: \(type) of items to fetch for")
      }
    }
  }
}

extension EKCalendarItem: @unchecked @retroactive Sendable {}
