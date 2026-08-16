//
//  EKEventStore+Extension.swift
//
//  Created by cyan on 10/28/24.
//

import EventKit

public extension EKEventStore {
  func events(from startDate: Date, to endDate: Date, calendars: [EKCalendar]) -> [EKCalendarItem] {
    events(matching: predicateForEvents(
      withStart: startDate,
      end: endDate,
      calendars: calendars
    ))
  }
}

extension EKCalendarItem: @unchecked @retroactive Sendable {}
