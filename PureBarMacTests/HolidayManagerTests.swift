//
//  HolidayManagerTests.swift
//  PureBarMacTests
//
//  Created by cyan on 12/29/23.
//

import XCTest
@testable import PureBar

@MainActor
final class HolidayManagerTests: XCTestCase {
  func testDataOf2024() {
    let manager = HolidayManager.default
    XCTAssertEqual(manager.typeOf(year: 2024, monthDay: "0101"), .holiday)
    XCTAssertEqual(manager.typeOf(year: 2024, monthDay: "0204"), .workday)
  }

  func testCachedFiles() {
    let manager = HolidayManager.default
    let fileURL = URL.cachesDirectory
      .appending(path: "Holidays", directoryHint: .isDirectory)
      .appending(path: "test-custom.json", directoryHint: .notDirectory)

    try? FileManager.default.removeItem(at: fileURL)
    defer {
      try? FileManager.default.removeItem(at: fileURL)
    }

    try? JSONSerialization.data(withJSONObject: ["2099": ["0101": 2, "0102": 1]]).write(
      to: fileURL,
      options: .atomic
    )

    manager.reloadCachedFiles()
    XCTAssertEqual(manager.typeOf(year: 2099, monthDay: "0101"), .holiday)
    XCTAssertEqual(manager.typeOf(year: 2099, monthDay: "0102"), .workday)
    XCTAssertNil(manager.typeOf(year: 2099, monthDay: "0103"))
  }
}
