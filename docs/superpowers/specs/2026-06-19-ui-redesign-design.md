# 考勤助手 UI 重设计 — 设计方案

**日期**: 2026-06-19
**版本目标**: v0.7.0 / v0.8.0
**状态**: 待实施

---

## 1. 背景与目标

考勤助手当前 UI（v0.6.5+29）使用 Flutter Material 3 默认主题（`colorSchemeSeed: Colors.blue`），所有页面遵循标准 M3 模板风格。在产品已上线、业务稳定的前提下，希望通过设计升级提升以下方面：

- 视觉一致性与品牌识别度
- 信息密度与高频操作效率
- 明/暗主题的对比度与舒适度
- 专业商业 SaaS 工具的"高级感"

### 设计原则

1. **工具优先**：信息密度 > 装饰，识别速度 > 视觉冲击
2. **克制配色**：中性灰为主，品牌色仅在关键动作、焦点、状态指示上出现
3. **可访问性**：文本对比度 ≥ 4.5:1，关键操作触控区 ≥ 44pt
4. **零回归**：不破坏现有信息层级与已上线用户的肌肉记忆

### 范围

**本期（一次性走完）**

- 设计系统骨架：色彩、字体、间距、圆角、阴影、动效
- 核心组件：按钮、卡片、状态标签、输入框、空/错/加载状态、顶栏、底部操作栏
- 4 个核心页面重做：首页、记名、提交、记录详情

**本期不动**：登录/注册/实名、FAQ、设置、调试、点名、确认、文本生成、周汇总、排行榜（保留 M3 默认风格，新设计系统的 token 自动作用其上，但不重排版）

---

## 2. 设计系统（Design Tokens）

### 2.1 色彩

**亮色主题 (light)**

| 用途 | 值 | 备注 |
|---|---|---|
| `bg.canvas` | `#FAFAFA` | 全局背景，灯灰 |
| `bg.surface` | `#FFFFFF` | 卡片、面板 |
| `bg.elevated` | `#FFFFFF` | 弹窗、菜单 |
| `bg.muted` | `#F4F4F5` | 输入框、disabled 背景 |
| `border.subtle` | `#E4E4E7` | 默认边框 |
| `border.default` | `#D4D4D8` | hover、focus 前的边框 |
| `border.strong` | `#A1A1AA` | 选中边框 |
| `text.primary` | `#18181B` | 主标题、正文 |
| `text.secondary` | `#52525B` | 次要文字 |
| `text.tertiary` | `#71717A` | 辅助说明 |
| `text.disabled` | `#A1A1AA` | 禁用 |
| `brand.primary` | `#2563EB` | blue-600，主品牌色 |
| `brand.gradient.from` | `#38BDF8` | sky-400，渐变起点 |
| `brand.gradient.to` | `#2563EB` | blue-600，渐变终点 |
| `brand.subtle` | `#EFF6FF` | 浅色品牌背景（选中态、聚焦态） |
| `state.success` | `#059669` | emerald-600 |
| `state.warning` | `#D97706` | amber-600 |
| `state.danger` | `#DC2626` | red-600 |
| `state.info` | `#0EA5E9` | sky-500 |

**暗色主题 (dark)**

| 用途 | 值 | 备注 |
|---|---|---|
| `bg.canvas` | `#0A0A0B` | 深炭，非纯黑 |
| `bg.surface` | `#18181B` | 卡片 |
| `bg.elevated` | `#27272A` | 弹窗 |
| `bg.muted` | `#27272A` | 输入框 |
| `border.subtle` | `#27272A` | 默认边框 |
| `border.default` | `#3F3F46` | hover、focus 前 |
| `border.strong` | `#52525B` | 选中边框 |
| `text.primary` | `#FAFAFA` | 主文 |
| `text.secondary` | `#A1A1AA` | 次文 |
| `text.tertiary` | `#71717A` | 辅助 |
| `text.disabled` | `#52525B` | 禁用 |
| `brand.primary` | `#60A5FA` | blue-400，暗模式下的品牌色 |
| `brand.gradient.from` | `#7DD3FC` | sky-300 |
| `brand.gradient.to` | `#60A5FA` | blue-400 |
| `brand.subtle` | `#1E3A8A` | blue-900 alpha 30% 模拟 |
| `state.success` | `#10B981` | emerald-500，亮一档 |
| `state.warning` | `#F59E0B` | amber-500 |
| `state.danger` | `#EF4444` | red-500 |
| `state.info` | `#38BDF8` | sky-400 |

