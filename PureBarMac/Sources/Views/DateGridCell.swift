//
//  DateGridCell.swift
//  PureBarMac
//
//  Created by cyan on 12/22/23.
//

import AppKit
import AppKitControls
import EventKit
import PureBarKit

/**
 Grid cell that draws a day, including its solar date and lunar date and decorating views.

 Example: 22 初十
 */
final class DateGridCell: NSCollectionViewItem {
  static let reuseIdentifier = NSUserInterfaceItemIdentifier("DateGridCell")

  private(set) var cellDate: Date?
  private var displayedMonthDate: Date?
  private var cellEvents = [EKCalendarItem]()
  private var mainInfo = ""
  private var isDateSelected = false
  private var isHovered = false

  // Callback when the cell is clicked to select the date
  var onDateSelected: ((Date, [EKCalendarItem]) -> Void)?

  private let containerView: CustomButton = {
    let button = CustomButton()
    button.setAccessibilityElement(true)
    button.setAccessibilityRole(.button)
    button.setAccessibilityHelp(Localized.UI.accessibilityClickToRevealDate)

    return button
  }()

  private let highlightView: NSView = {
    let view = NSView()
    view.wantsLayer = true
    view.alphaValue = 0
    view.setAccessibilityHidden(true)

    view.layer?.cornerRadius = AppDesign.cellCornerRadius
    view.layer?.cornerCurve = .continuous

    return view
  }()

  private let selectionContainerView: NSView = {
    let view = NSView()
    view.wantsLayer = true
    view.isHidden = true
    view.setAccessibilityHidden(true)

    view.layer?.cornerCurve = .continuous
    view.layer?.masksToBounds = true

    return view
  }()

  private let solarLabel: TextLabel = {
    let label = TextLabel()
    label.textColor = Colors.primaryLabel
    label.font = .mediumSystemFont(ofSize: Constants.solarFontSize)
    label.setAccessibilityHidden(true)

    return label
  }()

  private let lunarLabel: TextLabel = {
    let label = TextLabel()
    label.textColor = Colors.primaryLabel
    label.font = .mediumSystemFont(ofSize: Constants.lunarFontSize)
    label.setAccessibilityHidden(true)

    return label
  }()

  private let eventView: EventView = {
    let view = EventView()
    view.setAccessibilityHidden(true)

    return view
  }()

  private let selectionRingView: NSView = {
    let view = NSView()
    view.wantsLayer = true
    view.setAccessibilityHidden(true)

    view.layer?.borderWidth = Constants.selectionBorderWidth
    view.layer?.cornerRadius = AppDesign.cellCornerRadius
    view.layer?.cornerCurve = .continuous

    return view
  }()

  // Glass effect views for macOS 26+ (stored as Any to avoid availability issues)
  private var glassSelectionView: Any?

  private let holidayView: NSImageView = {
    let view = NSImageView()
    view.isHidden = true
    view.setAccessibilityHidden(true)

    return view
  }()

  private var holidayViewWidthConstraint: NSLayoutConstraint?
  private var holidayViewHeightConstraint: NSLayoutConstraint?
}

// MARK: - Life Cycle

extension DateGridCell {
  override func loadView() {
    // Required prior to macOS Sonoma
    view = NSView(frame: .zero)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    setUp()
  }

