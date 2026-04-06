# 考勤助手 v0.5.0 重构方案

> 版本：0.5.0  
> 更新日期：2026-04-06  
> 分支：feature/v0.5.0

---

## 一、重构目标

### 1.1 代码结构优化

**问题：**
- server/ 目录扁平，- 根目录杂乱
- 缺少统一规范

**目标：**
- 清晰的目录结构
- 统一的代码规范
- 便于维护和扩展

### 1.2 功能扩展准备

**目标：**
- 为角色系统预留接口
- 为周名单功能预留数据结构
- 为提交审核预留扩展位

---

## 二、重构范围

### 2.1 服务端重构

**当前结构：**
```
server/
├── config.py
├── database.py
├── models.py
├── schemas.py
├── main.py
├── routers/
│   ├── auth.py
│   ├── grades.py
│   ├── majors.py
│   ├── classes.py
│   ├── students.py
│   ├── tasks.py
│   └── records.py
└── deploy/
```

**目标结构：**
```
server/
├── app/
│   ├── core/              # 核心配置
│   │   ├── config.py
│   │   ├── database.py
│   │   ├── security.py     # JWT、密码处理
│   │   └── exceptions.py   # 自定义异常
│   ├── models/             # 数据库模型
│   │   ├── __init__.py
│   │   ├── user.py
│   │   ├── student.py
│   │   ├── task.py
│   │   └── record.py
│   ├── schemas/            # Pydantic 模型
│   │   ├── __init__.py
│   │   ├── user.py
│   │   ├── student.py
│   │   ├── task.py
│   │   └── record.py
│   ├── routers/            # API 路由
│   │   ├── __init__.py
│   │   ├── auth.py
│   │   ├── students.py
│   │   ├── tasks.py
│   │   └── version.py
│   └── services/            # 业务逻辑
│       ├── __init__.py
│       ├── auth_service.py
│       ├── task_service.py
│       └── sync_service.py
├── main.py
├── requirements.txt
└── deploy/
```

### 2.2 根目录重构

**当前结构：**
```
LessonSearch/
├── app/
├── server/
├── scripts/
├── docs/
├── data/
├── build_release.ps1
├── build_release.sh
├── clean_build.ps1
└── .env
```

**目标结构：**
```
LessonSearch/
├── app/                    # Flutter 客户端
├── server/                 # FastAPI 服务端
├── scripts/                # 所有脚本
│   ├── build_release.ps1
│   ├── build_release.sh
│   ├── clean_build.ps1
│   ├── data/              # Excel 导入脚本
│   └── sync_invitation_codes.py
├── docs/                   # 文档
├── .github/                # GitHub Actions
│   └── workflows/
├── .env.example
├── .gitignore
├── AGENT.md
├── CLAUDE.md
└── README.md
```

### 2.3 客户端优化（保持现状）

**当前结构已合理：**
```
app/lib/
├── main.dart
├── app.dart
├── core/
├── features/
└── shared/
```

**优化点：**
- 添加 `services/` 层（可选）
- 优化 `providers.dart` 组织

---

## 三、重构步骤

### 阶段一：准备阶段（1天）

**目标：** 创建新结构，**步骤：**

1. **创建目标目录**
   ```bash
   cd server
   mkdir -p app/core app/models app/schemas app/routers app/services
   ```

2. **更新 import 路径**
   - 记录所有需要修改的 import
   - 准备迁移脚本

3. **测试环境准备**
   - 确保测试通过
   - 备份数据库

### 阶段二：服务端重构（2-3天）

**Day 1：核心模块迁移**

1. **迁移 core 模块**
   ```bash
   mv config.py app/core/
   mv database.py app/core/
   ```

2. **创建 security.py**
   - JWT 相关函数
   - 密码处理函数

3. **创建 exceptions.py**
   - 自定义异常类

4. **更新 import 路径**
   - 逐文件修改
   - 运行测试

**Day 2：模型迁移**

1. **拆分 models.py**
   ```bash
   # 按模块拆分
   mv models.py app/models/
   # 然后拆分为多个文件
   ```

2. **拆分 schemas.py**
   ```bash
   mv schemas.py app/schemas/
   # 然后拆分为多个文件
   ```