**渐变使用规则**

- 仅出现在：首页主 CTA 按钮、Hero 顶部装饰、记名页"到课"主按钮（可选）
- 角度：135°（左上 → 右下）
- 不应出现在：卡片背景、列表项背景、状态标签

### 2.2 字体

- **西文/数字**: 系统默认（iOS: SF Pro / Android: Roboto）
- **中文 fallback**: PingFang SC, Source Han Sans, Noto Sans SC, sans-serif
- **数字等宽**: 学号、数字栏、时间戳使用 `fontFeatures: [FontFeature.tabularFigures()]`

| 名称 | 字号 | 行高 | weight | 用途 |
|---|---|---|---|---|
| `display` | 28 | 36 | 600 | 首页 hero 标题 |
| `h1` | 22 | 30 | 600 | 页面主标题 |
| `h2` | 18 | 26 | 600 | 卡片标题、对话框标题 |
| `h3` | 16 | 24 | 600 | 分组标题 |
| `body` | 14 | 22 | 400 | 正文（默认） |
| `body.medium` | 14 | 22 | 500 | 强调正文 |
| `sm` | 13 | 20 | 400 | 副文、说明 |
| `xs` | 11 | 16 | 500 | 标签、徽章、时间戳 |

### 2.3 间距（4 px 基准）

| token | px | 用途 |
|---|---|---|
| `xs` | 4 | 图标与文字间隔 |
| `sm` | 8 | 紧凑列表项内边距 |
| `md` | 12 | 卡片内边距（紧凑） |
| `lg` | 16 | 卡片内边距（默认）、页面边距 |
| `xl` | 24 | 区块间距 |
| `2xl` | 32 | 大区块间距 |
| `3xl` | 48 | hero 区垂直留白 |

### 2.4 圆角

| token | px | 用途 |
|---|---|---|
| `none` | 0 | 分割线 |
| `sm` | 4 | 标签、徽章 |
| `default` | 6 | 按钮、输入框、小卡片 |
| `md` | 8 | 卡片、对话框 |
| `lg` | 12 | 大卡片、Hero |
| `full` | 999 | 头像、胶囊 |

> 不使用 M3 默认的 12 px 卡片圆角，6/8 px 更锐利、更专业。

### 2.5 阴影 / 描边

亮色：

```dart
// shadow.sm
BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))
// shadow.md
BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))
```

**暗色不用阴影**，用 1 px 边框区分层级（这是 Linear/Vercel 的处理方式）。

### 2.6 动效

| 用途 | 时长 | 缓动 |
|---|---|---|
| 状态切换（颜色、透明度） | 150 ms | `Curves.easeOut` |
| 元素位移、尺寸变化 | 200 ms | `Curves.easeInOut` |
| 页面切换（GoRouter 默认） | 300 ms | 系统 |
| 触觉反馈 | 即时 | 复用 `feedbackServiceProvider` |

不使用：弹簧、过度回弹、≥ 400 ms 的动画。

---

## 3. 核心组件规格

> 所有组件放在 `app/lib/shared/design_system/`，按 `tokens.dart` / `colors.dart` / `typography.dart` / `widgets/` 组织。

### 3.1 AppButton

3 种 variant + size = 9 形态，外加渐变变体（`AppButton.gradient`）：

```dart
AppButton.primary(label: '到课', onPressed: ...)
AppButton.secondary(label: '取消', onPressed: ...)
AppButton.ghost(label: '了解', onPressed: ...)
AppButton.gradient(label: '开始记名', onPressed: ...)
```

| size | height | padding-x | font |
|---|---|---|---|
| `sm` | 32 | 12 | 13/500 |
| `md` | 40 | 16 | 14/500 |
| `lg` | 48 | 20 | 15/600 |

### 3.2 AppCard

- 默认 `bg.surface` + 1 px `border.subtle` + radius 8 px + shadow.sm（亮）/ 仅边框（暗）
- hover/press：边框 `border.default`，shadow.md
- selected：边框 `brand.primary`，背景 `brand.subtle`

### 3.3 StatusPill（状态胶囊）

替代当前 `StatusBadge`，5 种状态：success / warning / danger / info / neutral

