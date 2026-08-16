//
//  AppPreferencesTests.swift
//  PureBarMacTests
//
//  Created by cyan on 12/31/23.
//

import EventKit
import XCTest
@testable import PureBar

@MainActor
final class AppPreferencesTests: XCTestCase {
  func testPastEventsStyleHidesEndedEvents() {
    let store = EKEventStore()

    let past = EKEvent(eventStore: store)
    past.startDate = Date.now.addingTimeInterval(-3600)
    past.endDate = Date.now.addingTimeInterval(-1800)

    let ongoing = EKEvent(eventStore: store)
    ongoing.startDate = Date.now.addingTimeInterval(-1800)
    ongoing.endDate = Date.now.addingTimeInterval(1800)

    let items = [past, ongoing]
    XCTAssertEqual(PastEventsStyle.hidden.displayed(items).map(\.calendarItemIdentifier), [ongoing.calendarItemIdentifier])
    XCTAssertEqual(PastEventsStyle.dimmed.displayed(items).count, 2)
    XCTAssertEqual(PastEventsStyle.unchanged.displayed(items).count, 2)
  }

  func testSetEncodingDecoding() {
    AppPreferences.Mocked.setObjects.removeAll()
    XCTAssertEqual(AppPreferences.Mocked.setObjects, Set())

    AppPreferences.Mocked.setObjects.insert("Foo")
    AppPreferences.Mocked.setObjects.insert("Bar")
    XCTAssertEqual(AppPreferences.Mocked.setObjects, Set(["Foo", "Bar"]))

    AppPreferences.Mocked.setObjects.toggle("Foo")
    XCTAssertEqual(AppPreferences.Mocked.setObjects, Set(["Bar"]))
  }
}

// MARK: - Private

private extension AppPreferences {
  enum Mocked {
    @Storage(key: "mocked.set-objects", defaultValue: Set())
    static var setObjects: Set<String>
  }
}
