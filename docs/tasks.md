# 考勤助手 — 开发任务表

> 更新日期：2026-04-11
> 当前版本：0.5.0 (重构完成，功能开发待实施)

---

## 已完成

### P0-P23：v0.4.0 正式版发布 ✅

详见历史记录（已完成所有基础功能）

---

### P24：v0.5.0 代码重构 ✅ (2026-04-11)

**重构目标：**
- 清晰的目录结构
- 统一的代码规范
- 为v0.5.0功能扩展预留接口

**重构内容：**
- ✅ 服务端目录重构：`server/app/` 结构（core/models/schemas/routers/services）
- ✅ Models拆分：user.py, student.py, task.py, record.py
- ✅ Schemas拆分：user.py, student.py, task.py, record.py
- ✅ Core模块：config.py, database.py, security.py, exceptions.py
- ✅ 根目录整理：脚本移至 `scripts/`
- ✅ 文档整理：删除重复文档，合并build-outputs.md到dev-guide.md

**部署验证：**
- ✅ 服务器部署完成（2026-04-11）
- ✅ API测试通过
- ✅ 客户端测试通过
- ✅ 兼容性验证：v0.4.0客户端可继续使用

**发现并修复的问题：**
- ✅ config.py .env路径修复（2级目录）
- ✅ auth.py HTML邮件模板恢复（粉色主题）

**已合并到main分支**

---

### P25：v0.5.0 Bug修复与改进 ✅ (2026-04-11)

**Bug修复（4项）：**

| 编号 | 问题 | 修复方案 |
|------|------|----------|
| B1 | 记名重新编辑自动跳转班级 | 新增 `isEditing` 状态标记，编辑模式下不自动跳转 |
| B2 | iOS 微信/QQ检测失败 | 添加 `LSApplicationQueriesSchemes` 声明 |
| B3 | 查课记录编辑滚动位置丢失 | 用 `recordId` 直接更新条目，不全量刷新 |
| B4 | 查课记录编辑索引错位 | 用 `recordId` 查找正确条目，不依赖列表索引 |

**功能改进（4项）：**

| 编号 | 改进 | 说明 |
|------|------|------|
| I1 | 点名记录两列布局 | 使用 Wrap + LayoutBuilder 实现响应式两列 |
| I2 | 学委汇报按班级分开复制 | 文本生成页+查课记录页，每个班级独立卡片 |
| I3 | 状态标签统一 | "到"改为"到课"，与其他两字状态统一 |
| I4 | 点名上一个+预览界面 | 上一个按钮撤销记录，预览区显示已点+下一位 |

**涉及文件：**
- `name_check_notifier.dart` - 新增 isEditing 状态
- `name_check_page.dart` - 编辑模式检查
- `Info.plist` - iOS URL Scheme声明
- `record_detail_page.dart` - 滚动位置保持+学委分开复制+两列布局
- `records_repository.dart` - RecordEntry copyWith方法
- `text_gen_page.dart` - 学委汇报按班级分开复制
- `roll_call_notifier.dart` - prevStudent方法+预览getter
- `roll_call_page.dart` - 上一个按钮+预览界面
- `attendance_repository.dart` - deleteRecord方法
- `attendance_local_ds.dart` - deleteRecord方法

---

## 待实施

### P26：v0.5.0 功能开发（按阶段实施）

详见 `docs/v0.5.0功能开发计划.md`

| 阶段 | 内容 | 优先级 | 可行度 |
|------|------|--------|--------|
| 阶段一 | 数据库设计（新表） | 高 | 95% |
| 阶段二 | 后端API开发 | 高 | 85% |
| 阶段三 | 前端页面开发 | 高 | 80% |
| 阶段四 | 数据隔离（登出清空） | 高 | 95% |
| 阶段五 | 审核流程 | 中 | 80% |
| 阶段六 | Excel导出 | 中 | 85% |
| 阶段七 | 职务分配 | 低 | 95% |

**核心功能：**
- 实名制系统（登录后填姓名）
- 周次配置（每周一为新周）
- 记名提交审核
- 周名单汇总导出
- 职务分配管理
- 实时公告

**其他待实施：**

| 项目 | 说明 | 优先级 |
|------|------|--------|
| 文本模板配置化 | 目前是代码常量，应支持用户自定义 | 中 |
| 数据导出 | Excel/PDF 导出考勤数据 | 中 |
| 统计分析 | 缺勤趋势、班级对比图表 | 低 |
| 跨设备同步 | 登录后从服务端拉取数据 | 低 |
| 后台Web系统 | 管理员Web界面（v0.6.0或v1.0.0） | 低 |

---

## 已知问题

- SyncService 在主 isolate，大量同步时可能微卡
- 记名恢复后 remark 字段可能丢失（fromString 映射）

---

## 版本历史

| 版本 | 发布日期 | 主要内容 |
|------|----------|----------|
| v0.4.0 | 2026-04-06 | 正式版发布，多班级滑动切换 |
| v0.5.0 | 2026-04-11 | 重构完成，功能开发待实施 |