  override func viewDidLayout() {
    super.viewDidLayout()
    containerView.frame = view.bounds

    let isDarkMode = view.effectiveAppearance.isDarkMode
    let reduceTransparency = AppPreferences.Accessibility.reduceTransparency
    let accentColor = Colors.controlAccent.resolvedColor(with: view.effectiveAppearance)

    // All interaction surfaces share the same fixed circle geometry.
    let radius = Constants.stateIndicatorSize / 2

    let hoverAlpha: Double
    if reduceTransparency {
      hoverAlpha = isDarkMode ? 0.10 : 0.07
    } else {
      hoverAlpha = isDarkMode ? 0.05 : 0.03
    }
    let hoverColor = (isDarkMode ? NSColor.white : NSColor.black)
      .withAlphaComponent(hoverAlpha)
    highlightView.layer?.backgroundColor = hoverColor.cgColor
    highlightView.layer?.cornerRadius = radius

    let fillAlpha: Double
    if reduceTransparency {
      fillAlpha = isDarkMode ? 0.22 : 0.18
    } else {
      fillAlpha = isDarkMode ? 0.15 : 0.11
    }
    let borderAlpha = isDarkMode ? 0.45 : 0.34
    let usesGlass = AppDesign.modernStyle && !reduceTransparency

    selectionContainerView.layer?.cornerRadius = radius
    selectionRingView.layer?.cornerRadius = radius
    selectionRingView.layer?.borderWidth = Constants.selectionBorderWidth
    selectionRingView.layer?.borderColor = accentColor
      .withAlphaComponent(borderAlpha)
      .cgColor
    selectionRingView.layer?.backgroundColor = accentColor
      .withAlphaComponent(usesGlass ? 0.04 : fillAlpha)
      .cgColor

    // Tahoe gets a tinted glass surface; Reduce Transparency uses the solid fallback above.
    if #available(macOS 26.0, *), AppDesign.modernStyle {
      let glassSelectionView = glassSelectionView as? NSGlassEffectView
      glassSelectionView?.isHidden = reduceTransparency
      glassSelectionView?.cornerRadius = radius
      glassSelectionView?.tintColor = accentColor.withAlphaComponent(isDarkMode ? 0.14 : 0.10)
    }
  }
}

// MARK: - Updating

extension DateGridCell {
  func updateViews(
    cellDate: Date,
    cellEvents: [EKCalendarItem],
    monthDate: Date?,
    lunarInfo: LunarInfo?
  ) {
    self.cellDate = cellDate
    self.displayedMonthDate = monthDate
    self.cellEvents = cellEvents

    let currentDate = Date.now
    let solarComponents = Calendar.solar.dateComponents([.year, .month, .day], from: cellDate)
    let lunarComponents = Calendar.lunar.dateComponents([.year, .month, .day], from: cellDate)
    let lastDayOfLunarYear = Calendar.lunar.lastDayOfYear(from: cellDate)
    let isLeapLunarMonth = Calendar.lunar.isLeapMonth(from: cellDate)

    let solarMonthDay = solarComponents.fourDigitsMonthDay
    let lunarMonthDay = lunarComponents.fourDigitsMonthDay

    let holidayType = HolidayManager.default.typeOf(
      year: solarComponents.year ?? 0, // It's too broken to have year as nil
      monthDay: solarMonthDay
    )

    // Solar day label
    if let day = solarComponents.day {
      solarLabel.stringValue = String(day)
    } else {
      Logger.assertFail("Failed to get solar day from date: \(cellDate)")
    }

    // Lunar day label
    if let day = lunarComponents.day {
      if day == 1, let month = lunarComponents.month {
        // The Chinese character "月" will shift the layout slightly to the left,
        // add a "thin space" to make it optically centered.
        lunarLabel.stringValue = "\u{2009}" + AppLocalizer.chineseMonth(of: month - 1, isLeap: isLeapLunarMonth)
      } else {
        lunarLabel.stringValue = AppLocalizer.chineseDay(of: day - 1)
      }
    } else {
      Logger.assertFail("Failed to get lunar day from date: \(cellDate)")
    }

    // Prefer solar term over normal lunar day
    if let solarTerm = lunarInfo?.solarTerms[solarMonthDay] {
      lunarLabel.stringValue = AppLocalizer.solarTerm(of: solarTerm)
    }

    // Prefer lunar holiday over solar term
    if let lunarHoliday = AppLocalizer.lunarFestival(of: lunarMonthDay) {
      lunarLabel.stringValue = lunarHoliday
    }

    // Chinese New Year's Eve, the last day of the lunar year, not necessarily a certain date
    if let lastDayOfLunarYear, Calendar.lunar.isDate(cellDate, inSameDayAs: lastDayOfLunarYear) {
      lunarLabel.stringValue = Localized.Calendar.chineseNewYearsEve
    }

    // Reload event dot views
    eventView.updateEvents(cellEvents)

    // Holiday indicator icons
    let iconStyle = AppPreferences.Calendar.holidayIconStyle
    let iconSize: Double = iconStyle == .textBadge ? Constants.textBadgeIconSize : Constants.defaultIconSize
    holidayViewWidthConstraint?.constant = iconSize
    holidayViewHeightConstraint?.constant = iconSize

    switch holidayType {
    case .none:
      holidayView.isHidden = true
      holidayView.image = nil
      holidayView.contentTintColor = nil
    case .workday:
      holidayView.isHidden = false
      holidayView.image = HolidayIconFactory.workdayIcon(style: iconStyle)
      // textBadge style already includes color, no need for additional tinting
      holidayView.contentTintColor = iconStyle == .textBadge ? nil : .systemRed
    case .holiday:
      holidayView.isHidden = false
      holidayView.image = HolidayIconFactory.holidayIcon(style: iconStyle)
      holidayView.contentTintColor = iconStyle == .textBadge ? nil : .systemGreen
    }

    updateOpacity(monthDate: monthDate)

    self.mainInfo = {
      var components: [String] = []
      // E.g. [Holiday]
      if let holidayLabel = AppLocalizer.holidayLabel(of: holidayType) {
        components.append(holidayLabel)
      }

      // Formatted lunar date, e.g., 癸卯年冬月十五 (leading numbers are removed to be concise)
      let lunarDate = Constants.lunarDateFormatter.string(from: cellDate)
      components.append(lunarDate.removingLeadingDigits)

      // Date ruler, e.g., "(10 days ago)" when hovering over a cell
      if let daysBetween = Calendar.solar.daysBetween(from: currentDate, to: cellDate) {
        if daysBetween == 0 {
          components.append(Localized.Calendar.todayLabel)
        } else {
          let format = daysBetween > 0 ? Localized.Calendar.daysLaterFormat : Localized.Calendar.daysAgoFormat
          components.append(String.localizedStringWithFormat(format, abs(daysBetween)))
        }
      }

      return components.joined()
    }()

    let accessibleDetails = {
      let eventTitles = cellEvents.compactMap { $0.title }

      // Only the main info
      if eventTitles.isEmpty {
        return mainInfo
      }

      // Full version, each trailing line is an event title
      return [mainInfo, eventTitles.joined(separator: "\n")].joined(separator: "\n\n")
    }()

    // Combine all visually available information to get the accessibility label
    containerView.setAccessibilityLabel([
      solarLabel.stringValue,
      lunarLabel.stringValue,
      accessibleDetails,
    ].compactMap { $0 }.joined(separator: " "))
  }

