//
//  HeaderView.swift
//  PureBarMac
//
//  Created by cyan on 12/21/23.
//

import AppKit
import AppKitControls
import PureBarKit

@MainActor
protocol HeaderViewDelegate: AnyObject {
  func headerView(_ sender: HeaderView, moveTo date: Date)
  func headerView(_ sender: HeaderView, moveBy offset: Int)
  func headerViewGotoToday(_ sender: HeaderView)
}

/**
 Calendar header, showing the date and a few buttons for navigation.

 Example: [ Dec 2023    < O > ]
 */
final class HeaderView: NSView {
  weak var delegate: HeaderViewDelegate?

  // Date display: split into two labels for partial animation
  private let dateContainer = NSView()

  private let primaryLabel: TextLabel = {
    let label = TextLabel()
    label.textColor = Colors.primaryLabel
    label.font = .monospacedDigitSystemFont(ofSize: Constants.dateFontSize, weight: .medium)
    return label
  }()

  private let secondaryLabel: TextLabel = {
    let label = TextLabel()
    label.textColor = Colors.primaryLabel
    label.font = .monospacedDigitSystemFont(ofSize: Constants.dateFontSize, weight: .medium)
    return label
  }()

  private lazy var nextButton: ImageButton = {
    let button = createButton(
      symbolName: Icons.chevronCompactForward,
      accessibilityLabel: Localized.UI.buttonTitleNextMonth
    )

    button.addAction { [weak self] in
      guard let self else {
        return
      }

      delegate?.headerView(self, moveBy: 1)
    }

    button.toolTip = Localized.UI.buttonTitleNextMonth + " ▶"
    return button
  }()

  private lazy var actionsButton: ImageButton = {
    let button = createButton(
      symbolName: Icons.locationFill,
      accessibilityLabel: Localized.UI.buttonTitleGotoToday
      // 使用默认颜色（primaryLabel），与其他按钮保持一致
    )

    button.addAction { [weak self] in
      guard let self else {
        return
      }

      self.delegate?.headerViewGotoToday(self)
    }

    button.toolTip = Localized.UI.buttonTitleGotoToday
    button.alphaValue = 0  // Hidden by default
    return button
  }()

  private lazy var previousButton: ImageButton = {
    let button = createButton(
      symbolName: Icons.chevronCompactBackward,
      accessibilityLabel: Localized.UI.buttonTitlePreviousMonth
    )

    button.addAction { [weak self] in
      guard let self else {
        return
      }

      delegate?.headerView(self, moveBy: -1)
    }

    button.toolTip = "◀ " + Localized.UI.buttonTitlePreviousMonth
    return button
  }()

  private var previousDate: Date = .distantPast
  private var currentIconStyle: HolidayIconStyle?

  init() {
    super.init(frame: .zero)

    // Date container with clipping for ticker animation
    dateContainer.translatesAutoresizingMaskIntoConstraints = false
    dateContainer.wantsLayer = true
    dateContainer.layer?.masksToBounds = true
    addSubview(dateContainer)

    // Primary label (first component: year for CJK, month for Western)
    primaryLabel.translatesAutoresizingMaskIntoConstraints = false
    dateContainer.addSubview(primaryLabel)

    // Secondary label (second component: month for CJK, year for Western)
    secondaryLabel.translatesAutoresizingMaskIntoConstraints = false
    dateContainer.addSubview(secondaryLabel)

    NSLayoutConstraint.activate([
      dateContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Constants.datePadding),
      dateContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
      dateContainer.heightAnchor.constraint(equalTo: heightAnchor),

      primaryLabel.leadingAnchor.constraint(equalTo: dateContainer.leadingAnchor),
      primaryLabel.centerYAnchor.constraint(equalTo: dateContainer.centerYAnchor),

      secondaryLabel.leadingAnchor.constraint(equalTo: primaryLabel.trailingAnchor),
      secondaryLabel.centerYAnchor.constraint(equalTo: dateContainer.centerYAnchor),
      secondaryLabel.trailingAnchor.constraint(equalTo: dateContainer.trailingAnchor),
    ])

