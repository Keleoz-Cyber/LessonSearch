# 设计系统手册

> 考勤助手 v0.7.0+ 设计系统（位于 `app/lib/shared/design_system/`）。所有新页面/组件必须使用本系统，不再使用 Material 3 默认值或裸 `Colors.*`。

## 目录结构

```
app/lib/shared/design_system/
├── tokens.dart         # 数值常量
├── colors.dart         # AppColors + BuildContext.colors 扩展
├── typography.dart     # AppTextStyles
├── theme.dart          # buildLightTheme() / buildDarkTheme()
└── widgets/
    ├── app_button.dart
    ├── app_card.dart
    ├── app_input.dart
    ├── app_top_bar.dart
    ├── bottom_action_bar.dart
    ├── progress_bar.dart        # SegmentedProgressBar + ProgressSegment
    ├── segmented_control.dart   # AppSegmentedControl + AppSegmentedItem
    ├── status_pill.dart
    └── sync_status_banner.dart
```

## 颜色（AppColors）

通过 `context.colors` 获取（自动按 Theme.brightness 选择亮/暗）。

| 类别 | 字段 | 亮色值 | 暗色值 | 用途 |
|---|---|---|---|---|
| 背景 | `bgCanvas` | #FAFAFA | #0A0A0B | 页面底色 |
| 背景 | `bgSurface` | #FFFFFF | #131316 | 卡片/对话框 |
| 背景 | `bgElevated` | #FFFFFF | #1A1A1F | 弹层 |
| 背景 | `bgMuted` | #F4F4F5 | #1C1C22 | 统计标签底/分割条 |
| 边框 | `borderSubtle` | #F0F0F1 | #232329 | 卡片内细分割 |
| 边框 | `borderDefault` | #E4E4E7 | #2E2E36 | 输入框边/按钮边 |
| 边框 | `borderStrong` | #D4D4D8 | #3F3F46 | 强调容器边 |
| 文本 | `textPrimary` | #18181B | #FAFAFA | 主文本 |
| 文本 | `textSecondary` | #52525B | #A1A1AA | 次文本/标签 |
| 文本 | `textTertiary` | #A1A1AA | #71717A | 提示/时间戳 |
| 文本 | `textDisabled` | #D4D4D8 | #52525B | 禁用态 |
| 品牌 | `brandPrimary` | #2563EB | #60A5FA | 主操作色 |
| 品牌 | `brandSubtle` | #DBEAFE | #1E3A8A20 | 品牌淡背景 |
| 品牌 | `brandGradientFrom` | #2563EB | #3B82F6 | 渐变起点 |
| 品牌 | `brandGradientTo` | #3B82F6 | #60A5FA | 渐变终点 |
| 品牌 | `onBrand` | #FFFFFF | #FFFFFF | 品牌色上的文字/图标 |
| 状态 | `stateSuccess` | #16A34A | #22C55E | 到课/通过/已发布 |
| 状态 | `stateWarning` | #EA580C | #F97316 | 待审核/迟到/未发布 |
| 状态 | `stateDanger` | #DC2626 | #EF4444 | 缺勤/拒绝/失败 |
| 状态 | `stateInfo` | #0EA5E9 | #38BDF8 | 请假/信息提示 |

> `c.brandGradient` 是 `LinearGradient(topLeft → bottomRight)`，可直接挂 `BoxDecoration.gradient`。

## Tokens

```dart
class AppSpacing {
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xl2 = 32, xl3 = 48;
}
class AppRadius {
  static const double sm = 4, normal = 6, md = 8, lg = 12, full = 999;
}
class AppDuration {
  static const Duration fast = Duration(milliseconds: 150);   // 触摸反馈
  static const Duration normal = Duration(milliseconds: 200); // 状态切换
  static const Duration slow = Duration(milliseconds: 300);   // 容器过渡
  static const Duration page = Duration(milliseconds: 450);   // 页面级
}
class AppCurves {
  static const Curve fast = Curves.easeOut;          // 入场
  static const Curve normal = Curves.easeInOut;      // 状态切换
  static const Curve emphasize = Curves.easeOutBack; // 强调（弹入）
  static const Curve depart = Curves.easeIn;         // 出场
}
class AppMinTouchSize { static const double width = 44, height = 44; }
```

**约定**：
- 按钮圆角 `AppRadius.normal = 6`
- 卡片圆角 `AppRadius.md = 8`
- 标签/胶囊圆角 `AppRadius.sm = 4` 或 `AppRadius.full`
- 按钮高 32/40/48（sm/md/lg）
- 卡片内默认 padding `AppSpacing.lg`

## 排版（AppTextStyles）

| 名称 | size/line/weight | 用途 |
|---|---|---|
| `display` | 28/36/w600 | 周次 hero |
| `h1` | 22/30/w600 | 大标题 |
| `h2` | 18/26/w600 | 对话框标题 |
| `h3` | 16/24/w600 | 卡片标题/section header |
| `body` | 14/22/w400 | 正文 |
| `bodyMedium` | 14/22/w500 | 卡片主文本 |
| `sm` | 13/20/w400 | 次要说明 |
| `xs` | 11/16/w500 | 时间戳/标签 |

数字、学号、时间戳统一用 `AppTextStyles.withTabular(style)` 套等宽数字特性。

## 组件 API 速查

### AppButton
```dart
enum AppButtonVariant { primary, secondary, ghost, gradient }
enum AppButtonSize { sm, md, lg }  // 高 32/40/48

AppButton.primary({label, onPressed, leadingIcon?, trailingIcon?, size=md, loading?, fullWidth?})
AppButton.secondary(...)
AppButton.ghost(...)
AppButton.gradient(...)  // 默认 size=lg
```
- `onPressed: null` 表示禁用
- `loading: true` 显示 CircularProgressIndicator 替换 leadingIcon

