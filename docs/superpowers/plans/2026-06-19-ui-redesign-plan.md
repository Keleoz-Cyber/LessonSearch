# UI 重设计 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把考勤助手 UI 从 Material 3 默认风格升级到 Linear/SaaS 风（中性灰 + sky→blue 渐变），覆盖设计系统骨架与 4 个核心页面，不破坏已上线业务逻辑。

**Architecture:** 在 `app/lib/shared/design_system/` 下建立新设计系统目录，提供 design tokens（颜色/字号/间距/圆角/阴影/动效）、主题构建器（亮/暗）、9 个核心组件（按钮/卡片/状态胶囊/输入/顶栏/底操作栏/分段控件/同步状态条/进度条）。旧组件 `EntryCard` / `StatusBadge` / `EmptyState` / `LoadingOverlay` / `Toast` 保留以兼容未改造页面，新代码统一使用新组件。4 个核心页（首页 / 记名 / 提交 / 记录详情）逐页替换。

**Tech Stack:** Flutter 3.43 / Dart ^3.11 / Material 3 / flutter_riverpod 2.6 / go_router 14.8（不引入新依赖）

**Reference Spec:** `docs/superpowers/specs/2026-06-19-ui-redesign-design.md`

---

## 文件结构

### 新增

```
app/lib/shared/design_system/
├── tokens.dart                 # 数值常量：spacing/radius/duration/curves
├── colors.dart                 # AppColors（亮+暗，BuildContext 扩展）
├── typography.dart             # AppTextStyles
├── theme.dart                  # buildLightTheme()/buildDarkTheme()
└── widgets/
    ├── app_button.dart         # AppButton（primary/secondary/ghost/gradient × sm/md/lg）
    ├── app_card.dart           # AppCard（边框 + 阴影 + selected 态）
    ├── status_pill.dart        # StatusPill（success/warning/danger/info/neutral）
    ├── app_input.dart          # AppInput（带 label，无 ring）
    ├── app_top_bar.dart        # AppTopBar（52px，左标题+右 actions）
    ├── bottom_action_bar.dart  # BottomActionBar（固定底部，主+副）
    ├── segmented_control.dart  # AppSegmentedControl（替代 TabBar/ChoiceChip）
    ├── sync_status_banner.dart # SyncStatusBanner（4 状态）
    └── progress_bar.dart       # SegmentedProgressBar（5 段彩色条）
```

### 改造

| 文件 | 操作 |
|---|---|
| `app/lib/app.dart` | 改用 `buildLightTheme()` / `buildDarkTheme()` |
| `app/lib/shared/widgets/empty_state.dart` | 视觉重做，API 兼容 |
| `app/lib/shared/widgets/loading_overlay.dart` | 视觉微调 |
| `app/lib/shared/widgets/toast.dart` | 视觉微调（圆角、阴影） |
| `app/lib/features/home/presentation/home_page.dart` | 重写（保留所有现有入口和逻辑） |
| `app/lib/features/attendance/presentation/name_check/name_check_page.dart` | 重写 build/_buildBottomBar/_StudentCard |
| `app/lib/features/extension/presentation/submission_page.dart` | 重写第一个 Tab + 顶部状态卡 |
| `app/lib/features/records/presentation/record_detail_page.dart` | 重写 build |

### 不动

- `entry_card.dart`、`status_badge.dart`：保留（旧页面仍在用）
- 登录、注册、实名、设置、FAQ、调试、点名、确认、文本生成、周汇总、提交搜索、排行榜：保留
- 业务逻辑层（Notifier / Repository / Service）：完全不动

---

## 通用约定

- 所有命令在 `app/` 目录下执行（除非另注）
- 每个 Task 完成后必跑：`flutter analyze` 不能引入新 error
- Dart 代码风格：不加非业务注释，与现有代码风格一致（不使用 emoji）
- 引用旧组件以验证兼容性：`flutter test` 必须保持通过

---

## Task 1: design_system tokens（间距/圆角/时长/缓动）

**Files:**
- Create: `app/lib/shared/design_system/tokens.dart`

- [ ] **Step 1.1: 创建 tokens.dart**

```dart
import "package:flutter/material.dart";

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xl2 = 32;
  static const double xl3 = 48;
}

class AppRadius {
  static const double none = 0;
  static const double sm = 4;
  static const double normal = 6;
  static const double md = 8;
  static const double lg = 12;
  static const double full = 999;
}

class AppDuration {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);
}

class AppCurves {
  static const Curve fast = Curves.easeOut;
  static const Curve normal = Curves.easeInOut;
}

class AppMinTouchSize {
  static const double width = 44;
  static const double height = 44;
}
```

- [ ] **Step 1.2: 验证可编译**

Run: `flutter analyze lib/shared/design_system/tokens.dart`
Expected: `No issues found!`

- [ ] **Step 1.3: 提交**

```powershell
git add app/lib/shared/design_system/tokens.dart
git commit -m "feat(ui): 添加 design system tokens"
```

---

## Task 2: AppColors 色板

**Files:**
- Create: `app/lib/shared/design_system/colors.dart`

- [ ] **Step 2.1: 创建 colors.dart**

```dart
import "package:flutter/material.dart";

class AppColors {
  final Color bgCanvas;
  final Color bgSurface;
  final Color bgElevated;
  final Color bgMuted;

  final Color borderSubtle;
  final Color borderDefault;
  final Color borderStrong;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;

  final Color brandPrimary;
  final Color brandGradientFrom;
  final Color brandGradientTo;
  final Color brandSubtle;
  final Color onBrand;

  final Color stateSuccess;
  final Color stateWarning;
  final Color stateDanger;
  final Color stateInfo;

  const AppColors({
    required this.bgCanvas,
    required this.bgSurface,
    required this.bgElevated,
    required this.bgMuted,
    required this.borderSubtle,
    required this.borderDefault,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.brandPrimary,
    required this.brandGradientFrom,
    required this.brandGradientTo,
    required this.brandSubtle,
    required this.onBrand,
    required this.stateSuccess,
    required this.stateWarning,
    required this.stateDanger,
    required this.stateInfo,
  });

  static const light = AppColors(
    bgCanvas: Color(0xFFFAFAFA),
    bgSurface: Color(0xFFFFFFFF),
    bgElevated: Color(0xFFFFFFFF),
    bgMuted: Color(0xFFF4F4F5),
    borderSubtle: Color(0xFFE4E4E7),
    borderDefault: Color(0xFFD4D4D8),
    borderStrong: Color(0xFFA1A1AA),
    textPrimary: Color(0xFF18181B),
    textSecondary: Color(0xFF52525B),
    textTertiary: Color(0xFF71717A),
    textDisabled: Color(0xFFA1A1AA),
    brandPrimary: Color(0xFF2563EB),
    brandGradientFrom: Color(0xFF38BDF8),
    brandGradientTo: Color(0xFF2563EB),
    brandSubtle: Color(0xFFEFF6FF),
    onBrand: Color(0xFFFFFFFF),
    stateSuccess: Color(0xFF059669),
    stateWarning: Color(0xFFD97706),
    stateDanger: Color(0xFFDC2626),
    stateInfo: Color(0xFF0EA5E9),
  );

  static const dark = AppColors(
    bgCanvas: Color(0xFF0A0A0B),
    bgSurface: Color(0xFF18181B),
    bgElevated: Color(0xFF27272A),
    bgMuted: Color(0xFF27272A),
    borderSubtle: Color(0xFF27272A),
    borderDefault: Color(0xFF3F3F46),
    borderStrong: Color(0xFF52525B),
    textPrimary: Color(0xFFFAFAFA),
    textSecondary: Color(0xFFA1A1AA),
    textTertiary: Color(0xFF71717A),
    textDisabled: Color(0xFF52525B),
    brandPrimary: Color(0xFF60A5FA),
    brandGradientFrom: Color(0xFF7DD3FC),
    brandGradientTo: Color(0xFF60A5FA),
    brandSubtle: Color(0x4D1E3A8A),
    onBrand: Color(0xFF0A0A0B),
    stateSuccess: Color(0xFF10B981),
    stateWarning: Color(0xFFF59E0B),
    stateDanger: Color(0xFFEF4444),
    stateInfo: Color(0xFF38BDF8),
  );

  LinearGradient get brandGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [brandGradientFrom, brandGradientTo],
      );
}

extension AppColorsExt on BuildContext {
  AppColors get colors {
    final brightness = Theme.of(this).brightness;
    return brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  }
}
```

- [ ] **Step 2.2: 验证**

Run: `flutter analyze lib/shared/design_system/colors.dart`
Expected: `No issues found!`

