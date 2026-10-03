# Magic Mouse Flow

一款开源、轻量的 macOS 菜单栏工具，为 Apple 妙控鼠标补充“轻触点击”、双指缩放、轻触拖动等操作，并提供实时触点可视化与防误触设置。

[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)](https://www.apple.com/macos/)
[![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## 它能做什么

- 左侧单指轻触：左键点击
- 右侧单指轻触：右键单击
- 左侧轻触并停留：按住左键拖动
- 连续轻触两次：锁定左键保持按下；再次轻触释放
- 双指捏合/张开：向当前应用发送连续缩放事件
- 双指同时上下滑动：作为缩放的备用手势
- 实时显示妙控鼠标触点、估算接触力度和点击状态
- 可调节鼠标下半部、顶部中央区域及左右边缘的防误触范围
- 可按应用 Bundle ID 停用全部手势
- 可调节轻触阈值、拖动延迟、双击判定时间和缩放灵敏度

所有手势识别都在本机完成。应用是菜单栏程序，不需要账号。

## 系统要求

- macOS 13 Ventura 或更高版本
- Apple Magic Mouse（妙控鼠标）
- “辅助功能”和“输入监控”权限

## 安装

从仓库右侧的 [Releases](../../releases) 下载最新的 `Magic-Mouse-Flow-*.zip`，解压后将 **Magic Mouse Flow.app** 移入“应用程序”文件夹。

本项目暂未使用 Apple Developer ID 公证。首次打开时，如果 macOS 阻止运行，请在 Finder 中右键应用并选择“打开”，或前往“系统设置 → 隐私与安全性”确认打开。

首次启动后，请允许：

1. 系统设置 → 隐私与安全性 → 辅助功能
2. 系统设置 → 隐私与安全性 → 输入监控

授权后完全退出并重新打开应用。如果开关已经打开但应用仍显示“未授权”，请从两个权限列表中删除旧项目，再重新添加当前应用。

## 从源码构建

无需完整 Xcode，安装 Apple Command Line Tools 即可：

```bash
git clone https://github.com/lnevenn-pixel/Magic-Mouse-Flow.git
cd Magic-Mouse-Flow
chmod +x scripts/build-app.sh
./scripts/build-app.sh release
open "outputs/Magic Mouse Flow.app"
```

构建脚本会优先使用本机名为 `Magic Mouse Flow Local Signing` 的代码签名身份；找不到时自动使用 ad-hoc 签名。签名身份仅用于让本机权限记录在后续构建间保持稳定，项目不包含任何证书或私钥。

## 使用说明

启动后，应用会显示在 macOS 菜单栏。打开“设置”即可：

- 开关各项轻触、拖动和缩放手势
- 查看实时触点和估算力度
- 调整红色防误触区域
- 配置需要排除的应用 Bundle ID
- 查看辅助功能和输入监控授权状态

右侧轻触与左侧轻触按区域固定映射。左键按住拖动只会从左侧有效区域开始，右侧停留不会触发左键按住。

## 技术说明与限制

- 使用 Swift、AppKit、CoreGraphics 和少量 Objective-C 桥接实现。
- 妙控鼠标原始触控数据来自 Apple 私有的 `MultitouchSupport.framework`；macOS 更新后可能需要适配。
- 缩放通过 macOS magnification 事件发送，Safari、预览及多数设计软件可以响应，少数应用可能需要单独适配。
- 项目不适合提交 Mac App Store，因为商店审核通常不允许使用私有框架。
- 发布包未经 Apple Developer ID 公证，适合测试和自行构建使用。

## 隐私

Magic Mouse Flow 不包含账号系统、分析统计或网络上传功能。辅助功能和输入监控权限仅用于识别妙控鼠标触摸并生成用户启用的鼠标/缩放事件。

## 许可证

本项目采用 [MIT License](LICENSE) 开源。