### AppCard
```dart
AppCard({child, padding=EdgeInsets.all(AppSpacing.lg), onTap?, selected=false})
```
- 有 `onTap` 自动包 InkWell
- `selected: true` → brandPrimary 边框 + brandSubtle 背景
- 亮色有轻阴影，暗色无阴影只有 1px 边框

### StatusPill
```dart
enum StatusPillVariant { success, warning, danger, info, neutral }

StatusPill({label, variant, icon?})
StatusPill.success({label, icon?})  // + warning/danger/info/neutral 5 个命名构造
```

### AppInput
```dart
AppInput({label?, hint?, errorText?, controller?, onChanged?, keyboardType?, obscureText=false, enabled=true, prefixIcon?, suffix?})
```

### AppTopBar（实现 PreferredSizeWidget）
```dart
AppTopBar({title, subtitle?, leading?, actions=const []})
// 高度：无副标 52，带副标 72
```
> 当前项目多数页面仍用普通 AppBar + `Scaffold.backgroundColor: c.bgCanvas`，AppTopBar 可选。

### BottomActionBar
```dart
BottomActionBar({hintText?, primary, secondary?})
// 自带 SafeArea + 顶边线
```

### AppSegmentedControl\<T\>
```dart
AppSegmentedControl({items: List<AppSegmentedItem<T>>, value: T, onChanged: ValueChanged<T>})
AppSegmentedItem({value: T, label: String})
```

### SyncStatusBanner
```dart
enum SyncBannerState { syncing, ready, failed, unknown }
SyncStatusBanner({state, title, description?, actionLabel?, onAction?})
```

### SegmentedProgressBar
```dart
SegmentedProgressBar({segments: List<ProgressSegment>, totalCount: int, height: 6})
ProgressSegment({value: int, color: Color})
```

## 公共 helper（design_system/widgets/）

### AppNoticeBox
```dart
AppNoticeBox({color, icon, title, body?})
// 彩色背景 + 左侧色条 + 图标 + 标题 + 可选正文
// 用于 rejected/cancelled/sync-warning/error 等通知块
```

### AppStatChip
```dart
AppStatChip({label, count, color, compact: false})
// compact=true 用于行内统计标签（如"应交 5"）
// 默认用于 dialog 内统计摘要
```

### AppStatTile
```dart
AppStatTile({label, count, color, icon?})
// 大方块统计磁贴（数字大字号 + 标签 + 可选图标）
// 用于"本周统计"三栏布局
```

## 调用模式

### 状态色映射
```dart
(StatusPillVariant, String) _statusVariant(String status) {
  switch (status) {
    case 'pending':   return (StatusPillVariant.warning, '待审核');
    case 'approved':  return (StatusPillVariant.success, '已通过');
    case 'rejected':  return (StatusPillVariant.danger, '已拒绝');
    case 'cancelled': return (StatusPillVariant.neutral, '已撤回');
    default:          return (StatusPillVariant.neutral, status);
  }
}

// 使用
final (variant, label) = _statusVariant(item['status']);
StatusPill(label: label, variant: variant);
```

### 出勤状态色
```dart
AttendanceStatus.present => c.stateSuccess;
AttendanceStatus.absent  => c.stateDanger;
AttendanceStatus.late_   => c.stateWarning;
AttendanceStatus.leave   => c.stateInfo;
AttendanceStatus.other   => c.brandPrimary;
AttendanceStatus.pending => c.textTertiary;
```

### 页面骨架
```dart
@override
Widget build(BuildContext context) {
  final c = context.colors;
  return Scaffold(
    backgroundColor: c.bgCanvas,
    appBar: AppBar(title: const Text('页面标题')),
    body: ...,
  );
}
```

## 动画约定

- 触摸反馈：`AppDuration.fast` + `AppCurves.fast`（150ms easeOut）
- 状态切换：`AppDuration.normal` + `AppCurves.normal`（200ms easeInOut）
- 容器过渡：`AppDuration.slow`（300ms）
- 强调弹入：`AppCurves.emphasize`（easeOutBack，慎用，过强会刺眼）
- 出场：`AppCurves.depart`（easeIn）
- 路由过渡：全局 `CupertinoPageTransitionsBuilder`（iOS 风格右滑入）
- 列表/详情共享元素：用 `Hero(tag: ...)` 包裹标题/头像

## 禁用清单

❌ 不再使用：
- `Card(` → 用 `AppCard`
- `Colors.red/orange/green/blue/grey/...` → 用 `c.state*` / `c.textTertiary` 等
- `FilledButton/ElevatedButton/OutlinedButton` 在主操作位置 → 用 `AppButton.*`
- 手写状态徽章 Container → 用 `StatusPill`
- `Theme.of(context).colorScheme.onSurfaceVariant` → 用 `c.textSecondary`
- `EdgeInsets.all(16)` 等魔数 → 用 `AppSpacing.*`

✅ 例外允许：
- `FilledButton` 在 dialog actions 内可保留（语义按钮）
- `Colors.white` 在 onBrand 语义上等价（但推荐 `c.onBrand`）
- `AppBar` 替代 AppTopBar 当前可接受（待全面迁移）

## 已删除的旧组件

- `shared/widgets/entry_card.dart`（EntryCard / FeatureCard）
- `shared/widgets/status_badge.dart`（StatusBadge / CountBadge）

## 保留的旧组件

- `shared/widgets/empty_state.dart` — 已迁移到设计系统，14 个工厂构造可直接用
- `shared/widgets/loading_overlay.dart` — 已迁移
- `shared/widgets/toast.dart` — 已迁移，仅 `Toast.show(context, message)` 一个 API