- 高度 22 px，padding 8/4，radius 4 px
- 背景 = state 色 alpha 12%，文字 = state 色（满色），无边框
- 文字 11/500

### 3.4 AppInput

- 高度 40 px，radius 6，1 px 边框
- focus：品牌色边框，**无 ring**（M3 默认 ring 太重）
- error：danger 色边框 + 下方 13/400 错误文字
- 上方独立 label（13/500），不用 floating

### 3.5 EmptyState（保 API 兼容，重做视觉）

- 居中布局，最大宽度 320 px，垂直 16 间距
- icon 32×32，颜色 `text.tertiary`
- title h2，description body @ secondary
- 行动按钮可选（AppButton.primary md）

### 3.6 SegmentedControl

替代 TabBar 与 ChoiceChip：

- 整体 1 px 边框 + radius 6
- 选中段：`bg.surface` + shadow.sm + 主文
- 未选中段：透明 + secondary 文字
- 高度 36 px，每段最小宽度 80 px

### 3.7 AppTopBar

- 高度 52 px（替代 M3 默认 56）
- 标题 h1，左对齐
- 右侧 actions 用 ghost 按钮，间距 8

### 3.8 BottomActionBar

- 顶部 1 px `border.subtle`
- padding 16/12 + safe area
- 主操作 lg，副操作 md
- 暗模式仅 surface + 边框；亮模式 surface + 向上 shadow.md

### 3.9 SyncStatusBanner（新增）

提交页 / 记录详情页统一使用：

- 4 种状态：syncing / ready / failed / unknown
- 紧凑卡片：左 16×16 图标 + 14/500 标题 + 13/400 描述 + 右侧 ghost 按钮
- 高度 56 px，颜色随状态变化


---

## 4. 4 个核心页改造方案

### 4.1 首页 `home_page.dart`

**当前问题**：所有入口扁平排列看不出主次；缺少全局状态可视化（待提交、是否同步）。

**新版结构**：

```
┌──────────────────────────────────────┐
│  考勤助手                       ●3   │ ← AppTopBar + 同步状态点
│  第 12 周 · 计算机学院 23 级         │
├──────────────────────────────────────┤
│                                      │
│  [开始记名 (gradient)]  [开始点名]   │ ← 主操作（70/30）
│                                      │
├──────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐ │
│  │ 名单提交  3  │  │ 周汇总       │ │
│  │ 待提交       │  │ 第 12 周     │ │
│  └──────────────┘  └──────────────┘ │ ← 次入口 2×2
│  ┌──────────────┐  ┌──────────────┐ │
│  │ 查课记录 142 │  │ 排行榜       │ │
│  │ 累计         │  │ 近 7 天      │ │
│  └──────────────┘  └──────────────┘ │
├──────────────────────────────────────┤
│  📢 v0.7.0 已发布，点击查看          │ ← 公告（可关闭）
└──────────────────────────────────────┘
```

**关键改造**：

- 新增 hero 区：当前周 + 用户身份
- 主操作 = 渐变按钮（视觉锚点）
- 次入口卡片显示**核心数字**而不仅仅是图标
- 同步状态用顶栏右侧小圆点 + 数字角标

### 4.2 记名页 `name_check_page.dart`

**当前问题**：进度只有 "12/30" 看不出异常分布；学生卡片状态颜色撞色严重；焦点不够明显。

**新版结构**：

```
┌──────────────────────────────────────┐
│  ← 计算机 23-1                  ⋮    │
│  ▓▓▓▓▓▓▓▓░░ 12/30                    │ ← 分段彩色进度条
├──────────────────────────────────────┤
│  [23-1] [23-2] [23-3]                │ ← SegmentedControl
├──────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐ │
│  │ 王小明     到│  │ 李四     缺  │ │
│  │ 23010101     │  │ 23010102     │ │
│  └──────────────┘  └──────────────┘ │
│  ┌──────────────┐  ┌──────────────┐ │
│  │ 张三 (focus) │  │ ...          │ │ ← 焦点 brand 边框 + brand.subtle
│  │ 23010103     │  │              │ │
│  └──────────────┘  └──────────────┘ │
├──────────────────────────────────────┤
│  正在标记：张三                      │
│  [缺] [迟] [假] [他]   [   到课   ]  │
└──────────────────────────────────────┘
```

**关键改造**：