- [ ] **Step 2.3: 提交**

```powershell
git add app/lib/shared/design_system/colors.dart
git commit -m "feat(ui): 添加 AppColors 双主题色板"
```

---

## Task 3: AppTextStyles 字体阶梯

**Files:**
- Create: `app/lib/shared/design_system/typography.dart`

- [ ] **Step 3.1: 创建 typography.dart**

```dart
import "dart:ui";
import "package:flutter/material.dart";

class AppTextStyles {
  static const TextStyle display = TextStyle(
    fontSize: 28,
    height: 36 / 28,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle h1 = TextStyle(
    fontSize: 22,
    height: 30 / 22,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle h2 = TextStyle(
    fontSize: 18,
    height: 26 / 18,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle h3 = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    height: 22 / 14,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    height: 22 / 14,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle sm = TextStyle(
    fontSize: 13,
    height: 20 / 13,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle xs = TextStyle(
    fontSize: 11,
    height: 16 / 11,
    fontWeight: FontWeight.w500,
  );

  /// 数字等宽（学号、数字栏、时间戳）
  static const List<FontFeature> tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static TextStyle withTabular(TextStyle base) =>
      base.copyWith(fontFeatures: tabular);
}
```

- [ ] **Step 3.2: 验证**

Run: `flutter analyze lib/shared/design_system/typography.dart`
Expected: `No issues found!`

- [ ] **Step 3.3: 提交**

```powershell
git add app/lib/shared/design_system/typography.dart
git commit -m "feat(ui): 添加 AppTextStyles 字体阶梯"
```


---

## Task 4: 主题构建器（亮/暗）

**Files:**
- Create: `app/lib/shared/design_system/theme.dart`

- [ ] **Step 4.1: 创建 theme.dart**

```dart
import "package:flutter/material.dart";

import "colors.dart";
import "tokens.dart";
import "typography.dart";

ThemeData buildLightTheme() => _build(AppColors.light, Brightness.light);
ThemeData buildDarkTheme() => _build(AppColors.dark, Brightness.dark);

ThemeData _build(AppColors c, Brightness brightness) {
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.brandPrimary,
    onPrimary: c.onBrand,
    primaryContainer: c.brandSubtle,
    onPrimaryContainer: c.brandPrimary,
    secondary: c.brandPrimary,
    onSecondary: c.onBrand,
    error: c.stateDanger,
    onError: c.onBrand,
    surface: c.bgSurface,
    onSurface: c.textPrimary,
    surfaceContainerHighest: c.bgMuted,
    onSurfaceVariant: c.textSecondary,
    outline: c.borderDefault,
    outlineVariant: c.borderSubtle,
  );

  final textTheme = TextTheme(
    displayLarge: AppTextStyles.display.copyWith(color: c.textPrimary),
    headlineMedium: AppTextStyles.h1.copyWith(color: c.textPrimary),
    headlineSmall: AppTextStyles.h2.copyWith(color: c.textPrimary),
    titleLarge: AppTextStyles.h2.copyWith(color: c.textPrimary),
    titleMedium: AppTextStyles.h3.copyWith(color: c.textPrimary),
    titleSmall: AppTextStyles.bodyMedium.copyWith(color: c.textPrimary),
    bodyLarge: AppTextStyles.body.copyWith(color: c.textPrimary),
    bodyMedium: AppTextStyles.body.copyWith(color: c.textPrimary),
    bodySmall: AppTextStyles.sm.copyWith(color: c.textSecondary),
    labelLarge: AppTextStyles.bodyMedium.copyWith(color: c.textPrimary),
    labelMedium: AppTextStyles.sm.copyWith(color: c.textSecondary),
    labelSmall: AppTextStyles.xs.copyWith(color: c.textSecondary),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bgCanvas,
    canvasColor: c.bgSurface,
    dividerColor: c.borderSubtle,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: c.bgCanvas,
      foregroundColor: c.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppTextStyles.h1.copyWith(color: c.textPrimary),
      toolbarHeight: 52,
    ),
    cardTheme: CardThemeData(
      color: c.bgSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: c.borderSubtle),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.bgSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.normal),
        borderSide: BorderSide(color: c.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.normal),
        borderSide: BorderSide(color: c.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.normal),
        borderSide: BorderSide(color: c.brandPrimary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.normal),
        borderSide: BorderSide(color: c.stateDanger),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.bgElevated,
      contentTextStyle: AppTextStyles.body.copyWith(color: c.textPrimary),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: c.borderSubtle),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.bgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      titleTextStyle: AppTextStyles.h2.copyWith(color: c.textPrimary),
      contentTextStyle: AppTextStyles.body.copyWith(color: c.textPrimary),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
```

- [ ] **Step 4.2: 验证**

Run: `flutter analyze lib/shared/design_system/theme.dart`
Expected: `No issues found!`

- [ ] **Step 4.3: 提交**

```powershell
git add app/lib/shared/design_system/theme.dart
git commit -m "feat(ui): 添加 buildLightTheme/buildDarkTheme"
```

---

## Task 5: 接入新主题到 app.dart

**Files:**
- Modify: `app/lib/app.dart`

- [ ] **Step 5.1: 在 app.dart 顶部增加 import**

把 import 区追加：

```dart
import "shared/design_system/theme.dart";
```

- [ ] **Step 5.2: 替换 MaterialApp 的主题**

找到 `MaterialApp.router(...)` 调用，把：

```dart
theme: ThemeData(
  colorSchemeSeed: Colors.blue,
  ...
),
darkTheme: ThemeData(
  colorSchemeSeed: Colors.blue,
  ...
),
```

替换为：

```dart
theme: buildLightTheme(),
darkTheme: buildDarkTheme(),
```

- [ ] **Step 5.3: 验证主题切换**

Run: `flutter analyze lib/app.dart`
Expected: `No issues found!`

Run: `flutter test test/`
Expected: All tests passed

手工运行（可选）：`flutter run` 后切换系统亮/暗模式，确认所有页面色彩切换正常，无白底黑字（暗模式）或黑底白字（亮模式）的反色 bug。

- [ ] **Step 5.4: 提交**

```powershell
git add app/lib/app.dart
git commit -m "feat(ui): MaterialApp 切换到新设计系统主题"
```


---

## Task 6: AppButton 组件

**Files:**
- Create: `app/lib/shared/design_system/widgets/app_button.dart`

- [ ] **Step 6.1: 创建 app_button.dart**

```dart
import "package:flutter/material.dart";

import "../colors.dart";
import "../tokens.dart";
import "../typography.dart";

enum AppButtonVariant { primary, secondary, ghost, gradient }
enum AppButtonSize { sm, md, lg }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool loading;
  final bool fullWidth;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.leadingIcon,
    this.trailingIcon,
    this.loading = false,
    this.fullWidth = false,
  });

  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.md,
    this.leadingIcon,
    this.trailingIcon,
    this.loading = false,
    this.fullWidth = false,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.md,
    this.leadingIcon,
    this.trailingIcon,
    this.loading = false,
    this.fullWidth = false,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.md,
    this.leadingIcon,
    this.trailingIcon,
    this.loading = false,
    this.fullWidth = false,
  }) : variant = AppButtonVariant.ghost;

  const AppButton.gradient({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.lg,
    this.leadingIcon,
    this.trailingIcon,
    this.loading = false,
    this.fullWidth = false,
  }) : variant = AppButtonVariant.gradient;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final disabled = onPressed == null || loading;

    final height = switch (size) {
      AppButtonSize.sm => 32.0,
      AppButtonSize.md => 40.0,
      AppButtonSize.lg => 48.0,
    };
    final paddingX = switch (size) {
      AppButtonSize.sm => 12.0,
      AppButtonSize.md => 16.0,
      AppButtonSize.lg => 20.0,
    };
    final textStyle = switch (size) {
      AppButtonSize.sm => AppTextStyles.sm.copyWith(fontWeight: FontWeight.w500),
      AppButtonSize.md => AppTextStyles.bodyMedium,
      AppButtonSize.lg => AppTextStyles.bodyMedium.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
    };

    final fg = switch (variant) {
      AppButtonVariant.primary => c.onBrand,
      AppButtonVariant.gradient => c.onBrand,
      AppButtonVariant.secondary => c.textPrimary,
      AppButtonVariant.ghost => c.textPrimary,
    };

    final bgDecoration = switch (variant) {
      AppButtonVariant.primary => BoxDecoration(
          color: disabled ? c.borderSubtle : c.brandPrimary,
          borderRadius: BorderRadius.circular(AppRadius.normal),
        ),
      AppButtonVariant.gradient => BoxDecoration(
          gradient: disabled ? null : c.brandGradient,
          color: disabled ? c.borderSubtle : null,
          borderRadius: BorderRadius.circular(AppRadius.normal),
        ),
      AppButtonVariant.secondary => BoxDecoration(
          color: c.bgSurface,
          border: Border.all(color: c.borderDefault),
          borderRadius: BorderRadius.circular(AppRadius.normal),
        ),
      AppButtonVariant.ghost => BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.normal),
        ),
    };

    Widget content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(fg),
            ),
          )
        else if (leadingIcon != null)
          Icon(leadingIcon, size: 16, color: fg),
        if ((loading || leadingIcon != null)) const SizedBox(width: 8),
        Text(label, style: textStyle.copyWith(color: disabled ? c.textDisabled : fg)),
        if (trailingIcon != null) ...[
          const SizedBox(width: 8),
          Icon(trailingIcon, size: 16, color: fg),
        ],
      ],
    );

    return Opacity(
      opacity: disabled ? 0.6 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: BorderRadius.circular(AppRadius.normal),
          child: AnimatedContainer(
            duration: AppDuration.fast,
            curve: AppCurves.fast,
            height: height,
            padding: EdgeInsets.symmetric(horizontal: paddingX),
            decoration: bgDecoration,
            child: content,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6.2: 写 widget 测试**

Create: `app/test/design_system/app_button_test.dart`

```dart
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lesson_search/shared/design_system/widgets/app_button.dart";