    nextButton.translatesAutoresizingMaskIntoConstraints = false
    addSubview(nextButton)
    NSLayoutConstraint.activate([
      nextButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Constants.buttonPadding),
      nextButton.centerYAnchor.constraint(equalTo: centerYAnchor),
      nextButton.widthAnchor.constraint(equalToConstant: nextButton.frame.width),
      nextButton.heightAnchor.constraint(equalToConstant: nextButton.frame.height),
    ])

    actionsButton.translatesAutoresizingMaskIntoConstraints = false
    addSubview(actionsButton)
    NSLayoutConstraint.activate([
      actionsButton.trailingAnchor.constraint(equalTo: nextButton.leadingAnchor),
      actionsButton.centerYAnchor.constraint(equalTo: centerYAnchor),
      actionsButton.widthAnchor.constraint(equalToConstant: actionsButton.frame.width),
      actionsButton.heightAnchor.constraint(equalToConstant: actionsButton.frame.height),
    ])

    previousButton.translatesAutoresizingMaskIntoConstraints = false
    addSubview(previousButton)
    NSLayoutConstraint.activate([
      previousButton.trailingAnchor.constraint(equalTo: actionsButton.leadingAnchor),
      previousButton.centerYAnchor.constraint(equalTo: centerYAnchor),
      previousButton.widthAnchor.constraint(equalToConstant: previousButton.frame.width),
      previousButton.heightAnchor.constraint(equalToConstant: previousButton.frame.height),
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func mouseUp(with event: NSEvent) {
    super.mouseUp(with: event)

    // Hidden way to goto today
    if dateContainer.frame.contains(convert(event.locationInWindow, from: nil)) {
      delegate?.headerViewGotoToday(self)
    }
  }
}

// MARK: - Updating

extension HeaderView {
  enum ButtonIdentifier {
    case previous
    case actions
    case next
  }

  func updateCalendar(date: Date) {
    let newPrimary = Constants.primaryFormatter.string(from: date)
    let newSecondary = Constants.secondaryFormatter.string(from: date)

    let shouldAnimate = !AppPreferences.Accessibility.reduceMotion
      && previousDate != .distantPast
      && !Calendar.solar.isDate(previousDate, inSameMonthAs: date)

    if shouldAnimate {
      let forward = previousDate < date
      let primaryChanged = primaryLabel.stringValue != newPrimary
      let secondaryChanged = secondaryLabel.stringValue != newSecondary

      // Animate only the labels that actually changed
      if secondaryChanged {
        animateLabel(secondaryLabel, to: newSecondary, forward: forward)
      }
      if primaryChanged {
        let primaryDelay = secondaryChanged ? Constants.staggerDelay : 0
        animateLabel(primaryLabel, to: newPrimary, forward: forward, delay: primaryDelay)
      }
    } else {
      primaryLabel.stringValue = newPrimary
      secondaryLabel.stringValue = newSecondary
    }

    previousDate = date
    updateTodayButtonState(for: date)
    updateTodayButtonIcon()
  }

  func updateTodayButtonState(for date: Date) {
    let isCurrentMonth = Calendar.solar.isDate(date, inSameMonthAs: Date.now)
    // Hide button when viewing current month, show when viewing other months
    actionsButton.alphaValue = isCurrentMonth ? 0 : 1
  }

  func updateTodayButtonIcon() {
    let style = AppPreferences.Calendar.holidayIconStyle
    guard style != currentIconStyle else {
      return
    }

    currentIconStyle = style
    let iconSize = Constants.iconSize + Constants.sizeDelta
    let icon: NSImage
    if style == .textBadge {
      icon = HolidayIconFactory.todayIcon(pointSize: iconSize - 1)
    } else {
      icon = .with(symbolName: Icons.locationFill, pointSize: iconSize, weight: .semibold)
    }

    actionsButton.updateIcon(image: icon)
  }

  func showClickEffect(for identifier: ButtonIdentifier) {
    guard !AppPreferences.Accessibility.reduceMotion else {
      return
    }

    let button = {
      switch identifier {
      case .previous: return previousButton
      case .actions: return actionsButton
      case .next: return nextButton
      }
    }()

    button.setAlphaValue(0.6) {
      Task { @MainActor in
        button.setAlphaValue(1)
      }
    }
  }
}

// MARK: - Private

private extension HeaderView {
  enum Constants {
    static let dateFontSize: Double = FontSizes.large
    static let datePadding: Double = 9
    static let buttonPadding: Double = 6
    static let iconSize: Double = 14
    @MainActor static let sizeDelta: Double = AppDesign.modernStyle ? 1 : 0
    static let animationDuration: TimeInterval = 0.3
    static let staggerDelay: TimeInterval = 0.04
    static let slideOffset: CGFloat = 20

    // Determine locale order: CJK locales show year first, others show month first
    static let yearFirst: Bool = {
      let id = Locale.autoupdatingCurrent.identifier
      return id.hasPrefix("zh") || id.hasPrefix("ja") || id.hasPrefix("ko")
    }()

    // Primary = the part that appears first (left side)
    // Secondary = the part that appears second (right side)
    static let primaryFormatter: DateFormatter = {
      let formatter = DateFormatter()
      formatter.locale = .autoupdatingCurrent
      formatter.setLocalizedDateFormatFromTemplate(yearFirst ? "y" : "MMM")
      // Append a separator for the first part
      if yearFirst {
        // Keep the localized format as-is (e.g., "2026年" in zh)
      } else {
        // Add trailing space for Western locales (e.g., "Apr ")
        let base = formatter.dateFormat ?? ""
        formatter.dateFormat = base + " "
      }
      return formatter
    }()

    static let secondaryFormatter: DateFormatter = {
      let formatter = DateFormatter()
      formatter.locale = .autoupdatingCurrent
      formatter.setLocalizedDateFormatFromTemplate(yearFirst ? "MMM" : "y")
      return formatter
    }()
  }

  /// Ticker-style animation: old text slides out, new text slides in
  func animateLabel(_ label: TextLabel, to newValue: String, forward: Bool, delay: TimeInterval = 0) {
    let slideOffset = Constants.slideOffset
    let direction: CGFloat = forward ? -1 : 1  // forward = slide up (negative Y)

    // Snapshot the old text
    let snapshot = TextLabel()
    snapshot.stringValue = label.stringValue
    snapshot.font = label.font
    snapshot.textColor = label.textColor
    snapshot.translatesAutoresizingMaskIntoConstraints = false
    snapshot.alphaValue = 1

    dateContainer.addSubview(snapshot)
    NSLayoutConstraint.activate([
      snapshot.leadingAnchor.constraint(equalTo: label.leadingAnchor),
      snapshot.centerYAnchor.constraint(equalTo: label.centerYAnchor),
    ])

    // Set new text and prepare entry position
    label.stringValue = newValue
    label.alphaValue = 0

    // Force layout so snapshot is positioned correctly
    dateContainer.layoutSubtreeIfNeeded()

    // Offset the new label to its start position (below or above)
    let entryOffset = -direction * slideOffset
    label.wantsLayer = true
    snapshot.wantsLayer = true
    label.layer?.transform = CATransform3DMakeTranslation(0, entryOffset, 0)

    let animate = {
      NSAnimationContext.runAnimationGroup { context in
        context.duration = Constants.animationDuration
        context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0, 0, 1)
        context.allowsImplicitAnimation = true

        // Old text slides out + fades
        snapshot.animator().alphaValue = 0
        snapshot.layer?.transform = CATransform3DMakeTranslation(0, direction * slideOffset, 0)

        // New text slides in + appears
        label.animator().alphaValue = 1
        label.layer?.transform = CATransform3DIdentity
      } completionHandler: {
        snapshot.removeFromSuperview()
      }
    }

    if delay > 0 {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: animate)
    } else {
      animate()
    }
  }

  func createButton(symbolName: String, accessibilityLabel: String, tintColor: NSColor? = Colors.primaryLabel) -> ImageButton {
    ImageButton(
      symbolName: symbolName,
      sizeDelta: Constants.sizeDelta,
      cornerRadius: AppDesign.cellCornerRadius,
      highlightColorProvider: { .highlightedBackground },
      tintColor: tintColor,
      accessibilityLabel: accessibilityLabel
    )
  }
}
