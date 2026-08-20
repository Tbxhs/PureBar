//
//  EventView.swift
//  PureBarMac
//
//  Created by cyan on 12/24/23.
//

import AppKit
import EventKit
import PureBarKit

/**
 UI component to draw Calendar events as dots.
 */
final class EventView: NSStackView {
  init() {
    super.init(frame: .zero)
    spacing = Constants.spacing
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func updateEvents(_ events: [EKCalendarItem]) {
    isHidden = events.isEmpty
    removeArrangedSubviews()

    // Dim the day only when every event is one the user hasn't committed to,
    // dimming individual dots is ambiguous since dots are anonymous
    let allPending = !events.isEmpty && events.allSatisfy { $0.isPendingItem }
    let alpha = allPending ? Constants.pendingAlpha : Constants.normalAlpha

    // Only show up to three dots due to limited space
    events.prefix(Constants.eventLimit).forEach {
      let dotView = DotView()
      let baseColor = $0.calendar?.color ?? Colors.controlAccent
      // 降低亮度：使用透明度让颜色更柔和
      dotView.layerBackgroundColor = baseColor.withAlphaComponent(alpha)
      addArrangedSubview(dotView)
    }
  }
}

// MARK: - Private

private extension EventView {
  enum Constants {
    static let spacing: Double = 2
    static let eventLimit = 3
    static let normalAlpha: Double = 0.7
    static let pendingAlpha: Double = 0.35
  }
}

private class DotView: NSView {
  enum Constants {
    static let dotSize: Double = 4
  }

  init() {
    super.init(frame: .zero)
    wantsLayer = true
    clipsToBounds = true
    layer?.cornerRadius = Constants.dotSize * 0.5
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layout() {
    super.layout()

    if let borderColor = layerBackgroundColor?.darkerColor() {
      layer?.borderWidth = hairlineWidth
      layer?.borderColor = borderColor.cgColor
    }
  }

  override var intrinsicContentSize: CGSize {
    CGSize(width: Constants.dotSize, height: Constants.dotSize)
  }
}
