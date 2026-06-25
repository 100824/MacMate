# MacMate

MacMate 是面向 macOS 的本地菜单栏助手，提供 Accessibility 划词工具、离线 IPA 与系统朗读、DeepSeek AI 翻译/解释，以及最近 10 条文本和图片剪贴板历史。

## 构建

```bash
./scripts/package_dmg.sh
```

构建产物为 `dist/MacMate-1.0.0-arm64.dmg`。首次运行需要在系统设置中授予“辅助功能”和“输入监控”权限。

## 隐私

API Key 仅存储在本地应用支持目录中的受限配置文件。日志不会记录划词正文、剪贴板内容、API Key、解释提示词或 AI 返回正文。诊断包不会自动上传。
