# PureBar 开发文档

本文档记录 PureBar 项目的开发配置、发布流程和常见问题排查。

---

## 目录

- [项目结构](#项目结构)
- [版本配置](#版本配置)
- [Sparkle 自动更新](#sparkle-自动更新)
- [发布流程](#发布流程)
- [开发工具](#开发工具)
- [常见问题](#常见问题)

---

## 项目结构

```
PureBar/
├── PureBarMac/                 # 主应用目标
│   ├── Sources/
│   │   ├── Main/               # 主入口和控制器
│   │   ├── Views/              # UI 视图组件
│   │   ├── Managers/           # 业务管理器
│   │   ├── Updater/            # Sparkle 更新相关
│   │   └── Shared/             # 共享定义和设计常量
│   ├── Resources/              # 资源文件
│   ├── Modules/                # 本地 Swift Package
│   └── Info.plist              # 应用配置（含 Sparkle 配置）
├── PureBarKit/                 # 核心库 (Swift Package)
├── PureBarTools/               # 构建工具 (Swift Package)
├── Build.xcconfig              # 版本号和签名配置
├── Local.xcconfig              # 本地配置（可选，已 gitignore）
├── release.sh                  # 发布脚本（本地使用）
└── dist/                       # 发布产物目录（已 gitignore）
    └── updates/                # Sparkle 更新包
        ├── appcast.xml
        └── PureBar-x.x.x.zip
```

---

## 版本配置

### 配置文件位置

**`Build.xcconfig`**

```xcconfig
MARKETING_VERSION = 2.4.0       # 用户可见版本号 (CFBundleShortVersionString)
CURRENT_PROJECT_VERSION = 17    # 内部构建号 (CFBundleVersion)
```

### 版本号规则

- **主版本号 (Major)**: 重大功能变更或不兼容更新
- **中版本号 (Minor)**: 新功能或显著改进
- **修订号 (Patch)**: Bug 修复或小改进
- **构建号**: 每次发布递增

### 本地配置（可选）

创建 `Local.xcconfig` 文件可覆盖默认配置（已被 gitignore）：

```xcconfig
// Local.xcconfig - 本地开发配置
CODE_SIGN_IDENTITY = Apple Development
DEVELOPMENT_TEAM = YOUR_TEAM_ID
```

---

## Sparkle 自动更新

### 配置概览

| 配置项 | 位置 | 值 |
|--------|------|-----|
| **公钥 (SUPublicEDKey)** | `PureBarMac/Info.plist` | `m1PPbnGqoLz7uuN60prX627kNquJMznxQOHCXNtcqUQ=` |
| **Feed URL (SUFeedURL)** | `PureBarMac/Info.plist` | `https://tbxhs.github.io/PureBar/appcast.xml` |
| **私钥** | macOS Keychain | 账户名: `ed25519` |
| **Appcast 托管** | gh-pages 分支 | `appcast.xml` + `*.zip` |

### 私钥存储

Sparkle 的 EdDSA 私钥存储在 **macOS Keychain** 中：

- **服务 (Service)**: `https://sparkle-project.org`
- **账户 (Account)**: `ed25519`
- **描述**: `Private key for signing Sparkle updates`

**查看私钥是否存在：**
```bash
security dump-keychain 2>/dev/null | grep -A2 "sparkle-project"
```

**重要提示：**
- 私钥只能在创建它的 Mac 上使用
- 如果更换开发机器，需要导出/导入私钥或重新生成密钥对
- 重新生成密钥对需要同时更新 Info.plist 中的 SUPublicEDKey

### Info.plist 配置

```xml
<key>SUFeedURL</key>
<string>https://tbxhs.github.io/PureBar/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>m1PPbnGqoLz7uuN60prX627kNquJMznxQOHCXNtcqUQ=</string>
<key>SUEnableAutomaticChecks</key>
<true/>
```

### 生成 Appcast

使用 Sparkle 的 `generate_appcast` 工具（**运行时框架走 SPM**，与 brew 无关；这里只需要 CLI）：

```bash
# 本地构建后，工具一般在 SPM artifacts 里
SPARKLE_BIN=$(echo build/*/SourcePackages/artifacts/sparkle/Sparkle/bin | awk '{print $1}')

# 自动从 Keychain 读取私钥
"$SPARKLE_BIN/generate_appcast" \
    --account "ed25519" \
    -o dist/updates/appcast.xml \
    dist/updates

# 或指定私钥文件（CI 环境）
generate_appcast --ed-key-file /path/to/private-key -o appcast.xml ./updates
```

---

## 发布流程

### 完整发布步骤

1. **更新版本号** - 修改 `Build.xcconfig`
2. **更新 CHANGELOG.md** - 记录本次变更
3. **运行发布脚本** - `./release.sh`
4. **验证更新** - 打开旧版本应用检查更新

### release.sh 脚本流程

```
1. 关闭正在运行的 PureBar
2. 卸载已挂载的 DMG 卷
3. 清理并构建 Release 版本
4. 创建 DMG 安装包 (create-dmg)
5. 创建 ZIP 更新包 (用于 Sparkle)
6. 生成并签名 appcast.xml
7. 发布 appcast 到 gh-pages 分支
8. 创建 Git tag 并推送
9. 创建 GitHub Release（上传 DMG 和 ZIP）
```

### 手动发布（不使用脚本）

```bash
# 1. 构建 Release
xcodebuild -project PureBar.xcodeproj -scheme PureBarMac -configuration Release build

# 2. 创建 ZIP
ditto -c -k --sequesterRsrc --keepParent \
    "build/DerivedData/Build/Products/Release/PureBar.app" \
    "dist/updates/PureBar-2.4.0.zip"

# 3. 生成 appcast（优先用 SPM artifacts 里的 CLI）
SPARKLE_BIN=$(echo build/*/SourcePackages/artifacts/sparkle/Sparkle/bin | awk '{print $1}')
"$SPARKLE_BIN/generate_appcast" \
    --account "ed25519" \
    -o dist/updates/appcast.xml \
    dist/updates

# 4. 发布到 gh-pages
git worktree add -B gh-pages build/gh-pages origin/gh-pages
cp dist/updates/appcast.xml build/gh-pages/
cp dist/updates/*.zip build/gh-pages/
cd build/gh-pages && git add . && git commit -m "docs(appcast): 2.4.0" && git push
```

### GitHub Pages 配置

- **分支**: `gh-pages`
- **URL**: `https://tbxhs.github.io/PureBar/`
- **文件**:
  - `appcast.xml` - Sparkle 更新 feed
  - `PureBar-x.x.x.zip` - 各版本更新包

---

## 开发工具

### 运行测试

项目使用共享 scheme `PureBarMac`（含单元测试 target `PureBarMacTests`，宿主为应用本体）：

```bash
# 构建并运行测试
xcodebuild -project PureBar.xcodeproj -scheme PureBarMac test

# 仅构建
xcodebuild -project PureBar.xcodeproj -scheme PureBarMac -configuration Debug build
```

说明：
- 测试宿主 `TEST_HOST` 指向 `PureBar.app/Contents/MacOS/PureBar`，依赖 `PRODUCT_NAME = PureBar`
- 如果 `xcode-select` 指向 CommandLineTools，需要用 `DEVELOPER_DIR=/Applications/Xcode.app xcodebuild ...` 或先 `sudo xcode-select -s /Applications/Xcode.app`
- PureBarKit 的独立测试（`swift test`）在命令行下会被 SwiftLint 插件阻拦，请用上面的 xcodebuild 方式

### 必需工具

| 工具 | 用途 | 安装方式 |
|------|------|----------|
| **Xcode 16.0+** | 构建项目 | Mac App Store / Apple Developer |
| **Sparkle 框架** | App 内自动更新 | SPM（Xcode 自动解析，无需 brew） |
| **Sparkle CLI** | 生成/签名 appcast | 构建后自带，或从 [GitHub Releases](https://github.com/sparkle-project/Sparkle/releases) 下载（**不要**再装已弃用的 `brew install --cask sparkle`） |
| **create-dmg** | 创建 DMG 安装包 | `brew install create-dmg` |
| **gh (GitHub CLI)** | 创建 GitHub Release | `brew install gh` |

### Sparkle：框架 vs CLI（为什么 brew 里曾有 sparkle）

| 用途 | 来源 | 是否需要 brew |
|------|------|----------------|
| App 内 `import Sparkle` | SPM 依赖 | **否** |
| 发布用的 `generate_appcast` / `sign_update` | SPM artifacts 或官方 release 包 | **否**（brew cask 已因 Gatekeeper 弃用） |

历史上 `DEVELOPMENT.md` 写了 `brew install --cask sparkle`，所以本机装过这个 cask；它只是多装了一份 Test App + CLI，**和 SPM 框架重复**，还会触发 `brew doctor` 的 deprecated 警告。现已改为优先用构建产物里的 CLI。

### Sparkle CLI 位置

构建一次后通常在：
```
build/SourcePackages/artifacts/sparkle/Sparkle/bin/
# 或
build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/
├── generate_appcast    # 生成 appcast.xml
├── sign_update         # 单独签名更新包
└── generate_keys       # 生成新的密钥对
```

`release.sh` 会自动探测上述路径（也可用环境变量 `SPARKLE_BIN_DIR` 覆盖）。

### 验证工具安装

```bash
# 检查 Sparkle CLI（构建后）
ls build/*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast

# 检查 create-dmg
which create-dmg

# 检查 GitHub CLI
gh --version && gh auth status
```

---

## 常见问题

### Q: generate_appcast 提示找不到私钥

**症状**：
```
Error: Unable to find a valid signing key...
```

**解决方案**：
1. 检查 Keychain 中是否有私钥：
   ```bash
   security dump-keychain 2>/dev/null | grep -i sparkle
   ```
2. 如果没有，需要生成新的密钥对：
   ```bash
   build/*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys
   ```
3. 更新 `Info.plist` 中的 `SUPublicEDKey`

### Q: Sparkle 更新不工作

**检查清单**：
1. 确认 `appcast.xml` 已发布到 gh-pages
2. 确认 ZIP 文件已上传且路径正确
3. 检查 `SUFeedURL` 是否正确
4. 确认新版本号大于当前版本
5. 检查 appcast.xml 中的签名是否有效

**调试方式**：
```bash
# 查看 appcast.xml 内容
curl https://tbxhs.github.io/PureBar/appcast.xml

# 检查 ZIP 是否可下载
curl -I https://tbxhs.github.io/PureBar/PureBar-2.4.0.zip
```

### Q: release.sh 执行失败

**常见原因**：

1. **Tag 已存在** - 脚本会提示是否覆盖，输入 `y` 继续
2. **gh 未认证** - 运行 `gh auth login`
3. **Sparkle CLI 未找到** - 先本地 Release 构建一次，或从 [Sparkle Releases](https://github.com/sparkle-project/Sparkle/releases) 下载工具并设置 `SPARKLE_BIN_DIR`
4. **DMG 卷未卸载** - 手动卸载或重启 Finder

### Q: 如何在新机器上设置开发环境

1. 克隆仓库
2. 安装必需工具（见上方表格）
3. 从旧机器导出 Sparkle 私钥，或生成新密钥对
4. 如生成新密钥对，需更新 `SUPublicEDKey` 并重新发布所有用户的应用

### Q: 版本号应该如何递增

- **Bug 修复**: 2.4.0 → 2.4.1
- **新功能/改进**: 2.4.0 → 2.5.0
- **重大更新**: 2.4.0 → 3.0.0
- **构建号**: 每次发布必须递增

---

## 附录

### 相关链接

- [Sparkle 官方文档](https://sparkle-project.org/documentation/)
- [GitHub Pages 文档](https://docs.github.com/en/pages)
- [create-dmg 文档](https://github.com/create-dmg/create-dmg)

### 密钥备份提醒

Sparkle 私钥存储在 Keychain 中，建议定期备份：

```bash
# 导出私钥（需要手动从 Keychain Access 操作）
# 1. 打开 Keychain Access
# 2. 搜索 "sparkle"
# 3. 右键导出为 .p12 文件
# 4. 安全存储导出的文件
```

---

*最后更新: 2026-08-16*