void main() {
  Widget wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

  testWidgets("primary 渲染 label 和 onPressed", (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(AppButton.primary(
      label: "确认",
      onPressed: () => tapped = true,
    )));
    expect(find.text("确认"), findsOneWidget);
    await tester.tap(find.text("确认"));
    expect(tapped, isTrue);
  });

  testWidgets("disabled 时不可点击", (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(AppButton.primary(
      label: "确认",
      onPressed: null,
    )));
    await tester.tap(find.text("确认"));
    expect(tapped, isFalse);
  });

  testWidgets("loading 时显示 progress", (tester) async {
    await tester.pumpWidget(wrap(AppButton.primary(
      label: "确认",
      onPressed: () {},
      loading: true,
    )));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
```

- [ ] **Step 6.3: 运行测试**

Run: `flutter test test/design_system/app_button_test.dart`
Expected: All tests passed

- [ ] **Step 6.4: 提交**

```powershell
git add app/lib/shared/design_system/widgets/app_button.dart app/test/design_system/app_button_test.dart
git commit -m "feat(ui): 添加 AppButton（4 variant + 3 size + loading）"
```


---

## Task 7: AppCard 组件

**Files:**
- Create: `app/lib/shared/design_system/widgets/app_card.dart`

- [ ] **Step 7.1: 创建 app_card.dart**

```dart
import "package:flutter/material.dart";

import "../colors.dart";
import "../tokens.dart";

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool selected;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final brightness = Theme.of(context).brightness;

    final borderColor = selected
        ? c.brandPrimary
        : c.borderSubtle;
    final bgColor = selected ? c.brandSubtle : c.bgSurface;

    final shadows = brightness == Brightness.light
        ? <BoxShadow>[
            const BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ]
        : const <BoxShadow>[];

    final card = AnimatedContainer(
      duration: AppDuration.fast,
      curve: AppCurves.fast,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: shadows,
      ),
      padding: padding,
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: card,
      ),
    );
  }
}
```

- [ ] **Step 7.2: 验证**

Run: `flutter analyze lib/shared/design_system/widgets/app_card.dart`
Expected: `No issues found!`

- [ ] **Step 7.3: 提交**

```powershell
git add app/lib/shared/design_system/widgets/app_card.dart
git commit -m "feat(ui): 添加 AppCard（边框 + 阴影 + selected 态）"
```

---

## Task 8: StatusPill 状态胶囊

**Files:**
- Create: `app/lib/shared/design_system/widgets/status_pill.dart`

- [ ] **Step 8.1: 创建 status_pill.dart**

```dart
import "package:flutter/material.dart";

import "../colors.dart";
import "../tokens.dart";
import "../typography.dart";

enum StatusPillVariant { success, warning, danger, info, neutral }

class StatusPill extends StatelessWidget {
  final String label;
  final StatusPillVariant variant;
  final IconData? icon;

  const StatusPill({
    super.key,
    required this.label,
    required this.variant,
    this.icon,
  });

