//
//  HolidayIconFactory.swift
//  PureBarMac
//
//  Created by Claude on 12/17/25.
//

import AppKit

/**
 Factory for creating holiday icons in different styles.
 */
enum HolidayIconFactory {
  private enum Constants {
    static let iconSize: Double = 9
    static let textBadgeSize: Double = 11
  }

  /// Get holiday (day off) icon based on style
  static func holidayIcon(style: HolidayIconStyle) -> NSImage {
    switch style {
    case .default:
      return .with(symbolName: "circle.fill", pointSize: Constants.iconSize)
    case .symbol:
      return .with(symbolName: "moon.fill", pointSize: Constants.iconSize)
    case .textBadge:
      return createTextBadge(text: "休", backgroundColor: .systemGreen)
    }
  }

  /// Get workday (work on holiday) icon based on style
  static func workdayIcon(style: HolidayIconStyle) -> NSImage {
    switch style {
    case .default:
      return .with(symbolName: "briefcase.fill", pointSize: Constants.iconSize)
    case .symbol:
      return .with(symbolName: "briefcase.circle.fill", pointSize: Constants.iconSize)
    case .textBadge:
      return createTextBadge(text: "班", backgroundColor: .systemRed)
    }
  }

  /// Create a text badge icon (circle + text)
  private static func createTextBadge(text: String, backgroundColor: NSColor) -> NSImage {
    let size = CGSize(width: Constants.textBadgeSize, height: Constants.textBadgeSize)
    let image = NSImage(size: size)

    image.lockFocus()

    // Draw circular background
    let rect = CGRect(origin: .zero, size: size)
    let path = NSBezierPath(ovalIn: rect)
    backgroundColor.setFill()
    path.fill()

    // Draw text
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.boldSystemFont(ofSize: 7),
      .foregroundColor: NSColor.white,
    ]

    let textSize = text.size(withAttributes: attributes)
    let textRect = CGRect(
      x: (size.width - textSize.width) / 2,
      y: (size.height - textSize.height) / 2 - 0.5, // Fine-tune vertical centering
      width: textSize.width,
      height: textSize.height
    )

    text.draw(in: textRect, withAttributes: attributes)

    image.unlockFocus()
    return image
  }
}