  func updateOpacity(monthDate: Date?) {
    displayedMonthDate = monthDate

    let currentDate = Date.now
    let cellDate = cellDate ?? currentDate

    let solarComponents = Calendar.solar.dateComponents([.month], from: cellDate)
    let isDateToday = Calendar.solar.isDate(cellDate, inSameDayAs: currentDate)
    let usesAccent = isDateToday || isDateSelected

    // Today is marked by accent text; selection adds the surrounding accent surface.
    solarLabel.font = .systemFont(
      ofSize: Constants.solarFontSize,
      weight: usesAccent ? .semibold : .medium
    )

    if let monthDate, Calendar.solar.month(from: monthDate) == solarComponents.month {
      // Current month: use primary color
      solarLabel.textColor = usesAccent ? Colors.controlAccent : Colors.primaryLabel
      lunarLabel.textColor = Colors.primaryLabel

      if Calendar.solar.isDateInWeekend(cellDate) && !isDateToday && !isDateSelected {
        // Current month weekend: 70% alpha (medium strength)
        solarLabel.alphaValue = AlphaLevels.secondary
      } else {
        // Current month weekday: 100% alpha (strongest)
        solarLabel.alphaValue = AlphaLevels.primary
      }

      // Intentional, secondary alpha is used only for labels at weekends
      eventView.alphaValue = AlphaLevels.primary
    } else {
      // Non-current month: use secondary color with reduced alpha (weakest)
      solarLabel.textColor = usesAccent ? Colors.controlAccent : Colors.secondaryLabel
      lunarLabel.textColor = Colors.secondaryLabel
      // An actively selected overflow date remains legible while its event metadata stays subdued.
      solarLabel.alphaValue = isDateSelected ? AlphaLevels.primary : 0.6

      // Event dots and holiday indicator use lower opacity
      eventView.alphaValue = 0.5
    }

    lunarLabel.alphaValue = solarLabel.alphaValue
    holidayView.alphaValue = eventView.alphaValue
  }