  const StatusPill.success({super.key, required this.label, this.icon})
      : variant = StatusPillVariant.success;
  const StatusPill.warning({super.key, required this.label, this.icon})
      : variant = StatusPillVariant.warning;
  const StatusPill.danger({super.key, required this.label, this.icon})
      : variant = StatusPillVariant.danger;
  const StatusPill.info({super.key, required this.label, this.icon})
      : variant = StatusPillVariant.info;
  const StatusPill.neutral({super.key, required this.label, this.icon})
      : variant = StatusPillVariant.neutral;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = switch (variant) {
      StatusPillVariant.success => c.stateSuccess,
      StatusPillVariant.warning => c.stateWarning,
      StatusPillVariant.danger => c.stateDanger,
      StatusPillVariant.info => c.stateInfo,
      StatusPillVariant.neutral => c.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTextStyles.xs.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 8.2: 验证**

Run: `flutter analyze lib/shared/design_system/widgets/status_pill.dart`
Expected: `No issues found!`

- [ ] **Step 8.3: 提交**

```powershell
git add app/lib/shared/design_system/widgets/status_pill.dart
git commit -m "feat(ui): 添加 StatusPill（5 种状态胶囊）"
```


---

## Task 9: SegmentedControl 分段控件

**Files:**
- Create: `app/lib/shared/design_system/widgets/segmented_control.dart`

- [ ] **Step 9.1: 创建 segmented_control.dart**

```dart
import "package:flutter/material.dart";

import "../colors.dart";
import "../tokens.dart";
import "../typography.dart";

class AppSegmentedControl<T> extends StatelessWidget {
  final List<AppSegmentedItem<T>> items;
  final T value;
  final ValueChanged<T> onChanged;

  const AppSegmentedControl({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      height: 36,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.bgMuted,
        borderRadius: BorderRadius.circular(AppRadius.normal),
        border: Border.all(color: c.borderSubtle),
      ),
      child: Row(
        children: items.map((item) {
          final selected = item.value == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(item.value),
              child: AnimatedContainer(
                duration: AppDuration.fast,
                curve: AppCurves.fast,
                decoration: BoxDecoration(
                  color: selected ? c.bgSurface : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  boxShadow: selected
                      ? const [
                          BoxShadow(
                            color: Color(0x0D000000),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  item.label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: selected ? c.textPrimary : c.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class AppSegmentedItem<T> {
  final T value;
  final String label;
  const AppSegmentedItem({required this.value, required this.label});
}
```

- [ ] **Step 9.2: 验证**

Run: `flutter analyze lib/shared/design_system/widgets/segmented_control.dart`
Expected: `No issues found!`

- [ ] **Step 9.3: 提交**

```powershell
git add app/lib/shared/design_system/widgets/segmented_control.dart
git commit -m "feat(ui): 添加 AppSegmentedControl"
```

---

## Task 10: BottomActionBar 底部固定操作栏

**Files:**
- Create: `app/lib/shared/design_system/widgets/bottom_action_bar.dart`

- [ ] **Step 10.1: 创建 bottom_action_bar.dart**

```dart
import "package:flutter/material.dart";

import "../colors.dart";
import "../tokens.dart";

class BottomActionBar extends StatelessWidget {
  /// 顶部可选信息文字（如"已选 3 个任务，共 90 条记录"）
  final String? hintText;

  /// 主操作按钮（必填）
  final Widget primary;

  /// 副操作按钮（可选，左侧）
  final Widget? secondary;

  const BottomActionBar({
    super.key,
    this.hintText,
    required this.primary,
    this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final brightness = Theme.of(context).brightness;
    final shadows = brightness == Brightness.light
        ? const <BoxShadow>[
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 6,
              offset: Offset(0, -2),
            ),
          ]
        : const <BoxShadow>[];

    return Container(
      decoration: BoxDecoration(
        color: c.bgSurface,
        border: Border(top: BorderSide(color: c.borderSubtle)),
        boxShadow: shadows,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hintText != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    hintText!,
                    style: TextStyle(fontSize: 13, color: c.textSecondary),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  if (secondary != null) ...[
                    secondary!,
                    const SizedBox(width: 12),
                  ],
                  Expanded(child: primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 10.2: 验证**

Run: `flutter analyze lib/shared/design_system/widgets/bottom_action_bar.dart`
Expected: `No issues found!`

- [ ] **Step 10.3: 提交**

```powershell
git add app/lib/shared/design_system/widgets/bottom_action_bar.dart
git commit -m "feat(ui): 添加 BottomActionBar"
```


---

## Task 11: SyncStatusBanner 同步状态条

**Files:**
- Create: `app/lib/shared/design_system/widgets/sync_status_banner.dart`

- [ ] **Step 11.1: 创建 sync_status_banner.dart**

```dart
import "package:flutter/material.dart";

import "../colors.dart";
import "../tokens.dart";
import "../typography.dart";
import "app_button.dart";

enum SyncBannerState { syncing, ready, failed, unknown }

class SyncStatusBanner extends StatelessWidget {
  final SyncBannerState state;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SyncStatusBanner({
    super.key,
    required this.state,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (color, icon) = switch (state) {
      SyncBannerState.syncing => (c.stateInfo, Icons.sync),
      SyncBannerState.ready => (c.stateSuccess, Icons.check_circle_outline),
      SyncBannerState.failed => (c.stateDanger, Icons.error_outline),
      SyncBannerState.unknown => (c.stateWarning, Icons.cloud_off_outlined),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(color: c.textPrimary),
                ),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    description!,
                    style: AppTextStyles.sm.copyWith(color: c.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            AppButton.ghost(
              label: actionLabel!,
              onPressed: onAction,
              size: AppButtonSize.sm,
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 11.2: 验证**

Run: `flutter analyze lib/shared/design_system/widgets/sync_status_banner.dart`
Expected: `No issues found!`

- [ ] **Step 11.3: 提交**

```powershell
git add app/lib/shared/design_system/widgets/sync_status_banner.dart
git commit -m "feat(ui): 添加 SyncStatusBanner"
```

---

## Task 12: SegmentedProgressBar 5 段彩色进度条

**Files:**
- Create: `app/lib/shared/design_system/widgets/progress_bar.dart`

- [ ] **Step 12.1: 创建 progress_bar.dart**

```dart
import "package:flutter/material.dart";

import "../colors.dart";
import "../tokens.dart";

class SegmentedProgressBar extends StatelessWidget {
  /// 各段数据：value 表示数量；color 表示该段颜色。
  /// 总数 = totalCount。
  /// 已处理总数 = segments.sumOf(value)；剩余部分以 muted 灰色显示。
  final List<ProgressSegment> segments;
  final int totalCount;
  final double height;

  const SegmentedProgressBar({
    super.key,
    required this.segments,
    required this.totalCount,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (totalCount <= 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(height: height, color: c.bgMuted),
      );
    }

    final processed = segments.fold<int>(0, (s, seg) => s + seg.value);
    final remaining = (totalCount - processed).clamp(0, totalCount);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            for (final seg in segments)
              if (seg.value > 0)
                Flexible(
                  flex: seg.value,
                  child: Container(color: seg.color),
                ),
            if (remaining > 0)
              Flexible(
                flex: remaining,
                child: Container(color: c.bgMuted),
              ),
          ],
        ),
      ),
    );
  }
}

class ProgressSegment {
  final int value;
  final Color color;
  const ProgressSegment({required this.value, required this.color});
}
```

- [ ] **Step 12.2: 验证**

Run: `flutter analyze lib/shared/design_system/widgets/progress_bar.dart`
Expected: `No issues found!`

- [ ] **Step 12.3: 提交**

```powershell
git add app/lib/shared/design_system/widgets/progress_bar.dart
git commit -m "feat(ui): 添加 SegmentedProgressBar"
```


---

## Task 13: AppTopBar 与 AppInput

**Files:**
- Create: `app/lib/shared/design_system/widgets/app_top_bar.dart`
- Create: `app/lib/shared/design_system/widgets/app_input.dart`

- [ ] **Step 13.1: 创建 app_top_bar.dart**

```dart
import "package:flutter/material.dart";

import "../colors.dart";
import "../typography.dart";

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  const AppTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
  });

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 52 : 72);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.bgCanvas,
        border: Border(bottom: BorderSide(color: c.borderSubtle)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              if (leading != null) leading!,
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.h1.copyWith(color: c.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: AppTextStyles.sm.copyWith(color: c.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 13.2: 创建 app_input.dart**

```dart
import "package:flutter/material.dart";

import "../colors.dart";
import "../tokens.dart";
import "../typography.dart";

class AppInput extends StatelessWidget {
  final String? label;
  final String? hint;
  final String? errorText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final IconData? prefixIcon;
  final Widget? suffix;

  const AppInput({
    super.key,
    this.label,
    this.hint,
    this.errorText,
    this.controller,
    this.onChanged,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.prefixIcon,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTextStyles.sm.copyWith(
              color: c.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: keyboardType,
          obscureText: obscureText,
          enabled: enabled,
          style: AppTextStyles.body.copyWith(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.body.copyWith(color: c.textTertiary),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 18, color: c.textSecondary)
                : null,
            suffix: suffix,
            errorText: errorText,
            errorStyle: AppTextStyles.sm.copyWith(color: c.stateDanger),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 13.3: 验证**

Run: `flutter analyze lib/shared/design_system/widgets/app_top_bar.dart lib/shared/design_system/widgets/app_input.dart`
Expected: `No issues found!`

- [ ] **Step 13.4: 提交**

```powershell
git add app/lib/shared/design_system/widgets/app_top_bar.dart app/lib/shared/design_system/widgets/app_input.dart
git commit -m "feat(ui): 添加 AppTopBar 和 AppInput"
```

---

## Task 14: 视觉重做 EmptyState/LoadingOverlay/Toast（API 兼容）

**Files:**
- Modify: `app/lib/shared/widgets/empty_state.dart`
- Modify: `app/lib/shared/widgets/loading_overlay.dart`
- Modify: `app/lib/shared/widgets/toast.dart`

> 关键约束：所有 factory 与构造参数签名保持不变，避免现有调用方（74 处）报错。仅修改内部样式。

- [ ] **Step 14.1: 重做 empty_state.dart 视觉**

打开文件，把 `EmptyState` 的 build 方法整体换成下方版本（保留所有 factory，不变）：

```dart
@override
Widget build(BuildContext context) {
  final c = context.colors;
  return Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: color ?? c.textTertiary),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.h3.copyWith(color: c.textPrimary),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    ),
  );
}
```

并在文件顶部 import 区追加：

```dart
import "../design_system/colors.dart";
import "../design_system/tokens.dart";
import "../design_system/typography.dart";
```

EmptyStateCard 同步重做：把外层 Card 替换为新设计的 AppCard：

```dart
import "../design_system/widgets/app_card.dart";

// EmptyStateCard build:
@override
Widget build(BuildContext context) {
  return AppCard(
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: EmptyState(icon: icon, message: message, color: color, action: action),
  );
}
```

- [ ] **Step 14.2: 微调 loading_overlay.dart**

把 CircularProgressIndicator 的 valueColor 设置为 brand 色，message 字号用 AppTextStyles.sm：

```dart
import "../design_system/colors.dart";
import "../design_system/typography.dart";

// 在 build 中改成：
CircularProgressIndicator(
  strokeWidth: 2.5,
  valueColor: AlwaysStoppedAnimation(context.colors.brandPrimary),
)
// message 文本：
Text(message!, style: AppTextStyles.sm.copyWith(color: context.colors.textSecondary))
```

- [ ] **Step 14.3: 微调 toast.dart**

把 SnackBar 的圆角设为 AppRadius.md，文字颜色为 textPrimary，背景 bgElevated。

- [ ] **Step 14.4: 验证**

Run: `flutter analyze lib/shared/widgets/empty_state.dart lib/shared/widgets/loading_overlay.dart lib/shared/widgets/toast.dart`
Expected: `No issues found!`

Run: `flutter test test/`
Expected: 全部通过（旧调用没破坏）

- [ ] **Step 14.5: 提交**

```powershell
git add app/lib/shared/widgets/empty_state.dart app/lib/shared/widgets/loading_overlay.dart app/lib/shared/widgets/toast.dart
git commit -m "refactor(ui): EmptyState/LoadingOverlay/Toast 视觉对齐新设计系统"
```


---

---

## Task 15: 重写 home_page.dart

**Files:**
- Modify: `app/lib/features/home/presentation/home_page.dart`

**约束**：
- 保留 `initState`、`_checkTokenValidity`、`_checkRealName`、`_checkLoginAndNavigate`、`_showLoginRequiredDialog` 不变
- 保留 4 个入口（点名、记名、查课记录、扩展功能）的导航 path 不变
- 仅 build 与 _buildSyncWarningCard 重做视觉

- [ ] **Step 15.1: 替换 build 方法**

把 build 方法整体替换为：

```dart
@override
Widget build(BuildContext context) {
  final c = context.colors;
  return Scaffold(
    backgroundColor: c.bgCanvas,
    body: SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHero()),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            sliver: SliverList.list(
              children: [
                _buildSyncWarningCard(),
                const SizedBox(height: AppSpacing.lg),
                _buildPrimaryActions(),
                const SizedBox(height: AppSpacing.lg),
                _buildSecondaryActions(),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 15.2: 添加 _buildHero 与 _buildSyncIndicator**

在类中追加（紧跟 build 方法后）：

```dart
Widget _buildHero() {
  final c = context.colors;
  final syncState = ref.watch(syncStateProvider);
  final issueCount = ref.watch(syncIssueCountProvider);
  final count = issueCount.valueOrNull ?? 0;

  return Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.lg,
      AppSpacing.lg,
      AppSpacing.md,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onLongPress: () => context.push('/debug/sync'),
                child: Text(
                  '考勤助手',
                  style: AppTextStyles.display.copyWith(color: c.textPrimary),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '高效记录课堂考勤',
                style: AppTextStyles.sm.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
        _buildSyncIndicator(syncState, count),
        IconButton(
          icon: Icon(Icons.settings_outlined, color: c.textSecondary),
          tooltip: '设置',
          onPressed: () => context.push('/settings'),
        ),
      ],
    ),
  );
}

Widget _buildSyncIndicator(SyncState state, int count) {
  final c = context.colors;
  if (count == 0 && state != SyncState.syncing) return const SizedBox.shrink();

  IconData icon;
  Color color;
  if (state == SyncState.syncing) {
    icon = Icons.sync;
    color = c.stateInfo;
  } else if (state == SyncState.error) {
    icon = Icons.sync_problem;
    color = c.stateDanger;
  } else {
    icon = Icons.sync;
    color = c.stateWarning;
  }

  return Stack(
    alignment: Alignment.center,
    children: [
      IconButton(
        icon: Icon(icon, color: color),
        tooltip: state == SyncState.error ? '同步异常，点击重试' : '同步记录',
        onPressed: () => ref.read(syncServiceProvider).syncNow(),
      ),
      if (count > 0 && state != SyncState.syncing)
        Positioned(
          right: 4,
          top: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: c.stateDanger,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
    ],
  );
}
```

- [ ] **Step 15.3: 添加 _buildPrimaryActions**

```dart
Widget _buildPrimaryActions() {
  return Row(
    children: [
      Expanded(
        flex: 7,
        child: SizedBox(
          height: 88,
          child: AppButton.gradient(
            label: '开始记名',
            onPressed: () => _checkLoginAndNavigate('/name-check/select'),
            leadingIcon: Icons.checklist,
            fullWidth: true,
          ),
        ),
      ),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        flex: 3,
        child: SizedBox(
          height: 88,
          child: AppButton.secondary(
            label: '点名',
            onPressed: () => _checkLoginAndNavigate('/roll-call/select'),
            leadingIcon: Icons.record_voice_over,
            fullWidth: true,
          ),
        ),
      ),
    ],
  );
}
```

- [ ] **Step 15.4: 添加 _buildSecondaryActions 与 _buildEntryCard**

```dart
Widget _buildSecondaryActions() {
  return GridView.count(
    crossAxisCount: 2,
    crossAxisSpacing: AppSpacing.md,
    mainAxisSpacing: AppSpacing.md,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    childAspectRatio: 1.5,
    children: [
      _buildEntryCard(
        icon: Icons.history,
        title: '查课记录',
        subtitle: '查看与编辑历史',
        onTap: () => _checkLoginAndNavigate('/records'),
      ),
      _buildEntryCard(
        icon: Icons.extension,
        title: '扩展功能',
        subtitle: '提交、汇总、排行',
        onTap: () => _checkLoginAndNavigate('/extension'),
      ),
    ],
  );
}

Widget _buildEntryCard({
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  final c = context.colors;
  return AppCard(
    onTap: onTap,
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: c.brandSubtle,
            borderRadius: BorderRadius.circular(AppRadius.normal),
          ),
          child: Icon(icon, size: 18, color: c.brandPrimary),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: AppTextStyles.h3.copyWith(color: c.textPrimary)),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTextStyles.sm.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      ],
    ),
  );
}
```

- [ ] **Step 15.5: 重写 _buildSyncWarningCard**

整体替换为：

```dart
Widget _buildSyncWarningCard() {
  final issueCount = ref.watch(syncIssueCountProvider);
  final syncState = ref.watch(syncStateProvider);
  final hasSyncFailed = ref.watch(hasSyncFailedProvider);
  final isSyncFailed = hasSyncFailed.valueOrNull ?? false;

  return issueCount.when(
    data: (count) {
      if (count == 0) return const SizedBox.shrink();

      if (syncState != SyncState.syncing && count > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(syncServiceProvider).syncNow();
        });
      }

      final state = isSyncFailed
          ? SyncBannerState.failed
          : syncState == SyncState.syncing
              ? SyncBannerState.syncing
              : SyncBannerState.unknown;

      final title = isSyncFailed
          ? '$count 条数据同步失败'
          : syncState == SyncState.syncing
              ? '正在自动同步 $count 条记录'
              : '$count 条记录待同步';

      final desc = isSyncFailed
          ? '请先处理后再继续编辑或提交'
          : syncState == SyncState.syncing
              ? '请避免同时编辑或提交，防止冲突'
              : '系统将在后台自动同步';

      return SyncStatusBanner(
        state: state,
        title: title,
        description: desc,
      );
    },
    loading: () => const SizedBox.shrink(),
    error: (_, __) => const SizedBox.shrink(),
  );
}
```

- [ ] **Step 15.6: 在文件顶部追加 imports，删除 entry_card import**

追加：

```dart
import '../../../shared/design_system/colors.dart';
import '../../../shared/design_system/tokens.dart';
import '../../../shared/design_system/typography.dart';
import '../../../shared/design_system/widgets/app_button.dart';
import '../../../shared/design_system/widgets/app_card.dart';
import '../../../shared/design_system/widgets/sync_status_banner.dart';
```

删除：

```dart
import '../../../shared/widgets/entry_card.dart';
```

- [ ] **Step 15.7: 验证**

Run: `flutter analyze lib/features/home/presentation/home_page.dart`
Expected: `No issues found!`

手工运行核对：
- hero 区显示 '考勤助手' + 副标题
- 渐变 '开始记名' 按钮 + secondary '点名' 按钮（70/30）
- 2 个次入口卡片
- 同步异常时 SyncStatusBanner 显示

- [ ] **Step 15.8: 提交**

```powershell
git add app/lib/features/home/presentation/home_page.dart
git commit -m "refactor(ui): 重做首页 - hero + 主操作 + 次入口网格"
```


---

## Task 16: 重写记名页（视觉层，业务逻辑不动）

**Files:**
- Modify: `app/lib/features/attendance/presentation/name_check/name_check_page.dart`

**约束**：完全保留业务逻辑（_isMarking、_focusedIndex、jumpToNextPending、mark、markPresent、markOther、_showExitDialog、_runFinish、_showNewStudentsDialog 全部不动）。仅重做：班级切换器、学生卡片、底部操作栏、新增顶部进度条。

- [ ] **Step 16.1: 在文件顶部追加 imports**

```dart
import '../../../../shared/design_system/colors.dart';
import '../../../../shared/design_system/tokens.dart';
import '../../../../shared/design_system/typography.dart';
import '../../../../shared/design_system/widgets/app_button.dart';
import '../../../../shared/design_system/widgets/bottom_action_bar.dart';
import '../../../../shared/design_system/widgets/progress_bar.dart';
import '../../../../shared/design_system/widgets/segmented_control.dart';
import '../../../../shared/design_system/widgets/status_pill.dart';
```

- [ ] **Step 16.2: 替换 AppBar 为顶部新组件**

把 `_buildExecutingView` 中的 `Scaffold(appBar: AppBar(...))` 整段替换 appBar 为：

```dart
appBar: PreferredSize(
  preferredSize: const Size.fromHeight(72),
  child: _buildTopBar(context, state),
),
```

并在 `_NameCheckPageState` 类中追加方法：

```dart
Widget _buildTopBar(BuildContext context, NameCheckState state) {
  final c = context.colors;
  final cls = state.currentClass;
  final segments = _calcProgressSegments(state, c);

  return Container(
    decoration: BoxDecoration(
      color: c.bgCanvas,
      border: Border(bottom: BorderSide(color: c.borderSubtle)),
    ),
    child: SafeArea(
      bottom: false,
      child: Column(
        children: [
          SizedBox(
            height: 52,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: c.textPrimary),
                  onPressed: () => _showExitDialog(context),
                ),
                Expanded(
                  child: Text(
                    cls?.displayName ?? '',
                    style: AppTextStyles.h2.copyWith(color: c.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '${state.processedStudents}/${state.totalStudents}',
                    style: AppTextStyles.withTabular(AppTextStyles.bodyMedium)
                        .copyWith(color: c.textSecondary),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.check_circle_outline, color: c.brandPrimary),
                  tooltip: '确认名单',
                  onPressed: _isMarking
                      ? null
                      : () => _showFinishDialog(context, state),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SegmentedProgressBar(
              segments: segments,
              totalCount: state.totalStudents,
            ),
          ),
        ],
      ),
    ),
  );
}

List<ProgressSegment> _calcProgressSegments(
    NameCheckState state, AppColors c) {
  int present = 0, absent = 0, late_ = 0, leave = 0, other = 0;
  for (final list in state.studentsByClass.values) {
    for (final s in list) {
      switch (s.status) {
        case AttendanceStatus.present:
          present++;
          break;
        case AttendanceStatus.absent:
          absent++;
          break;
        case AttendanceStatus.late_:
          late_++;
          break;
        case AttendanceStatus.leave:
          leave++;
          break;
        case AttendanceStatus.other:
          other++;
          break;
        case AttendanceStatus.pending:
          break;
      }
    }
  }
  return [
    ProgressSegment(value: present, color: c.stateSuccess),
    ProgressSegment(value: absent, color: c.stateDanger),
    ProgressSegment(value: late_, color: c.stateWarning),
    ProgressSegment(value: leave, color: c.stateInfo),
    ProgressSegment(value: other, color: c.textSecondary),
  ];
}
```

- [ ] **Step 16.3: 班级切换 ChoiceChip → SegmentedControl**

找到 `if (state.classes.length > 1)` 后面那个 SizedBox(height: 48, child: ListView.builder...) 整段，替换为：

```dart
if (state.classes.length > 1)
  Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: AppSegmentedControl<int>(
      items: [
        for (var i = 0; i < state.classes.length; i++)
          AppSegmentedItem(value: i, label: state.classes[i].displayName),
      ],
      value: state.currentClassIndex,
      onChanged: (i) {
        ref.read(nameCheckProvider.notifier).switchClass(i);
        _pageController.animateToPage(
          i,
          duration: AppDuration.normal,
          curve: AppCurves.normal,
        );
        setState(() => _focusedIndex = 0);
      },
    ),
  ),
```

- [ ] **Step 16.4: 重做 _StudentCard**

把 `_StudentCard` 类整体替换为：

```dart
class _StudentCard extends StatelessWidget {
  final String name;
  final String studentNo;
  final AttendanceStatus status;
  final String? remark;
  final bool isFocused;
  final VoidCallback onTap;

  const _StudentCard({
    required this.name,
    required this.studentNo,
    required this.status,
    this.remark,
    required this.isFocused,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isPending = status == AttendanceStatus.pending;
    final bgColor = isFocused
        ? c.brandSubtle
        : (isPending ? c.bgSurface : c.bgMuted);
    final borderColor = isFocused ? c.brandPrimary : c.borderSubtle;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: AppDuration.fast,
          curve: AppCurves.fast,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
                color: borderColor, width: isFocused ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: c.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      studentNo,
                      style: AppTextStyles.withTabular(AppTextStyles.xs)
                          .copyWith(color: c.textTertiary),
                    ),
                  ],
                ),
              ),
              if (!isPending) ...[
                const SizedBox(width: 8),
                _statusPillFor(status, remark),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPillFor(AttendanceStatus s, String? remark) {
    return switch (s) {
      AttendanceStatus.present => const StatusPill.success(label: '到'),
      AttendanceStatus.absent => const StatusPill.danger(label: '缺'),
      AttendanceStatus.late_ => const StatusPill.warning(label: '迟'),
      AttendanceStatus.leave => const StatusPill.info(label: '假'),
      AttendanceStatus.other => StatusPill.neutral(label: remark ?? '他'),
      AttendanceStatus.pending => const SizedBox.shrink(),
    };
  }
}
```


- [ ] **Step 16.5: 重做底部操作栏**

把 `_buildBottomBar` 末尾的 `return Container(...)` 整段（含 SafeArea + Column + Row 5 个按钮）替换为：

```dart
final c = context.colors;
final focused = _focusedIndex != null && _focusedIndex! < students.length
    ? students[_focusedIndex!]
    : null;

return BottomActionBar(
  hintText: focused != null
      ? '当前学生：${focused.student.name}'
      : '请选择学生',
  primary: AppButton.primary(
    label: '到课',
    onPressed: (!isSyncFailed && !_isMarking && _focusedIndex != null)
        ? markPresent
        : null,
    size: AppButtonSize.lg,
    fullWidth: true,
  ),
  secondary: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _smallActionButton('缺', c.stateDanger,
          (!isSyncFailed && !_isMarking && _focusedIndex != null)
              ? () => mark(AttendanceStatus.absent)
              : null),
      const SizedBox(width: 6),
      _smallActionButton('迟', c.stateWarning,
          (!isSyncFailed && !_isMarking && _focusedIndex != null)
              ? () => mark(AttendanceStatus.late_)
              : null),
      const SizedBox(width: 6),
      _smallActionButton('假', c.stateInfo,
          (!isSyncFailed && !_isMarking && _focusedIndex != null)
              ? () => mark(AttendanceStatus.leave)
              : null),
      const SizedBox(width: 6),
      _smallActionButton('他', c.textSecondary,
          (!isSyncFailed && !_isMarking && _focusedIndex != null)
              ? markOther
              : null),
    ],
  ),
);
```

并在类中添加：

```dart
Widget _smallActionButton(String label, Color color, VoidCallback? onPressed) {
  final c = context.colors;
  final disabled = onPressed == null;
  return SizedBox(
    width: 44,
    height: 48,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        foregroundColor: color,
        side: BorderSide(
          color: disabled ? c.borderSubtle : color.withValues(alpha: 0.4),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.normal),
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodyMedium.copyWith(
          color: disabled ? c.textDisabled : color,
        ),
      ),
    ),
  );
}
```

> 已存在的 `_ActionButton` 旧组件可删除（不再被引用）。

- [ ] **Step 16.6: 处理同步失败横幅样式**

文件中现有的 "同步失败红色提示条" Container 替换为：

```dart
if (isSyncFailed)
  Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: SyncStatusBanner(
      state: SyncBannerState.failed,
      title: '存在同步失败数据',
      description: '为避免数据不一致，编辑已锁定。请到同步问题详情处理。',
    ),
  ),
