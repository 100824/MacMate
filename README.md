# MacMate

MacMate 是一个面向 macOS 的本地优先菜单栏助手，提供划词工具、系统翻译、本地读音、AI 解释和剪贴板历史。

## 功能

- 划词助手：通过 macOS Accessibility API 读取支持控件中的选中文字和选区位置。
- 翻译：优先使用系统本地翻译；结果页可手动触发 AI 翻译。
- 读音与发音辅助：使用 macOS 本地语音；英文 IPA 离线生成，中文支持拼音。
- AI 解释：支持 OpenAI-compatible Chat Completions，可配置 Base URL、API Key、模型名和解释提示词。
- 剪贴板管理：记录最近 10 条文本、富文本和图片历史，支持快捷键呼出和自动粘贴。
- 快捷键：划词助手和剪贴板面板均支持全局快捷键配置。
- 日志与诊断：仅本地保存，诊断包不会自动上传。

## 系统要求

- Apple Silicon Mac
- macOS 14 或更新版本
- 首次使用相关功能时需要手动授予 macOS 权限

## 构建

```bash
./scripts/run_tests.sh
./scripts/package_dmg.sh
```

构建产物为：

```text
dist/MacMate-1.0.0-arm64.dmg
dist/MacMate-1.0.0-arm64.dmg.sha256
```

本项目默认使用本机 ad-hoc 签名，不做 Apple 公证。

## GitHub Release

推送 `v*` 标签会触发 GitHub Actions 构建 DMG，并把以下文件上传到 GitHub Release：

- `MacMate-1.0.0-arm64.dmg`
- `MacMate-1.0.0-arm64.dmg.sha256`

示例：

```bash
git tag v1.0.0
git push origin v1.0.0
```

## 权限说明

MacMate 可能需要以下 macOS 权限：

- 辅助功能：读取选区文字/位置，以及剪贴板历史自动粘贴。
- 输入监控：监听全局 mouseUp、输入、点击、滚动和应用切换，用于控制划词浮标生命周期。

如果权限被拒绝，对应功能会降级或保持静默。

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

## 第三方资源

MacMate 内置 CMU Pronouncing Dictionary 用于离线英文发音标注。许可证见：

```text
Sources/MacMate/Resources/Pronunciation/CMUdict-LICENSE.txt
```

也可查看 [NOTICE](NOTICE)。

## License

MIT. See [LICENSE](LICENSE).
