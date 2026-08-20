//
//  EKCalendarItem+Extension.swift
//
//  Created by cyan on 12/26/23.
//

import EventKit

public extension EKCalendarItem {
  var isAllDayItem: Bool {
    guard let event = self as? EKEvent else {
      Logger.assertFail("Invalid item is returned")
      return false
    }

    return event.isAllDay
  }

  var startOfItem: Date? {
    guard let event = self as? EKEvent else {
      Logger.assertFail("Invalid item is returned")
      return nil
    }

    return event.startDate
  }

  var endOfItem: Date? {
    guard let event = self as? EKEvent else {
      Logger.assertFail("Invalid item is returned")
      return nil
    }

    return event.endDate
  }

  /**
   Whether the item has already ended, used to apply the past events style.
   */
  var isPastItem: Bool {
    guard let endOfItem else {
      return false
    }

    return endOfItem < Date.now
  }

  /**
   Whether the current user hasn't committed to attend the item.

   True when the invitation hasn't been responded to (participant status is pending),
   or when none of the attendees can be identified as the current user, e.g., invited
   indirectly through a group. Items organized by the current user are never pending.
   */
  var isPendingItem: Bool {
    guard let event = self as? EKEvent, let attendees = event.attendees, !attendees.isEmpty else {
      return false
    }

    guard event.organizer?.isCurrentUser != true else {
      return false
    }

    guard let currentUser = attendees.first(where: { $0.isCurrentUser }) else {
      return true
    }

    return currentUser.participantStatus == .pending
  }

  /**
   Evaluate if the startDate and endDate of an event has overlaps with the input dates.

   Basically used to determine if an event should be displayed on a given date.
   */
  func overlaps(startOfDay: Date, endOfDay: Date) -> Bool {
    guard let startOfItem, let endOfItem else {
      Logger.log(.error, "Missing startDate and endDate from EKCalendarItem")
      return false
    }

    let rangeOfItem = startOfItem...endOfItem
    let rangeOfDay = startOfDay...endOfDay

    return rangeOfItem.overlaps(rangeOfDay)
  }
}

public extension [EKCalendarItem] {
  var oldestToNewest: [Self.Element] {
    sorted { lhs, rhs in
      (lhs.startOfItem ?? .distantPast) < (rhs.startOfItem ?? .distantPast)
    }
  }
}