- 顶部分段彩色进度条（绿/红/黄/蓝/紫/灰）
- 班级切换：ChoiceChip → SegmentedControl
- 学生卡片：状态用右上角 StatusPill（替代纯背景色变化）
- 焦点态：1.5 px brand 边框 + brand.subtle 背景
- 底部加学生姓名预览，避免误标
- "到课"主按钮 60% 宽，4 个状态按钮 40%

### 4.3 提交页 `submission_page.dart`

**当前问题**：状态卡片、Tab、列表、说明文字交错；任务卡片信息密度低。

**新版结构**：

```
┌──────────────────────────────────────┐
│  名单提交                            │
├──────────────────────────────────────┤
│  ┌──────────────────────────────────┐│
│  │ ✓ 已就绪，可以提交               ││ ← SyncStatusBanner
│  └──────────────────────────────────┘│
│                                      │
│  [提交任务]  [我的提交]              │ ← SegmentedControl
│                                      │
│  本周记名任务 (3)                    │
│                                      │
│  ┌──────────────────────────────────┐│
│  │ ☑  计算机 23-1 · 23-2            ││
│  │    今天 14:30 · 60 条 · 3 异常 🔴││
│  │    3 缺勤 · 1 请假               ││
│  └──────────────────────────────────┘│
│  ┌──────────────────────────────────┐│
│  │ ☐  计算机 23-3                   ││
│  │    昨天 09:00 · 30 条 · 全到齐 ✓ ││
│  └──────────────────────────────────┘│
├──────────────────────────────────────┤
│  已选 1 个任务，共 60 条记录         │
│  [          确认提交          ]      │
└──────────────────────────────────────┘
```

**关键改造**：

- 顶部 SyncStatusBanner 替代多个分散横幅
- Tab → SegmentedControl
- 任务卡片密度提升 3 倍：班级 + 时间 + 总数 + 异常徽章 + 异常详情
- 全到齐时绿色 ✓，异常时红色徽章
- 底部固定 BottomActionBar

### 4.4 记录详情页 `record_detail_page.dart`

**当前问题**：多个状态横幅占顶部；统计与名单分离；编辑入口不明显。

**新版结构**：

```
┌──────────────────────────────────────┐
│  ← 记名详情                  [编辑]  │
├──────────────────────────────────────┤
│  ┌──────────────────────────────────┐│
│  │ 计算机 23-1 · 23-2               ││
│  │ 2026-06-18 14:30        [草稿]   ││
│  │                                  ││
│  │ ▓▓▓▓▓▓▓░░░ 60 人                 ││ ← 5 段统计条
│  │ 56 到 · 3 缺 · 1 假              ││
│  └──────────────────────────────────┘│
│                                      │
│  异常记录 (4)                        │
│  ┌──────────────────────────────────┐│
│  │ ▮ 王小明                  [缺勤] ││ ← 左色条 + StatusPill
│  │   23010101 · 23-1                ││
│  └──────────────────────────────────┘│
│  ┌──────────────────────────────────┐│
│  │ ▮ 李四                    [请假] ││
│  │   23010102 · 23-1 · 备注：感冒   ││
│  └──────────────────────────────────┘│
│                                      │
│  ▼ 已到 (56)                         │ ← 默认折叠
└──────────────────────────────────────┘
```

**关键改造**：

- 顶部信息卡：班级 / 时间 / 状态（StatusPill）+ 5 段统计条
- 多个分散横幅整合为信息卡上的状态标签
- "已到"默认折叠，突出异常
- 异常学生：左 3 px 色条 + 右侧 StatusPill
- 编辑模式入口移到顶栏右侧
- 同步状态未知/失败时使用 SyncStatusBanner（在信息卡上方）


---

## 5. 文件结构与实施顺序

### 5.1 新增目录

```
app/lib/shared/design_system/
├── tokens.dart              # 间距 / 圆角 / 时长 等数值常量
├── colors.dart              # AppColors（亮 + 暗，从 Theme.of 取）
├── typography.dart          # AppTextStyles（display, h1, h2, body, sm, xs）
├── theme.dart               # buildLightTheme() / buildDarkTheme()
└── widgets/
    ├── app_button.dart
    ├── app_card.dart
    ├── status_pill.dart
    ├── app_input.dart
    ├── app_top_bar.dart
    ├── bottom_action_bar.dart
    ├── segmented_control.dart
    ├── sync_status_banner.dart
    └── progress_bar.dart    # 5 段彩色进度条
```

