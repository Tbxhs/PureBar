//
//  EKEventTests.swift
//
//  Created by cyan on 12/29/23.
//

import PureBarKit
import EventKit
import XCTest

final class EKEventTests: XCTestCase {
  func testOverlaps() {
    XCTAssertTrue({
      let event = EKEvent(eventStore: EKEventStore())
      event.startDate = Date.now
      event.endDate = event.startDate.addingTimeInterval(60 * 60)
      return event.overlaps(startOfDay: .now, endOfDay: .now.addingTimeInterval(10))
    }())

    XCTAssertFalse({
      let event = EKEvent(eventStore: EKEventStore())
      event.startDate = Date.now.addingTimeInterval(-24 * 60 * 60)
      event.endDate = event.startDate.addingTimeInterval(60 * 60)
      return event.overlaps(startOfDay: .now, endOfDay: .now.addingTimeInterval(10))
    }())
  }

  func testIsPendingItemWithoutAttendees() {
    // Attendees are read-only in EventKit, so only the no-attendee path is testable
    let event = EKEvent(eventStore: EKEventStore())
    event.startDate = Date.now
    event.endDate = event.startDate.addingTimeInterval(3600)
    XCTAssertFalse(event.isPendingItem)
  }

  func testIsPastItem() {
    let store = EKEventStore()

    let past = EKEvent(eventStore: store)
    past.startDate = Date.now.addingTimeInterval(-3600)
    past.endDate = Date.now.addingTimeInterval(-60)
    XCTAssertTrue(past.isPastItem)

    let ongoing = EKEvent(eventStore: store)
    ongoing.startDate = Date.now.addingTimeInterval(-60)
    ongoing.endDate = Date.now.addingTimeInterval(3600)
    XCTAssertFalse(ongoing.isPastItem)
  }
}
