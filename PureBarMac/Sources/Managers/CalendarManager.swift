//
//  CalendarManager.swift
//  PureBarMac
//
//  Created by cyan on 12/24/23.
//

import Foundation
import EventKit
import PureBarKit

struct DateRange: Hashable {
  let start: Date
  let end: Date
}

/**
 For the native Calendar app.
 */
@MainActor
final class CalendarManager {
  static let `default` = CalendarManager()

  private var eventStore = EKEventStore()
  private var memoryCache = [DateRange: [EKCalendarItem]]()
  private var cacheOrder = [DateRange]()  // Maintain insertion order for a simple LRU
  private let cacheLimit = 128

  var authorizationStatus: EKAuthorizationStatus {
    EKEventStore.authorizationStatus(for: .event)
  }

  func requestAccessIfNeeded() async {
    guard authorizationStatus == .notDetermined else {
      return
    }

    do {
      let result = try await eventStore.requestFullAccessToEvents()
      Logger.log(.info, "Result of the event access request: \(result)")
    } catch {
      Logger.log(.error, error.localizedDescription)
    }

    eventStore = EKEventStore()
  }

  func allCalendars() -> [EKCalendar] {
    guard hasReadAccess else {
      return []
    }

    return eventStore.calendars(for: .event)
  }

  func items(from startDate: Date, to endDate: Date) -> [EKCalendarItem] {
    let items = events(from: startDate, to: endDate)
    if !items.isEmpty {
      let range = DateRange(start: startDate, end: endDate)
      updateCache(range: range, items: items)
    }

    return items
  }

  func revealDateInCalendar(_ date: Date) {
    Task {
      // Requires Calendar access to locate the specified date
      await requestAccessIfNeeded()

      let source =
      """
      tell application "Calendar"
        activate
        switch view to day view
        view calendar at date "\(Constants.scriptingDateFormatter.string(from: date))"
      end tell
      """

      DispatchQueue.global(qos: .userInitiated).async {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        script?.executeAndReturnError(&error)

        if let error {
          Logger.log(.error, String(describing: error))
        } else {
        #if DEBUG
          Logger.log(.debug, "Successfully revealed the date")
        #endif
        }
      }
    }
  }

  private init() {}
}

// MARK: - Caching

extension CalendarManager {
  func clearCaches() {
    memoryCache.removeAll()
    cacheOrder.removeAll()
  }

  func caches(from startDate: Date, to endDate: Date) -> [EKCalendarItem]? {
    let range = DateRange(start: startDate, end: endDate)
    guard let items = memoryCache[range] else {
      return nil
    }

    // Bump to most-recent
    if let index = cacheOrder.firstIndex(of: range) {
      cacheOrder.remove(at: index)
      cacheOrder.append(range)
    }

    return items
  }

  func preload(date: Date) {
    guard let monthDates = Calendar.solar.allDatesFillingMonth(from: date) else {
      return Logger.log(.error, "Missing monthDates to continue preloading")
    }

    guard let startDate = monthDates.first, let endDate = monthDates.last else {
      return Logger.log(.error, "Missing startDate or endDate to continue preloading")
    }

    _ = items(from: startDate, to: endDate)
  }
}

// MARK: - Private

private extension CalendarManager {
  enum Constants {
    static let scriptingDateFormatter: DateFormatter = .fullDate
  }

  func updateCache(range: DateRange, items: [EKCalendarItem]) {
    // Remove existing entry from order if present
    if let index = cacheOrder.firstIndex(of: range) {
      cacheOrder.remove(at: index)
    }

    // Insert as most-recent
    cacheOrder.append(range)
    memoryCache[range] = items

    // Evict oldest while exceeding limit
    while cacheOrder.count > cacheLimit {
      let oldest = cacheOrder.removeFirst()
      memoryCache.removeValue(forKey: oldest)
    }
  }

  var hasReadAccess: Bool {
    authorizationStatus == .fullAccess
  }

  func events(from startDate: Date, to endDate: Date) -> [EKCalendarItem] {
    guard hasReadAccess else {
      return []
    }

    let hidden = AppPreferences.Calendar.hiddenCalendars
    let calendars = allCalendars().filter { !hidden.contains($0.calendarIdentifier) }

    // EventKit searches all calendars when calendars is empty
    guard !calendars.isEmpty else {
      return []
    }

  #if DEBUG
    let perfStartTime = Date.timeIntervalSinceReferenceDate
  #endif

    // Get the earliest of the start and the latest of the end
    let startOfDayDate = Calendar.solar.startOfDay(for: startDate)
    let endOfDayDate = Calendar.solar.endOfDay(for: endDate)

    let events = eventStore.events(from: startOfDayDate, to: endOfDayDate, calendars: calendars)

  #if DEBUG
    let perfEndTime = Date.timeIntervalSinceReferenceDate
    Logger.log(.info, "Time used querying \(events.count) events: \(perfEndTime - perfStartTime)")
  #endif

    return events
  }
}