  @discardableResult
  func cancelHighlight() -> Bool {
    isHovered = false
    updateHover(animated: false)
    return false
  }

  func setSelected(_ selected: Bool) {
    let wasSelected = isDateSelected
    isDateSelected = selected

    if wasSelected != selected {
      animateSelection(show: selected)
    } else {
      setSelectionVisible(selected)
    }

    updateHover(animated: wasSelected != selected)

    if cellDate != nil {
      updateOpacity(monthDate: displayedMonthDate)
    }
  }
}

// MARK: - Private

private extension DateGridCell {
  enum Constants {
    static let solarFontSize: Double = FontSizes.regular
    static let lunarFontSize: Double = FontSizes.small
    static let eventViewHeight: Double = 10
    static let selectionBorderWidth: Double = 1
    static let defaultIconSize: Double = 9
    static let textBadgeIconSize: Double = 11
    static let lunarDateFormatter: DateFormatter = .lunarDate
    static let stateIndicatorSize: Double = 40
  }

  enum AnimationConstants {
    static let selectionShowDuration: TimeInterval = 0.14
    static let selectionHideDuration: TimeInterval = 0.10
    static let selectionInitialScale: Double = 0.96
    static let hoverDuration: TimeInterval = 0.08
  }

  func setUp() {
    view.addSubview(containerView)
    containerView.addAction { [weak self] in
      self?.handleCellClick()
    }
    containerView.onMouseHover = { [weak self] isHovered in
      self?.setHovered(isHovered)
    }

    highlightView.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(highlightView)

    selectionContainerView.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(selectionContainerView)

    selectionRingView.translatesAutoresizingMaskIntoConstraints = false
    selectionContainerView.addSubview(selectionRingView)

    solarLabel.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(solarLabel)
    NSLayoutConstraint.activate([
      solarLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
      solarLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: AppDesign.cellRectInset),
    ])

    lunarLabel.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(lunarLabel)
    NSLayoutConstraint.activate([
      lunarLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
      lunarLabel.topAnchor.constraint(equalTo: solarLabel.bottomAnchor),
    ])

    eventView.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(eventView)
    NSLayoutConstraint.activate([
      eventView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
      eventView.topAnchor.constraint(equalTo: lunarLabel.bottomAnchor),
      eventView.heightAnchor.constraint(equalToConstant: Constants.eventViewHeight),
      // Ensure eventView has enough space from the bottom to prevent clipping
      eventView.bottomAnchor.constraint(
        lessThanOrEqualTo: containerView.bottomAnchor,
        constant: -AppDesign.cellRectInset
      ),
    ])

    NSLayoutConstraint.activate([
      highlightView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
      highlightView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
      highlightView.widthAnchor.constraint(equalToConstant: Constants.stateIndicatorSize),
      highlightView.heightAnchor.constraint(equalToConstant: Constants.stateIndicatorSize),

      selectionContainerView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
      selectionContainerView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
      selectionContainerView.widthAnchor.constraint(equalToConstant: Constants.stateIndicatorSize),
      selectionContainerView.heightAnchor.constraint(equalToConstant: Constants.stateIndicatorSize),

      selectionRingView.leadingAnchor.constraint(equalTo: selectionContainerView.leadingAnchor),
      selectionRingView.topAnchor.constraint(equalTo: selectionContainerView.topAnchor),
      selectionRingView.trailingAnchor.constraint(equalTo: selectionContainerView.trailingAnchor),
      selectionRingView.bottomAnchor.constraint(equalTo: selectionContainerView.bottomAnchor),
    ])

    holidayView.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(holidayView)

    let widthConstraint = holidayView.widthAnchor.constraint(equalToConstant: 9)
    let heightConstraint = holidayView.heightAnchor.constraint(equalToConstant: 9)
    holidayViewWidthConstraint = widthConstraint
    holidayViewHeightConstraint = heightConstraint

