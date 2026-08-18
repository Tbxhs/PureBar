# PureBar

macOS 菜单栏日历 App：农历、公共假日、系统日历集成，纯 AppKit 实现（零 SwiftUI），MIT 开源于 github.com/tbxhs/PureBar。当前 v2.7.2 / build 27，版本号在 `Build.xcconfig`。

项目原名 LunarBar，改名 PureBar 后仍有历史残留属正常：`project.pbxproj` 里 PBXProject 注释、`PureBarKit/Sources/LunarCalendar` 目录名、`PureBarKit/.swiftpm` 下 `LunarBar*Tests.xcscheme` 死 scheme 文件，均不用清理。

## 目录要点
- `PureBarMac/`：主 App target，`Sources/{Main,Views,Managers,Updater,Shared}`
- `PureBarMac/Modules/`：本地 SPM 包，出 `AppKitControls`/`AppKitExtensions` 两个 UI 组件库
- `PureBarKit/`：核心逻辑 SPM 包（农历换算等）
- `PureBarTools/`：只含 SwiftLint build-tool 插件（二进制 0.61.0 由 SPM 自动拉取，不需要 `brew install swiftlint`）
- `PureBarMacTests/`：单元测试，宿主是 App 本体，不是独立 test bundle

## 构建 / 测试
- 无 XcodeGen，`PureBar.xcodeproj` 是手写工程，直接 `open` 后选 scheme `PureBarMac`（Xcode 16+）
- 测试用 `xcodebuild -project PureBar.xcodeproj -scheme PureBarMac test`；`TEST_HOST` 指向 App 本体可执行文件。PureBarKit 单独 `swift test` 会被 SwiftLint 插件的沙盒挡住，只能走 xcodebuild
- `xcode-select` 指向 CommandLineTools 时 xcodebuild 会失败，需显式指到完整 Xcode（本机为 Xcode-beta）
- 改版本号只改 `Build.xcconfig` 的 `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION`，`CHANGELOG.md` 要同步；条目必须用 `## [X.Y.Z]` 格式，`release.sh` 靠这个格式的 awk 匹配抽取 Release Notes

## 发布流程（`release.sh`，本地专用）
clean → `xcodebuild` Release 构建 → 对 .app 做 **ad-hoc codesign**（脚本注释称为满足 Sparkle 运行时检查）→ create-dmg 打 DMG → ditto 打 Sparkle 用 ZIP → 用 Keychain 账户 `ed25519` 的 EdDSA 私钥跑 `generate_appcast` 签 appcast → git worktree 把 appcast.xml/zip 推到 `gh-pages` 分支 → `git tag -fa vX.Y.Z` **强制**推送 → `gh release create` 建 Release 并传 DMG/ZIP。重跑同版本会覆盖已存在的 tag 和 release。

## 开源仓库同步注意事项
- `release.sh` 本身在 `.gitignore`，**不会**出现在公开仓库里；`DEVELOPMENT.md` 的发布步骤是对它的转述，细节（比如 ad-hoc 签名）没写全
- `Local.xcconfig`（本地签名身份覆盖）同样 gitignore，新机器要自己建
- `gh-pages` 分支是公开的 Sparkle 更新源，直接 host `appcast.xml` 和各版本 `.zip`，改发布逻辑时要留意别把这条分支的历史搞乱
- `.github/assets/` 下的截图/图标是直接二进制提交进仓库的，不是 Release 产物

## 已知坑
- 2026-08-18 实测线上 v2.7.2 release DMG：`Signature=adhoc`、`TeamIdentifier=not set`、`spctl -a -t install` 为 `rejected`、未 staple——即只有 ad-hoc 签名、**没有公证**，与 README「经过代码签名和公证认证」的表述不符，仓库内也无 notarytool/staple 相关代码（是否在仓库外手动公证过待 James 确认；若否，普通用户双击 DMG 会被 Gatekeeper 拦）
- README「兼容旧版 macOS」指向的 `macos-13`/`macos-14` release tag 在 remote 已查不到（现存 tag 仅 `v2.0.0`–`v2.7.2`），链接可能失效
- 无 CI（`.github/` 里只有图片素材），发布完全靠本地手动跑 `release.sh`
- Sparkle EdDSA 私钥只在生成它的那台 Mac 的 Keychain 里（服务 `https://sparkle-project.org`，账户 `ed25519`），换机器要迁移或重新生成；重新生成必须同步改 `Info.plist` 的 `SUPublicEDKey` 并给所有存量用户重新发版