### 5.2 改造已有文件

| 文件 | 操作 |
|---|---|
| `app/lib/app.dart` | `ThemeData` 改用 `buildLightTheme()` / `buildDarkTheme()` |
| `app/lib/shared/widgets/empty_state.dart` | 视觉重做，API 兼容 |
| `app/lib/shared/widgets/status_badge.dart` | **保留**（旧调用兼容），新代码用 `StatusPill` |
| `app/lib/shared/widgets/toast.dart` | 视觉微调（圆角、阴影） |
| `app/lib/features/home/presentation/home_page.dart` | 重写 |
| `app/lib/features/attendance/presentation/name_check/name_check_page.dart` | 重写 |
| `app/lib/features/extension/presentation/submission_page.dart` | 重写第一个 Tab + 顶部状态卡，第二个 Tab 仅替换组件 |
| `app/lib/features/records/presentation/record_detail_page.dart` | 重写 |

### 5.3 不动的文件

- 登录、注册、实名页：保留 M3 默认（仅承袭新 token）
- 设置、FAQ、调试页：保留
- 点名页、确认页、文本生成页：保留
- 周汇总、提交搜索、排行榜：保留

### 5.4 实施顺序

| 阶段 | 内容 | 估时 |
|---|---|---|
| **阶段 1** | tokens / colors / typography / theme | 30 min |
| **阶段 2** | AppButton / AppCard / StatusPill / SegmentedControl | 60 min |
| **阶段 3** | AppTopBar / BottomActionBar / SyncStatusBanner / ProgressBar / EmptyState | 60 min |
| **阶段 4** | 首页重写 | 60 min |
| **阶段 5** | 记名页重写 | 90 min |
| **阶段 6** | 提交页重写 | 90 min |
| **阶段 7** | 记录详情页重写 | 90 min |
| **阶段 8** | 联调、暗模式核对、回归测试 | 60 min |

总计约 9 小时连续工作。

---

## 6. 风险与回滚

### 6.1 风险

1. **回归风险**：4 个核心页 + 设计系统组件影响面大，可能引入交互细节回归
2. **暗模式漏配**：旧代码大量 `Colors.red.withOpacity(0.1)` 这种硬编码颜色，暗模式可能视觉违和
3. **用户肌肉记忆**：已上线用户对当前布局熟悉，结构调整需要 1-2 周适应期
4. **状态色冲突**：新设计系统中"绿色 = success"与原有"绿色 = 已到"语义统一，无冲突；但提交状态的"已通过 = 绿色"与"已到 = 绿色"在同一界面要小心区分

### 6.2 回滚方案

- 每个页面改造作为独立 commit，失败时 `git revert` 单个 commit
- 旧组件（StatusBadge）保留，不删除，确保未改造页面不受影响
- ThemeData 切换有开关：调试页可切回 `colorSchemeSeed: Colors.blue` 旧主题（作为 hotfix 兜底）

### 6.3 兼容性

- 不破坏已有 Notifier / Repository / 路由层接口
- 不修改业务逻辑（Bug 修复在 v0.7.0 已完成，本次是纯视觉/交互层）
- 跨版本 SharedPreferences key 兼容

---

## 7. 验收标准

1. **视觉**
   - [ ] 4 个核心页与设计稿匹配（亮 + 暗）
   - [ ] 所有按钮、卡片、状态标签使用新组件
   - [ ] 文本对比度 ≥ 4.5:1（用浏览器/Material Designer 工具测）
   - [ ] 触控区 ≥ 44pt
2. **功能**
   - [ ] 现有所有交互无回归（标记、提交、编辑、撤回...）
   - [ ] 同步状态、错误提示、加载状态正确显示
   - [ ] 暗模式下所有页面无视觉违和
3. **代码质量**
   - [ ] `flutter analyze` 不引入新 error
   - [ ] 已有单元测试全部通过
   - [ ] 新增 widget 测试覆盖 AppButton / StatusPill / SyncStatusBanner

---

## 8. 后续（不在本期内）

- 登录/注册/实名页对齐设计系统
- 点名页、确认页、文本生成页对齐
- 设置页、FAQ 页对齐
- 周汇总、排行榜对齐（信息密度更高的页面，需要单独设计）
- 增加 widget 库的 storybook（可选）