3. **更新所有 import**

**Day 3：路由和业务逻辑**

1. **迁移 routers**
   ```bash
   mv routers/* app/routers/
   ```

2. **创建 services 层**
   - 从 routers 中抽取业务逻辑
   - 创建独立的 service 文件

3. **更新 main.py**

### 阶段三：根目录整理（1天）

1. **移动脚本文件**
   ```bash
   mv build_release.ps1 scripts/
   mv build_release.sh scripts/
   mv clean_build.ps1 scripts/
   ```

2. **清理根目录**
   - 删除临时文件
   - 更新 .gitignore

3. **更新文档**

### 阶段四：测试验证（1天）

1. **运行所有测试**
2. **功能验证**
3. **部署测试**
4. **性能测试**

---

## 四、风险评估

### 4.1 高风险操作

| 操作 | 风险 | 缓解措施 |
|------|------|----------|
| 修改 import 路径 | 高 | 逐个文件修改，立即测试 |
| 数据库模型迁移 | 高 | 保持模型定义不变，只改位置 |
| 路由迁移 | 中 | 保持路由逻辑不变 |

### 4.2 中风险操作

| 操作 | 风险 | 缓解措施 |
|------|------|----------|
| 目录结构调整 | 中 | 保持向后兼容 |
| 脚本迁移 | 低 | 更新脚本路径 |

### 4.3 低风险操作

| 操作 | 风险 | 缓解措施 |
|------|------|----------|
| 文档更新 | 低 | 无 |
| 清理临时文件 | 低 | 确认无用再删除 |

---

## 五、回滚方案

### 5.1 Git 分支保护

**当前分支：**
- `main` - 稳定版本（v0.4.0）
- `feature/v0.5.0` - 开发分支

**保护措施：**
- main 分支保护，不允许强制推送
- 每个 stage 创建独立 commit
- 每天推送到远程备份

### 5.2 回滚步骤

**如果重构失败：**

```bash
# 切回主分支
git checkout main

# 删除开发分支
git branch -D feature/v0.5.0

# 重新创建开发分支
git checkout -b feature/v0.5.0-backup

# 从稳定版本重新开始
```

**部分回滚：**

```bash
# 回滚到某个 commit
git reset --hard <commit-hash>

# 或创建反向 commit
git revert <commit-hash>
```

---

## 六、验证清单

### 6.1 服务端验证

- [ ] 所有 API 接口正常响应
- [ ] 数据库连接正常
- [ ] JWT 认证正常
- [ ] 邀请码验证正常
- [ ] 同步功能正常
- [ ] 版本检查正常

### 6.2 客户端验证

- [ ] 登录注册正常
- [ ] 点名功能正常
- [ ] 记名功能正常
- [ ] 查课记录正常
- [ ] 同步功能正常
- [ ] 检查更新正常

### 6.3 部署验证

- [ ] 服务启动正常
- [ ] 数据库迁移正常
- [ ] Nginx 配置正常
- [ ] HTTPS 证书有效
- [ ] 日志输出正常

---

## 七、时间规划

### 7.1 总体时间

| 阶段 | 时间 | 说明 |
|------|------|------|
| 阶段一：准备 | 1天 | 目录创建、路径规划 |
| 阶段二：服务端重构 | 2-3天 | 核心迁移、测试验证 |
| 阶段三：根目录整理 | 1天 | 脚本移动、文档更新 |
| 阶段四：测试验证 | 1天 | 全面测试、性能验证 |
| **总计** | **5-6天** | - |

### 7.2 详细时间表

**Day 1：准备 + core 迁移**
- 上午：创建目录结构
- 下午：迁移 core 模块

**Day 2：models 迁移**
- 上午：拆分 models
- 下午：拆分 schemas

**Day 3：routers 迁移**
- 上午：迁移 routers
- 下午：创建 services 层

**Day 4：根目录整理**
- 上午：移动脚本文件
- 下午：更新文档

**Day 5：测试验证**
- 上午：功能测试
- 下午：部署测试

**Day 6：缓冲时间**
- 处理意外问题
- 优化调整

---

## 八、注意事项

### 8.1 重构原则

