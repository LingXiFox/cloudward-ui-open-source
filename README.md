# 归云 Cloudward UI

归云是一个面向 macOS 的 iCloud 云盘空间整理工具。本仓库只开源页面设计层,用于展示 SwiftUI 视图结构、视觉 token、页面布局与交互稿。

## 开源范围

本仓库包含:

- `iCloudManageTool/Views`: 主要 SwiftUI 页面与组件
- `iCloudManageTool/DesignSystem`: 颜色与动效 token
- `iCloudManageTool/Assets.xcassets`: 应用图标与基础视觉资源

本仓库不包含:

- iCloud 文件索引、扫描、统计、释放算法
- 文件占用检测、进程检测、元数据监听
- `CloudwardCore`
- 生产 ViewModel、Services、测试夹具与私有工程配置

因此,这里的源码是 UI-only snapshot,不是完整可编译的产品源码。部分 View 中保留了对私有模型或核心模块的引用,仅用于说明页面接线位置。

## Beta 构建

Release 中的 `Cloudward-beta-2-macos.zip` 是当前 macOS beta 2 构建包,可用于试用现阶段界面与流程。该构建仍处于 prerelease 阶段,请先在非关键文件上试用。

Beta 2 重点:

- 修复 iCloud Drive 在 macOS 27 beta 上 Spotlight 元数据为空时首屏无内容的问题。
- 增加后台文件系统索引兜底,目录会回填真实本地大小与 iCloud 聚合状态。
- 增加索引/读取状态提示,避免界面只显示空表或长期“计算中”。
- 移除同步状态页中的深色模式缩略验证 demo。
- 优化释放后的涟漪反馈,避免仅云端行保留常驻动画源。

## 目录

```text
iCloudManageTool/
  Assets.xcassets/
  DesignSystem/
  Views/
```

## 许可

UI 设计层源码以 MIT License 开源。归云名称、图标与完整产品逻辑仍保留所有权利。
