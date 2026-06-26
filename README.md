<p align="center">
  <img src="Sources/MacMate/Resources/Icons/MacMate.png" width="128" height="128" alt="MacMate app icon">
</p>

<h1 align="center">MacMate</h1>

<p align="center">
  一只住在菜单栏里的红耳鹎助手：划词、翻译、读音、AI 解释和剪贴板历史。
</p>

<p align="center">
  <a href="https://github.com/100824/MacMate/releases/latest">下载最新版</a>
  ·
  <a href="https://github.com/100824/MacMate/releases/download/v1.0.0/MacMate-1.0.0-arm64.dmg">直接下载 DMG</a>
  ·
  <a href="PRIVACY.md">隐私说明</a>
</p>

## 下载与安装

当前版本：

- 下载页面：[GitHub Releases](https://github.com/100824/MacMate/releases/latest)
- DMG 安装包：[MacMate-1.0.0-arm64.dmg](https://github.com/100824/MacMate/releases/download/v1.0.0/MacMate-1.0.0-arm64.dmg)
- 校验文件：[MacMate-1.0.0-arm64.dmg.sha256](https://github.com/100824/MacMate/releases/download/v1.0.0/MacMate-1.0.0-arm64.dmg.sha256)

安装方式：

1. 下载并打开 DMG。
2. 将 `MacMate.app` 拖入 `Applications`。
3. 首次启动时，如果 macOS 提示应用未公证，请在 Finder 中右键点击 MacMate 并选择“打开”。
4. 根据需要在系统设置中授予“辅助功能”和“输入监控”权限。

> MacMate 目前使用 ad-hoc 签名，没有做 Apple 公证；这是为了方便本地和开源分发。

## 它能做什么

- 划词助手：在支持 Accessibility API 的 App 中选择文字后显示轻量浮标。
- 翻译：优先使用系统本地翻译；结果页可手动触发 AI 翻译。
- 读音与发音辅助：使用 macOS 本地语音；英文 IPA 离线生成，中文支持拼音。
- AI 解释：支持 OpenAI-compatible Chat Completions，可配置 Base URL、API Key、模型名和解释提示词。
- 剪贴板管理：记录最近 10 条文本、富文本和图片历史，支持快捷键呼出和自动粘贴。
- 快捷键：划词助手和剪贴板面板均支持全局快捷键配置。
- 日志与诊断：仅本地保存，诊断包不会自动上传。

## 红耳鹎图标设计

<p align="center">
  <img src="Sources/MacMate/Resources/Icons/MacMate.png" width="160" height="160" alt="MacMate app icon">
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="Sources/MacMate/Resources/Icons/MenuBarIcon.png" width="48" height="48" alt="MacMate menu bar icon">
</p>

MacMate 的视觉元素来自红耳鹎：黑色冠羽、白色脸颊、红色耳斑和轻巧的鸟喙。它看起来有一点机灵，也有一点“随时准备帮你叼来答案”的感觉。

图标分为两套：

- App 图标：保留完整红耳鹎头像，并在右下角加入鼠标指针，表达“划词选择”和“桌面助手”的核心功能。
- 菜单栏图标：去掉复杂细节，只保留红耳鹎的轮廓和眼睛，让它在 macOS 顶部状态栏里足够简洁、清晰。

## 系统要求

- Apple Silicon Mac
- macOS 14 或更新版本
- 首次使用相关功能时需要手动授予 macOS 权限

## 权限说明

MacMate 可能需要以下 macOS 权限：

- 辅助功能：读取选区文字/位置，以及剪贴板历史自动粘贴。
- 输入监控：监听全局 mouseUp、输入、点击、滚动和应用切换，用于控制划词浮标生命周期。

如果权限被拒绝，对应功能会降级或保持静默。例如：无法读取选中文字时不会显示浮标。

## AI 配置

MacMate 不内置 API Key。你需要在设置里配置：

- Base URL
- API Key
- 模型名
- 解释提示词

支持 HTTPS，以及 `localhost` / `127.0.0.1` 的本地 HTTP 服务。

## 隐私

MacMate 默认本地优先。日志不会记录划词正文、剪贴板内容、API Key、解释提示词或 AI 返回正文。诊断包只保存在本机，不会自动上传。

更多细节见 [PRIVACY.md](PRIVACY.md)。

## 从源码构建

```bash
./scripts/run_tests.sh
./scripts/package_dmg.sh
```

构建产物为：

```text
dist/MacMate-1.0.0-arm64.dmg
dist/MacMate-1.0.0-arm64.dmg.sha256
```

推送 `v*` 标签会触发 GitHub Actions 构建 DMG，并把安装包上传到 GitHub Release。

## 第三方资源

MacMate 内置 CMU Pronouncing Dictionary 用于离线英文发音标注。许可证见：

```text
Sources/MacMate/Resources/Pronunciation/CMUdict-LICENSE.txt
```

也可查看 [NOTICE](NOTICE)。

## License

MIT. See [LICENSE](LICENSE).