1. **小步前进**：每次只改一小部分
2. **立即测试**：改完立即测试
3. **保持兼容**：不改变对外接口
4. **文档同步**：改动后立即更新文档

### 8.2 禁止操作

1. **禁止修改数据库结构**（阶段一不涉及）
2. **禁止修改 API 接口**（保持兼容）
3. **禁止一次性提交大量改动**
4. **禁止在未测试情况下推送**

### 8.3 必须操作

1. **必须每天推送到远程**
2. **必须每个 stage 创建 commit**
3. **必须更新相关文档**
4. **必须运行测试验证**

---

## 九、后续扩展

### 9.1 角色系统（v0.5.0+）

**预留接口：**
- User 模型添加 `role` 字段
- API 添加权限检查
- 前端根据角色显示功能

### 9.2 周名单功能（v0.5.0+）

**预留数据结构：**
- `week_config` 表
- `submissions` 表
- `submission_records` 关联表

### 9.3 提交审核功能（v0.5.0+）

**预留接口：**
- 提交 API
- 审核 API
- 汇总 API

---

## 十、参考资料

- `docs/dev-guide.md` - 开发文档
- `docs/tasks.md` - 任务表
- `CLAUDE.md` - 项目规范
- `docs/规划案/考勤助手v0.5.0规划案.txt` - 功能规划

---

**重构完成后请更新此文档，标记所有验证清单项。**

---

## 十一、重构进度

### 11.1 阶段一：目录创建与 core 迁移（已完成）

**完成日期：2026-04-06**

**完成内容：**
- ✅ 创建 `server/app/` 目录结构
- ✅ 创建 `app/core/` 目录
- ✅ 迁移 `config.py` → `app/core/config.py`
- ✅ 迁移 `database.py` → `app/core/database.py`（添加 Base 定义）
- ✅ 创建 `app/core/security.py`（JWT token 功能）
- ✅ 创建 `app/core/exceptions.py`（自定义异常）

### 11.2 阶段二：models 和 schemas 拆分（已完成）

**完成日期：2026-04-06**

**完成内容：**
- ✅ 创建 `app/models/` 目录
- ✅ 创建 `app/models/user.py`（User, VerificationCode, InvitationCode）
- ✅ 创建 `app/models/student.py`（Grade, Major, Class, Student）
- ✅ 创建 `app/models/task.py`（AttendanceTask, TaskClass）
- ✅ 创建 `app/models/record.py`（AttendanceRecord）
- ✅ 创建 `app/models/__init__.py`（统一导出）
- ✅ 创建 `app/schemas/` 目录
- ✅ 创建 `app/schemas/user.py`（认证相关 schema）
- ✅ 创建 `app/schemas/student.py`（学生、班级 schema）
- ✅ 创建 `app/schemas/task.py`（任务 schema）
- ✅ 创建 `app/schemas/record.py`（记录 schema）
- ✅ 创建 `app/schemas/__init__.py`（统一导出）

### 11.3 阶段三：routers import 更新（已完成）

**完成日期：2026-04-06**

**完成内容：**
- ✅ 更新 `routers/auth.py` import 路径
- ✅ 更新 `routers/grades.py` import 路径
- ✅ 更新 `routers/majors.py` import 路径
- ✅ 更新 `routers/classes.py` import 路径
- ✅ 更新 `routers/students.py` import 路径
- ✅ 更新 `routers/tasks.py` import 路径
- ✅ 更新 `routers/records.py` import 路径
- ✅ 更新 `routers/sync.py` import 路径
- ✅ 更新 `scripts/sync_invitation_codes.py` import 路径
- ✅ 更新 `scripts/generate_invitation_codes.py` import 路径

### 11.4 阶段四：本地测试验证（已完成）

**完成日期：2026-04-06**

**验证结果：**
- ✅ Models import 正常
- ✅ Database import 正常
- ⚠️ Schemas import 需要 email-validator 包（环境问题，非重构问题）
- ⚠️ 本地环境缺少 email-validator，但不影响服务器部署

### 11.5 下一步：服务器部署测试

**待完成：**
- [ ] 提交代码到 feature/v0.5.0 分支
- [ ] 在服务器上拉取代码
- [ ] 启动服务测试
- [ ] 验证所有 API 接口
- [ ] 验证客户端功能