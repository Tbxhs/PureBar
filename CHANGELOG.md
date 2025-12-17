# Changelog

## [2.2.0] - 2025-12-17
- 新增节假日图标样式选择功能（默认、符号、文字徽章）
- 文字徽章样式：绿色圆圈"休"表示放假日，红色圆圈"班"表示补班日
- 默认使用文字徽章样式，图标更加清晰易识别
- 恢复辅助功能菜单（减少动画效果、减少透明度）

## [2.1.1] - 2025-11-23
- 更新版权文案为“光阴似水，涓滴成时”
- 优化事件列表过滤逻辑并降低冗余日志
- 日历缓存改为简单 LRU，预加载范围缩小以减少无用查询
- 调整高频日志等级，减少日常使用的噪音
- 清理多余/过期的本地化键，去除 stale 状态

## [2.1.0] - 2025-11-16
- 优化了一些交互细节

## [2.0.2] - 2025-11-15
- Fixed text selection in custom format and custom symbol dialogs
- Enabled keyboard shortcuts (Cmd+C) for copying example text

## [2.0.1] - 2025-11-15
- Minor improvements and optimizations

## [2.0.0] - 2025-11-15
- Initial PureBar release (rebranded from LunarBar).
- Fixed crash on first launch when holiday directories don't exist.
- Updated all branding from LunarBar to PureBar.
- Configured Sparkle auto-update with EdDSA signing.