    NSLayoutConstraint.activate([
      holidayView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: -3.5),
      holidayView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -1.5),
      widthConstraint,
      heightConstraint,
    ])

    let longPressRecognizer = NSPressGestureRecognizer(target: self, action: #selector(onLongPress(_:)))
    longPressRecognizer.minimumPressDuration = 0.5
    view.addGestureRecognizer(longPressRecognizer)

    // Setup the selected glass surface for macOS 26+.
    if #available(macOS 26.0, *), AppDesign.modernStyle {
      setupGlassEffects()
    }
  }

  @available(macOS 26.0, *)
  func setupGlassEffects() {
    let isDarkMode = view.effectiveAppearance.isDarkMode
    let glassSelection = NSGlassEffectView()
    glassSelection.cornerRadius = Constants.stateIndicatorSize / 2
    glassSelection.tintColor = Colors.controlAccent
      .resolvedColor(with: view.effectiveAppearance)
      .withAlphaComponent(isDarkMode ? 0.14 : 0.10)
    glassSelection.translatesAutoresizingMaskIntoConstraints = false
    glassSelection.setAccessibilityHidden(true)

    selectionContainerView.addSubview(glassSelection, positioned: .below, relativeTo: selectionRingView)
    NSLayoutConstraint.activate([
      glassSelection.leadingAnchor.constraint(equalTo: selectionContainerView.leadingAnchor),
      glassSelection.topAnchor.constraint(equalTo: selectionContainerView.topAnchor),
      glassSelection.trailingAnchor.constraint(equalTo: selectionContainerView.trailingAnchor),
      glassSelection.bottomAnchor.constraint(equalTo: selectionContainerView.bottomAnchor),
    ])
    self.glassSelectionView = glassSelection
  }

  func handleCellClick() {
    guard let cellDate else {
      return Logger.assertFail("Missing cellDate to continue")
    }

    // Haptic feedback for glass-like tactile experience
    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)

    // Notify parent view to update event list immediately (no animation delay)
    onDateSelected?(cellDate, cellEvents)
  }

  @objc func onLongPress(_ recognizer: NSPressGestureRecognizer) {
    guard recognizer.state == .began, let cellDate else {
      return
    }

    NSHapticFeedbackManager.defaultPerformer.perform(
      .generic,
      performanceTime: .now
    )

    (NSApp.delegate as? AppDelegate)?.countDaysBetween(targetDate: cellDate)
  }
}

// MARK: - Interaction State

private extension DateGridCell {
  func setHovered(_ hovered: Bool) {
    guard isHovered != hovered else {
      return
    }

    isHovered = hovered
    updateHover(animated: true)
  }

  func updateHover(animated: Bool) {
    let targetAlpha = isHovered && !isDateSelected ? 1.0 : 0.0

    guard animated, !AppPreferences.Accessibility.reduceMotion else {
      highlightView.layer?.removeAllAnimations()
      highlightView.alphaValue = targetAlpha
      return
    }

    NSAnimationContext.runAnimationGroup { context in
      context.duration = AnimationConstants.hoverDuration
      context.timingFunction = CAMediaTimingFunction(name: .easeOut)
      highlightView.animator().alphaValue = targetAlpha
    }
  }

  func animateSelection(show: Bool) {
    guard !AppPreferences.Accessibility.reduceMotion else {
      setSelectionVisible(show)
      return
    }

    selectionContainerView.layer?.removeAllAnimations()

    if show {
      selectionContainerView.isHidden = false
      selectionContainerView.alphaValue = 0

      let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
      scaleAnimation.fromValue = AnimationConstants.selectionInitialScale
      scaleAnimation.toValue = 1.0
      scaleAnimation.duration = AnimationConstants.selectionShowDuration
      scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
      selectionContainerView.layer?.add(scaleAnimation, forKey: "selectionScale")

      NSAnimationContext.runAnimationGroup { context in
        context.duration = AnimationConstants.selectionShowDuration
        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
        selectionContainerView.animator().alphaValue = 1
      }
    } else {
      NSAnimationContext.runAnimationGroup { context in
        context.duration = AnimationConstants.selectionHideDuration
        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
        selectionContainerView.animator().alphaValue = 0
      } completionHandler: { [weak self] in
        guard let self, !self.isDateSelected else {
          return
        }

        self.selectionContainerView.isHidden = true
      }
    }
  }

  func setSelectionVisible(_ visible: Bool) {
    selectionContainerView.layer?.removeAllAnimations()
    selectionContainerView.alphaValue = visible ? 1 : 0
    selectionContainerView.isHidden = !visible
  }
}
