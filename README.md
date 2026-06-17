# TokenIsland

TokenIsland 是 CC Switch 的配套菜单栏工具。在 macOS 菜单栏实时显示你的 token 用量、费用、模型分布和趋势图。

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange)

## 功能

- **实时 token 统计** — 今日输入/输出/缓存命中 token 数
- **费用追踪** — 实时费用估算
- **模型分布** — 按模型拆分用量和费用
- **趋势图** — 24h token 消耗曲线 + 7 天用量柱状图
- **类型占比** — New Input / Output / Cache Hit 饼图

## 前置依赖

- macOS 14.0 (Sonoma) 或更高
- [CC Switch](https://github.com/yuyunw/cc-switch) — TokenIsland 读的是 `~/.cc-switch/cc-switch.db`，没有 CC Switch 就没有数据

## 安装

### 方式一：下载 Release（推荐）

从 [Releases](https://github.com/yourname/TokenIsland/releases) 下载 `TokenIsland-v0.1.0-macOS.zip`，解压后拖进 `Applications` 文件夹。

首次打开 Gatekeeper 会拦截，**每个用户只需操作一次**：

```
右键 TokenIsland.app → 打开 → 弹窗中点"仍要打开"
```

或者终端执行：

```bash
xattr -cr /Applications/TokenIsland.app
```

之后正常双击即可。

### 方式二：从源码构建

需要 [Swift 6.0+](https://swift.org)：

```bash
git clone https://github.com/yourname/TokenIsland.git
cd TokenIsland
swift build -c release
bash scripts/install-app.sh
```

生成的 `TokenIsland.app` 在项目根目录，拖进 `Applications` 即可。

## 使用方法

1. 确保 CC Switch 正在运行（有数据库文件 `~/.cc-switch/cc-switch.db`）
2. 打开 TokenIsland
3. 菜单栏会出现图表图标 + 今日 token 数
4. 点击图标展开详情面板

面板支持：
- 点击日历切换日期，查看历史用量
- 鼠标悬停柱状图看具体数字

## 项目结构

```
├── Package.swift                 # Swift package 配置
├── scripts/
│   ├── install-app.sh            # 打包脚本：编译 + 复制二进制/图标/plist + ad-hoc 签名
│   └── make-icon.py              # 图标生成：程序化绘制玻璃质感图标 → .icns
├── Assets/
│   ├── Info.plist                # App 元数据（Bundle ID、LSUIElement、版本等）
│   ├── TokenIsland.icns          # 最终图标文件
│   ├── TokenIsland.iconset/      # iconutil 中间产物（自动生成）
│   └── TokenIslandIcon.svg       # 图标矢量源文件
├── Sources/TokenIsland/
│   ├── main.swift                # 入口
│   ├── AppDelegate.swift         # 菜单栏 app 生命周期 + 状态栏图标
│   ├── TokenPopoverView.swift    # 弹窗 UI（概览 + 柱状图 + 饼图）
│   ├── UsageStore.swift          # 数据层：SQLite 查询 + 定时刷新
│   ├── Models.swift              # 数据结构：Snapshot / HourlyPoint / ModelUsage 等
│   ├── Charts.swift              # 图表绘制（柱状图 + 饼图）
│   ├── Glass.swift               # 毛玻璃效果
│   └── Extensions.swift          # 扩展（Double 格式化等）
└── .gitignore
```

## 技术细节

- **纯 Swift + SwiftUI**，无第三方依赖
- **LSUIElement = true** — 菜单栏 app，不显示 Dock 图标
- **SQLite 查询** — 通过 `/usr/bin/sqlite3` 子进程读取 CC Switch 数据库
- **30s 自动刷新** — 定时拉取最新数据
- **ad-hoc 签名** — `codesign --sign -`，分发需用户绕 Gatekeeper

## 常见问题

**Q: 打开后菜单栏没有图标？**
A: 检查 `~/.cc-switch/cc-switch.db` 是否存在，确保 CC Switch 正常运行过。

**Q: 提示 "CC Switch database not found"？**
A: TokenIsland 不是独立工具，必须先安装并运行 CC Switch。

**Q: 双击打不开 / "无法验证开发者"？**
A: 见上方「安装」章节的 Gatekeeper 绕法。

**Q: 能不能上架 Mac App Store？**
A: 理论上可以，但需要改造沙箱适配（不能 exec sqlite3 子进程、不能用 App Group 共享数据库），目前先走 GitHub Releases 分发。

## License

MIT