```

并 import：

```dart
import '../../../../shared/design_system/widgets/sync_status_banner.dart';
```

- [ ] **Step 16.7: 验证**

Run: `flutter analyze lib/features/attendance/presentation/name_check/name_check_page.dart`
Expected: `No issues found!`

Run: `flutter test test/`
Expected: All tests passed

手工运行核对：
- 顶部进度条彩色分段正确
- 班级切换 segmented control 工作
- 学生卡片 focus 边框为品牌色
- 底部 "到课" 主按钮 + 4 个小状态按钮工作正常
- 暗模式色彩协调

- [ ] **Step 16.8: 提交**

```powershell
git add app/lib/features/attendance/presentation/name_check/name_check_page.dart
git commit -m "refactor(ui): 重做记名页 - 进度条 + 紧凑卡片 + 新底部操作栏"
```


---

## Task 17: 重写提交页（仅第一个 Tab + 顶部状态卡）

**Files:**
- Modify: `app/lib/features/extension/presentation/submission_page.dart`

**约束**：保留所有 Notifier、Provider、`_submit`、`_onTabChanged`、`_buildNoDutyView` 不动。第二个 Tab "我的提交" 暂保持原状。

- [ ] **Step 17.1: 在文件顶部追加 imports**

```dart
import '../../../shared/design_system/colors.dart';
import '../../../shared/design_system/tokens.dart';
import '../../../shared/design_system/typography.dart';
import '../../../shared/design_system/widgets/app_button.dart';
import '../../../shared/design_system/widgets/app_card.dart';
import '../../../shared/design_system/widgets/bottom_action_bar.dart';
import '../../../shared/design_system/widgets/segmented_control.dart';
import '../../../shared/design_system/widgets/status_pill.dart';
import '../../../shared/design_system/widgets/sync_status_banner.dart';
```

- [ ] **Step 17.2: TabBar 改为 SegmentedControl**

把 Scaffold 的 `appBar: AppBar(... bottom: TabBar(...))` 改为：

```dart
appBar: AppBar(
  title: const Text('名单提交'),
),
body: Column(
  children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: AppSegmentedControl<int>(
        items: const [
          AppSegmentedItem(value: 0, label: '提交任务'),
          AppSegmentedItem(value: 1, label: '我的提交'),
        ],
        value: _tabController.index,
        onChanged: (i) {
          _tabController.animateTo(i);
          setState(() {});
        },
      ),
    ),
    Expanded(child: ...),  // 原 TabBarView 移到这里
  ],
),
```

> 注意：保留 `TabController`，因为有动画过渡和 listener 监听 tab 切换。`AppSegmentedControl.onChanged` 调 `animateTo(i)`，而 `_onTabChanged` 监听器会触发数据刷新。

- [ ] **Step 17.3: 重做 _SubmitTaskTab 的同步状态卡**

把 `_SubmitTaskTab.build` 内最顶部的 `issueCount.when(data: (count) { ... Card(...) })` 整段替换为：

```dart
issueCount.when(
  data: (count) {
    if (count == 0) return const SizedBox.shrink();
    final state = isSyncFailed
        ? SyncBannerState.failed
        : syncState == SyncState.syncing
            ? SyncBannerState.syncing
            : SyncBannerState.unknown;
    final title = isSyncFailed
        ? '$count 条同步失败，请先处理后再提交'
        : syncState == SyncState.syncing
            ? '正在自动同步 $count 条记录'
            : '$count 条记录待同步';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SyncStatusBanner(state: state, title: title),
    );
  },
  loading: () => const SizedBox.shrink(),
  error: (_, __) => const SizedBox.shrink(),
),
```

- [ ] **Step 17.4: 重做任务列表卡片**

把 `tasksAsync.when` 中的 `Card(child: ListView.builder(...))` 替换为：

```dart
data: (tasks) {
  if (tasks.isEmpty) return EmptyStateCard.noTask();
  return Column(
    children: [
      for (final taskRaw in tasks)
        _buildTaskCard(context, taskRaw as Map<String, dynamic>),
    ],
  );
},
```

并在 `_SubmitTaskTab` 中追加：

```dart
Widget _buildTaskCard(BuildContext context, Map<String, dynamic> task) {
  final c = context.colors;
  final taskId = task['id'] as String;
  final isSelected = selectedTaskIds.contains(taskId);
  final classNames = (task['class_names'] as List?)?.join('、') ?? '未知班级';
  final recordCount = task['record_count'] as int? ?? 0;
  final created = DateTime.parse(task['created_at'] as String);

  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: AppCard(
      selected: isSelected,
      onTap: () {
        if (isSelected) {
          onSelectionChanged(
            selectedTaskIds.where((id) => id != taskId).toList(),
          );
        } else {
          onSelectionChanged([...selectedTaskIds, taskId]);
        }
      },
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              isSelected
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              color: isSelected ? c.brandPrimary : c.borderStrong,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  classNames,
                  style: AppTextStyles.bodyMedium.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('MM-dd HH:mm').format(created)} · $recordCount 条记录',
                  style: AppTextStyles.sm.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 17.5: 提交按钮区改为 BottomActionBar**

把第一个 Tab 末尾的 `_SubmitButton(...)` + 上方的 "已选择 X 个任务" Text 区，整体迁移到 Scaffold 的 bottomNavigationBar：

```dart
bottomNavigationBar: hasDuty && _tabController.index == 0
    ? BottomActionBar(
        hintText: _selectedTaskIds.isEmpty
            ? '请选择要提交的任务'
            : '已选择 ${_selectedTaskIds.length} 个任务',
        primary: _SubmitButton(
          loading: _loading,
          issueCount: ref.watch(syncIssueCountProvider),
          syncState: ref.watch(syncStateProvider),
          onSubmit: () => _submit(weekNumber),
        ),
      )
    : null,
```

> 注意：`_SubmitButton` 内部已经处理 disabled 状态，保持不动；只是从 inline 移到 BottomActionBar 的 primary 槽。

- [ ] **Step 17.6: 验证**

Run: `flutter analyze lib/features/extension/presentation/submission_page.dart`
Expected: 不引入新 error

Run: `flutter test test/`
Expected: All tests passed

- [ ] **Step 17.7: 提交**

```powershell
git add app/lib/features/extension/presentation/submission_page.dart
git commit -m "refactor(ui): 重做提交页 - SegmentedControl + 紧凑任务卡 + BottomActionBar"
```


---

## Task 18: 重写记录详情页

**Files:**
- Modify: `app/lib/features/records/presentation/record_detail_page.dart`

**约束**：保留所有业务逻辑（_load、_updateStatus、_generateText、_isSubmitted/_isAbandoned/_submitStatusUnknown、编辑切换）。仅重做：顶部状态横幅整合 + 信息卡 + 异常列表样式。

- [ ] **Step 18.1: 在文件顶部追加 imports**

```dart
import '../../../shared/design_system/colors.dart';
import '../../../shared/design_system/tokens.dart';
import '../../../shared/design_system/typography.dart';
import '../../../shared/design_system/widgets/app_card.dart';
import '../../../shared/design_system/widgets/progress_bar.dart';
import '../../../shared/design_system/widgets/status_pill.dart';
import '../../../shared/design_system/widgets/sync_status_banner.dart';
```

- [ ] **Step 18.2: 整合 4 种顶部状态横幅**

在 build 方法的 body 中，找到 `if (_isAbandoned)` / `if (_submitStatusUnknown)` / `if (_isSubmitted)` / `if (isSyncFailed)` 这 4 段 Container（约 320-400 行），整体替换为单个方法调用：

```dart
_buildStatusBanner(isSyncFailed),
```

并在类中添加方法：

```dart
Widget _buildStatusBanner(bool isSyncFailed) {
  if (_isAbandoned) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SyncStatusBanner(
        state: SyncBannerState.unknown,
        title: '该记录已放弃',
        description: '仅可查看，不可编辑或提交',
      ),
    );
  }
  if (_submitStatusUnknown) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SyncStatusBanner(
        state: SyncBannerState.unknown,
        title: '无法确认提交状态',
        description: '编辑已锁定，请检查网络后重试',
        actionLabel: '重试',
        onAction: _loading ? null : _load,
      ),
    );
  }
  if (_isSubmitted) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SyncStatusBanner(
        state: SyncBannerState.ready,
        title: '该记录已提交审核',
        description: '不可修改。如需修改请先撤回提交或联系管理员。',
      ),
    );
  }
  if (isSyncFailed) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SyncStatusBanner(
        state: SyncBannerState.failed,
        title: '存在同步失败数据',
        description: '为避免数据不一致，编辑已锁定',
      ),
    );
  }
  return const SizedBox.shrink();
}
```

- [ ] **Step 18.3: 添加顶部信息卡**

在 `_buildStatusBanner` 调用之后追加 `_buildSummaryCard()` 调用，并实现：

```dart
Widget _buildSummaryCard() {
  final c = context.colors;
  final byClass = <String, List<RecordEntry>>{};
  for (final e in _entries) {
    byClass.putIfAbsent(e.className, () => []).add(e);
  }
  final classNames = byClass.keys.join(' · ');

  int present = 0, absent = 0, late_ = 0, leave = 0, other = 0;
  for (final e in _entries) {
    switch (e.status) {
      case AttendanceStatus.present:
        present++;
        break;
      case AttendanceStatus.absent:
        absent++;
        break;
      case AttendanceStatus.late_:
        late_++;
        break;
      case AttendanceStatus.leave:
        leave++;
        break;
      case AttendanceStatus.other:
        other++;
        break;
      case AttendanceStatus.pending:
        break;
    }
  }

  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  classNames,
                  style: AppTextStyles.h2.copyWith(color: c.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_isSubmitted)
                const StatusPill.success(label: '已提交')
              else if (_isAbandoned)
                const StatusPill.neutral(label: '已放弃')
              else
                const StatusPill.neutral(label: '草稿'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _taskDate ?? '',
            style: AppTextStyles.sm.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 16),
          SegmentedProgressBar(
            totalCount: _entries.length,
            segments: [
              ProgressSegment(value: present, color: c.stateSuccess),
              ProgressSegment(value: absent, color: c.stateDanger),
              ProgressSegment(value: late_, color: c.stateWarning),
              ProgressSegment(value: leave, color: c.stateInfo),
              ProgressSegment(value: other, color: c.textSecondary),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _statText('${_entries.length}', '总数', c.textPrimary),
              if (present > 0) _statText('$present', '到', c.stateSuccess),
              if (absent > 0) _statText('$absent', '缺', c.stateDanger),
              if (late_ > 0) _statText('$late_', '迟', c.stateWarning),
              if (leave > 0) _statText('$leave', '假', c.stateInfo),
              if (other > 0) _statText('$other', '他', c.textSecondary),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _statText(String value, String label, Color color) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        value,
        style: AppTextStyles.withTabular(AppTextStyles.bodyMedium)
            .copyWith(color: color, fontWeight: FontWeight.w600),
      ),
      const SizedBox(width: 2),
      Text(
        label,
        style: AppTextStyles.sm.copyWith(color: context.colors.textSecondary),
      ),
    ],
  );
}
```

- [ ] **Step 18.4: 异常列表行使用 StatusPill**

在 _RecordRow 类（如存在）的 build 中，把现有的状态徽章 Container/Chip 替换为：

```dart
StatusPill(
  variant: switch (entry.status) {
    AttendanceStatus.absent => StatusPillVariant.danger,
    AttendanceStatus.late_ => StatusPillVariant.warning,
    AttendanceStatus.leave => StatusPillVariant.info,
    AttendanceStatus.other => StatusPillVariant.neutral,
    AttendanceStatus.present => StatusPillVariant.success,
    AttendanceStatus.pending => StatusPillVariant.neutral,
  },
  label: switch (entry.status) {
    AttendanceStatus.absent => '缺勤',
    AttendanceStatus.late_ => '迟到',
    AttendanceStatus.leave => '请假',
    AttendanceStatus.other => entry.remark ?? '其他',
    AttendanceStatus.present => '到',
    AttendanceStatus.pending => '未处理',
  },
)
```

- [ ] **Step 18.5: 验证**

Run: `flutter analyze lib/features/records/presentation/record_detail_page.dart`
Expected: 不引入新 error

Run: `flutter test test/`
Expected: All tests passed

手工核对：
- 顶部信息卡（班级 + 状态胶囊 + 进度条 + 数字统计）
- 同步/提交/放弃 4 种状态横幅显示一致
- 异常名单状态使用 StatusPill

- [ ] **Step 18.6: 提交**

```powershell
git add app/lib/features/records/presentation/record_detail_page.dart
git commit -m "refactor(ui): 重做记录详情页 - 信息卡 + 进度条 + StatusPill"
```


---

## Task 19: 端到端验证 + 版本发布

**Files:**
- Modify: `app/pubspec.yaml`
- Modify: `CHANGELOG.md`

- [ ] **Step 19.1: 完整 analyze**

Run: `flutter analyze`（在 `app/` 下）
Expected: 不引入新 error。Info/warning 数量与 v0.7.0 起点（111）持平或减少。

如发现新 error，回到对应 Task 修复后再继续。

- [ ] **Step 19.2: 完整测试**

Run: `flutter test`（在 `app/` 下）
Expected: All tests passed

包含：
- `test/widget_test.dart`（已存在）
- `test/attendance_remote_ds_test.dart`（已存在）
- `test/name_check_reconcile_test.dart`（已存在）
- `test/design_system/app_button_test.dart`（Task 6 新增）

- [ ] **Step 19.3: 手工核对（亮模式）**

启动: `flutter run`（连接设备/模拟器）

依次过：
- [ ] 首页：hero 标题 + 副标题、渐变"开始记名"按钮、secondary "点名"按钮、2 个次入口卡片、同步状态卡（如有未同步项）
- [ ] 记名页：顶部 5 段彩色进度条、segmented 班级切换、紧凑学生卡片（focus 边框为品牌色）、底部"到课"主按钮 + 4 个小状态按钮、当前学生姓名预览
- [ ] 提交页：segmented "提交任务/我的提交"、SyncStatusBanner、可点击的紧凑任务卡片、底部 BottomActionBar
- [ ] 记录详情页：顶部信息卡（班级 + 状态胶囊 + 5 段进度条 + 数字统计）、整合后的状态横幅、异常名单 StatusPill
- [ ] 未改造页面（登录、设置、FAQ、调试、点名、确认、文本生成、周汇总、排行榜）：色彩协调，无显著违和

- [ ] **Step 19.4: 手工核对（暗模式）**

切换系统到暗模式，重复 Step 19.3 全过程。重点检查：
- [ ] 所有文字对比度 >= 4.5:1（肉眼判断：能轻松读清）
- [ ] 卡片边框可见（暗模式无阴影靠边框区分层级）
- [ ] 没有"白底黑字"或反色 bug
- [ ] 状态色（红/绿/橙/蓝）在深色背景下可读
- [ ] 渐变按钮在暗模式下饱和度不刺眼

- [ ] **Step 19.5: 关键交互回归**

至少完整跑一次：
- [ ] 选班级 → 进入记名 → 标记几个学生（含到/缺/迟/假/他）→ 退出保存 → 再进入恢复，状态保留
- [ ] 完成记名 → 进入提交页 → 选任务 → 提交 → 在"我的提交"看到结果
- [ ] 进入记录详情 → 切换编辑模式 → 修改一条记录状态 → 退出后重进，修改保留
- [ ] 主动断网测试：记名页能继续工作，恢复网络后 SyncQueue 自动消费

- [ ] **Step 19.6: bump 版本号**

Modify: `app/pubspec.yaml`

把：
```yaml
version: 0.6.5+29
```
改为：
```yaml
version: 0.7.0+30
```

- [ ] **Step 19.7: 更新 CHANGELOG**

Modify: `CHANGELOG.md`

在 v0.7.0 章节标题处把 `[进行中]` 移除，并在该章节末尾追加：

```markdown
### UI 重设计（设计系统 + 4 核心页）

- 全新 Design System：tokens（间距/圆角/动效）+ AppColors 双主题色板（中性灰 + sky→blue 渐变）+ AppTextStyles 字号阶梯 + buildLightTheme/buildDarkTheme
- 9 个核心组件：AppButton（4 variant × 3 size）/ AppCard / StatusPill / AppInput / AppTopBar / BottomActionBar / AppSegmentedControl / SyncStatusBanner / SegmentedProgressBar
- 首页重做：hero 区 + 渐变主 CTA + 次入口紧凑网格 + 整合后的同步状态卡
- 记名页重做：顶部 5 段彩色进度条 + segmented 班级切换 + 紧凑学生卡片（焦点品牌色边框 + 状态胶囊）+ 当前学生姓名预览
- 提交页重做：SegmentedControl 替代 TabBar + 单一 SyncStatusBanner + 紧凑可选任务卡片 + 固定 BottomActionBar
- 记录详情页重做：顶部信息卡（班级 + 状态胶囊 + 5 段进度条 + 数字统计）+ 4 种状态横幅整合 + StatusPill 替代纯背景色变化
- 旧组件 EntryCard / StatusBadge / EmptyState / LoadingOverlay / Toast 保留 API 兼容，未改造页面继续可用

### 视觉细节

- 字号阶梯采用 8 档（display 28 / h1 22 / h2 18 / h3 16 / body 14 / bodyMedium 14/500 / sm 13 / xs 11）
- 学号、数字栏、时间戳统一使用等宽数字（FontFeature.tabularFigures）
- 圆角默认 6 px（按钮/输入框）+ 8 px（卡片）+ 4 px（标签胶囊），比 M3 默认 12 px 更锐利
- 暗模式弃用阴影，改用 1 px 边框区分层级
- 触摸操作 < 200 ms easeOut，元素位移 < 200 ms easeInOut
```

- [ ] **Step 19.8: 提交版本发布**

```powershell
git add app/pubspec.yaml CHANGELOG.md
git commit -m "release: v0.7.0+30 - UI 重设计（设计系统 + 4 核心页）"
git push origin main
```

---

## Self-Review Checklist

执行计划前，由实施者再过一遍：

- [ ] 所有文件路径与现有 import 写法一致（`'../../../shared/...'`）
- [ ] 所有新组件均被 4 个核心页中至少一处引用（避免死代码）
- [ ] `EntryCard` / `StatusBadge` 未删除（仍被未改造页面使用）
- [ ] `flutter analyze` 不引入新 error
- [ ] `flutter test` 全部通过
- [ ] 暗模式核对完成，无反色 bug
- [ ] 业务逻辑（Notifier / Repository / Service）零修改
- [ ] 所有路由路径未变（防止打破 GoRouter 配置）

如有任意一项不通过，停下来评估根因，不要强行往下推。
