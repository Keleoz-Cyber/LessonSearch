# 邮箱验证码登录功能设计

> 日期：2026-04-04
> 版本：0.3.0

---

## 一、功能概述

实现邮箱验证码登录，支持：
- 固定邀请码验证
- 自动注册（验证成功后自动创建账户）
- 用户数据隔离（每人只看自己的记录）
- 历史无主数据在本地继续展示

---

## 二、数据库变更

### 服务端 MySQL 新增表

**users 表**：
```sql
CREATE TABLE users (
  id INT PRIMARY KEY AUTO_INCREMENT,
  email VARCHAR(100) UNIQUE NOT NULL,
  nickname VARCHAR(50),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  last_login_at DATETIME
);
```

**verification_codes 表**：
```sql
CREATE TABLE verification_codes (
  id INT PRIMARY KEY AUTO_INCREMENT,
  email VARCHAR(100) NOT NULL,
  code VARCHAR(6) NOT NULL,
  expires_at DATETIME NOT NULL,
  used BOOLEAN DEFAULT FALSE,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

### 服务端 MySQL 修改表

**attendance_tasks 表新增字段**：
```sql
ALTER TABLE attendance_tasks ADD COLUMN user_id INT NULL;
ALTER TABLE attendance_tasks ADD INDEX idx_user_id (user_id);
```

### 客户端 SQLite 新增表

**Users 表**：
- id (Int)
- email (Text)
- nickname (Text, nullable)
- createdAt (DateTime)
- lastLoginAt (DateTime, nullable)

### 客户端 SQLite 修改表

**AttendanceTasks 表新增字段**：
- userId (Int, nullable) — 登录后的用户 ID

---

## 三、服务端实现

### 3.1 配置文件新增 (config.py)

```python
# 邀请码（固定，可多个）
INVITATION_CODES = ["lesson2026", "keleoz"]

# JWT 配置
JWT_SECRET = os.getenv("JWT_SECRET", "your-secret-key-change-in-production")
JWT_EXPIRE_HOURS = int(os.getenv("JWT_EXPIRE_HOURS", "168"))  # 7天

# SMTP 配置（发送验证码）
SMTP_HOST = os.getenv("SMTP_HOST", "smtp.qq.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "465"))
SMTP_USER = os.getenv("SMTP_USER", "")  # 发件邮箱
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")  # SMTP密码/授权码
SMTP_FROM = os.getenv("SMTP_FROM", "查课 App")
```

### 3.2 新增路由 (routers/auth.py)

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/auth/send-code` | 发送验证码到邮箱 |
| POST | `/api/auth/login` | 验证码+邀请码登录/注册 |
| GET | `/api/auth/me` | 获取当前用户信息（需 token）|

**发送验证码请求**：
```json
POST /api/auth/send-code
{ "email": "user@example.com" }
```

**登录请求**：
```json
POST /api/auth/login
{ 
  "email": "user@example.com",
  "code": "123456",
  "invitation_code": "lesson2026"
}
```

**登录响应**：
```json
{
  "token": "eyJ...",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "nickname": null,
    "is_new_user": true
  }
}
```

### 3.3 JWT 认证中间件

- 请求头携带：`Authorization: Bearer <token>`
- 验证失败返回 401
- 所有涉及用户数据的接口需要认证

### 3.4 数据隔离

修改现有接口：
- `/api/tasks` — 按 user_id 过滤
- `/api/tasks/{id}` — 验证 user_id 是否匹配
- `/api/tasks/{id}/records` — 验证任务归属

user_id=NULL 的历史数据不返回给任何用户。

---

## 四、客户端实现

### 4.1 新增页面

**登录页 (LoginPage)**：
- 邮箱输入框
- 验证码输入框（6位）
- 邀请码输入框
- "发送验证码"按钮（60秒倒计时）
- "登录"按钮
- 提示：首次登录后数据将仅属于当前账户

**登录入口**：
- 设置页新增"登录/账户"入口
- 首页顶部显示登录状态（邮箱或"未登录")

### 4.2 Token 管理

使用 SharedPreferences 存储：
- `auth_token` — JWT token
- `user_id` — 用户 ID
- `user_email` — 用户邮箱

### 4.3 ApiClient 改造

- 初始化时读取 token
- 请求拦截器自动添加 Authorization 头
- 401 响应时清除 token 并跳转登录页

### 4.4 数据隔离逻辑

**登录后创建任务**：
- AttendanceTask.userId = 当前用户 ID
- 同步时携带 user_id

**本地历史数据（userId=NULL）**：
- 继续在本地展示
- 不同步到服务端（SyncService 跳过 userId=NULL 的任务）
- 显示"本地数据"标签

**登录后拉取服务端数据**：
- 只拉取 user_id 匹配的任务
- 合并到本地数据库

---

## 五、历史数据处理

| 场景 | 处理方式 |
|------|---------|
| 登录前本地数据 | userId=NULL，继续展示，不同步 |
| 登录后新建数据 | userId=当前用户，正常同步 |
| 服务端历史数据（user_id=NULL） | 不返回给客户端，保留在数据库 |
| 多设备登录同一账户 | 服务端数据同步到新设备 |

---

## 六、SMTP 发送验证码

使用 QQ邮箱/163邮箱 SMTP 服务：

1. 用户申请邮箱 SMTP 授权码
2. 配置到服务端 .env
3. Python smtplib 发送 HTML 格式邮件

**邮件内容**：
```
您的查课 App 登录验证码是：123456
验证码5分钟内有效，请勿泄露给他人。
```

---

## 七、流程图

### 登录流程

```
用户输入邮箱 → 点击发送验证码 → 服务端生成6位随机码
    → 存入 verification_codes 表（5分钟有效）
    → SMTP 发送邮件 → 用户收到验证码

用户输入验证码+邀请码 → 点击登录 → 服务端验证：
    1. 验证码是否有效（未过期、未使用）
    2. 邀请码是否在配置列表中
    → 验证成功 → 标记验证码已使用
    → 查询 users 表：
        - 若存在 → 更新 last_login_at，返回 token
        - 若不存在 → 创建用户，返回 token + is_new_user=true
    → 客户端存储 token → 首次登录弹窗提示
    → 拉取服务端数据 → 完成
```

### 数据同步流程（登录后）

```
创建任务 → Repository.createTask(userId=当前用户)
    → LocalDS.insert → SQLite (userId 已填)
    → LocalDS.enqueueSync → SyncQueue
    
SyncService → 读取 SyncQueue → 携带 token 调用 API
    → 服务端验证 token → 创建任务（user_id 从 token 获取）
    → 返回成功 → 标记 synced
    
SyncService 跳过 userId=NULL 的任务（本地历史数据）
```

---

## 八、安全考虑

1. 验证码 5 分钟过期
2. 验证码使用后标记已用，防止重复
3. 同一邮箱 60 秒内只能发送一次验证码
4. JWT token 7 天过期，可刷新
5. 邀请码固定在配置文件，不暴露给客户端

---

## 九、实现优先级

| 阶段 | 内容 |
|------|------|
| P1 | 服务端 auth 路由 + JWT + 数据库变更 |
| P2 | 客户端登录页 + token 管理 |
| P3 | ApiClient 拦截器 + 数据隔离 |
| P4 | 历史数据处理 + UI 提示 |