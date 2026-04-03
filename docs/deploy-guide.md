# 查课 App 服务端部署指南（1Panel + 子域名方案）

> 适用环境：已有 1Panel + Halo 博客的服务器，2C/2G/40G 配置
> 更新日期：2026-04-02

---

## 建议先确认的信息

在开始之前，请先在服务器上确认以下信息，以便判断哪些步骤可跳过：

```bash
# 1. Python 版本
python3 --version

# 2. MySQL 是否存在（1Panel 通常自带）
mysql --version
# 或者在 1Panel 面板 → 数据库 中查看

# 3. 1Panel 版本
1pctl version

# 4. 现有 Nginx 是否由 1Panel 管理
# 在 1Panel → 网站 中查看是否已有你的博客站点
```

---

## 第一部分：旧指南中哪些内容可保留

| 旧步骤 | 状态 | 说明 |
|--------|------|------|
| 上传 server/ 到服务器 | **保留** | 方式不变，scp 或 git clone |
| 安装 Python | **视情况** | 如果 `python3 --version` 已有 3.10+，跳过 |
| 安装 MySQL | **删除** | 1Panel 自带 MySQL，不要重复安装 |
| 安装 Nginx | **删除** | 1Panel 管理 OpenResty/Nginx，不要手动装 |
| 创建 MySQL 数据库和用户 | **保留** | 但通过 1Panel 面板操作更安全 |
| 配置 .env | **保留** | 内容不变 |
| 建表 | **保留** | 命令不变 |
| 手动启动 uvicorn 测试 | **保留** | 监听地址改为 `127.0.0.1:8000` |
| 配置 systemd | **保留** | service 文件已更新为轻量版（1 worker + 内存限制） |
| 手动编辑 Nginx 配置 | **删除** | 改为通过 1Panel 创建反向代理网站 |
| 开放 8000 端口 | **删除** | 不暴露 uvicorn 到公网，只开 80/443 |
| Flutter baseUrl 写 IP | **替换** | 改为 `https://api.你的域名/api` |

---

## 第二部分：推荐部署方案说明

### 架构

```
Flutter App
    ↓ HTTPS
https://api.你的域名
    ↓ 1Panel 反向代理（自动 HTTPS）
127.0.0.1:8000 (uvicorn, systemd 管理)
    ↓
MySQL (1Panel 内置)
```

### 为什么用子域名

- 主域名已被 Halo 博客占用，不能抢
- `api.你的域名` 作为独立站点，在 1Panel 中是独立网站，互不影响
- 博客和 API 各自有独立的 HTTPS 证书、独立的日志、独立的配置

### 为什么 FastAPI 只监听 127.0.0.1:8000

- 不暴露 uvicorn 到公网，安全
- 所有外部流量走 1Panel 管理的 Nginx 反向代理
- 公网只开放 80/443

### 为什么让 1Panel 做反向代理

- 1Panel 已经在管理 Nginx，手动编辑配置文件容易和 1Panel 冲突
- 1Panel 可以一键申请 Let's Encrypt 证书
- 1Panel 的"反向代理网站"功能就是为这个场景设计的

### Flutter 应改用什么地址

```dart
static const String defaultBaseUrl = 'https://api.你的域名/api';
```

- 使用 HTTPS，Android 9+ 默认阻止明文 HTTP
- 使用域名而非 IP，方便后续更换服务器

---

## 第三部分：本机需要准备的内容

### 需要上传到服务器的文件

```
server/                      # 整个目录
├── config.py
├── database.py
├── models.py
├── schemas.py
├── main.py
├── requirements.txt
├── .env.example
├── routers/
│   ├── __init__.py
│   ├── grades.py
│   ├── majors.py
│   ├── classes.py
│   ├── students.py
│   ├── tasks.py
│   └── records.py
└── deploy/
    └── lesson-search.service

scripts/                     # 如果需要在服务器导入学生数据
├── config.py
├── models.py
├── excel_analyzer.py
├── excel_importer.py
├── init_db.py
└── requirements.txt

data/考勤表/                  # 如果需要在服务器导入
```

### 不需要上传

- `app/` — Flutter 客户端代码留在本机
- `server/deploy/nginx-lesson-search.conf` — 不需要，用 1Panel 配置
- `server/__pycache__/` — 不需要
- `.env` — 不要上传真实密码文件，服务器上单独创建

### Flutter ApiClient 修改

文件：`app/lib/core/network/api_client.dart`

```dart
// 部署后改成：
static const String defaultBaseUrl = 'https://api.你的域名/api';
```

**暂时先不改**，等服务器部署验证通过后再改。

### 不需要修改的文件

- `server/requirements.txt` — 已包含所有依赖
- `server/.env.example` — 已更新
- `server/deploy/lesson-search.service` — 已更新为轻量版

---

## 第四部分：服务器端操作步骤

### 步骤 1：检查现有环境

```bash
# Python
python3 --version
# 需要 3.10+，如果没有：sudo apt install -y python3 python3-pip python3-venv

# MySQL — 在 1Panel 面板 → 数据库 中确认 MySQL 存在并运行
# 如果 1Panel 面板里有 MySQL，不要用 apt 再装一个

# 1Panel
1pctl version
# 确认 1Panel 正常运行

# 检查 8000 端口是否已被占用
ss -tlnp | grep 8000
# 应该没有输出。如果有，换一个端口（如 8001）
```

### 步骤 2：上传项目

```bash
# 在你的本机执行（Windows Git Bash / PowerShell）
scp -r server/ root@你的服务器IP:/opt/lesson-search/server/
scp -r scripts/ root@你的服务器IP:/opt/lesson-search/scripts/

# 如果需要在服务器导入学生数据：
scp -r data/ root@你的服务器IP:/opt/lesson-search/data/
```

或者用 Git：
```bash
# 本机
git add server/ scripts/
git commit -m "chore: add server deployment files"
git push

# 服务器
cd /opt
git clone https://github.com/Keleoz-Cyber/LessonSearch lesson-search
```

### 步骤 3：创建虚拟环境

```bash
# SSH 到服务器
cd /opt/lesson-search
python3 -m venv venv
source venv/bin/activate
pip install -r server/requirements.txt
```

### 步骤 4：通过 1Panel 创建 MySQL 数据库

**不要用命令行操作**，通过 1Panel 面板操作更安全：

1. 打开 1Panel 面板
2. 左侧菜单 → **数据库**
3. 点击 **创建数据库**
4. 填写：
   - 数据库名：`lesson_search`
   - 用户名：`lesson_search`
   - 密码：自己设一个强密码，**记下来**
   - 权限：本地（localhost）
   - 字符集：`utf8mb4`
5. 点击确认

### 步骤 5：配置 .env

```bash
cd /opt/lesson-search/server
cp .env.example .env
nano .env
```

填写：
```
DB_HOST=localhost
DB_PORT=3306
DB_USER=lesson_search
DB_PASSWORD=步骤4中设置的密码
DB_NAME=lesson_search
```

> 注意：1Panel 安装的 MySQL 端口可能不是 3306。在 1Panel → 数据库 → 设置中确认实际端口。

### 步骤 6：建表

```bash
cd /opt/lesson-search
source venv/bin/activate
cd server
python -c "from models import Base; from database import engine; Base.metadata.create_all(engine); print('建表成功')"
```

如果报错 `Can't connect to MySQL`：
- 检查 .env 中的端口和密码
- 1Panel 的 MySQL 可能监听在 `/var/run/mysqld/mysqld.sock` 而非 TCP，这时把 DB_HOST 改成 `127.0.0.1`

### 步骤 7：导入学生数据（可选）

```bash
cd /opt/lesson-search/scripts
pip install -r requirements.txt
cp ../server/.env .env

# 先预览
python excel_importer.py

# 正式导入
python excel_importer.py --commit
```

### 步骤 8：手动测试 FastAPI

```bash
cd /opt/lesson-search/server
source ../venv/bin/activate

# 手动启动（前台运行，用于测试）
uvicorn main:app --host 127.0.0.1 --port 8000

# 另开一个 SSH 窗口测试：
curl http://127.0.0.1:8000/health
# 预期：{"status":"ok"}

curl http://127.0.0.1:8000/api/grades
# 预期：[{"id":1,"name":"2022级","year":2022}, ...]

# 测试通过后 Ctrl+C 停掉
```

### 步骤 9：配置 systemd 服务

```bash
sudo cp /opt/lesson-search/server/deploy/lesson-search.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl start lesson-search
sudo systemctl enable lesson-search

# 验证
sudo systemctl status lesson-search
# 应显示 active (running)

# 再次验证接口
curl http://127.0.0.1:8000/health
```

### 步骤 10：域名解析

到你的域名注册商（阿里云/腾讯云/Cloudflare 等）：

1. 添加一条 **A 记录**：
   - 主机记录：`api`
   - 记录类型：A
   - 记录值：你的服务器 IP
   - TTL：默认或 600

2. 等待解析生效（通常 1-5 分钟）

3. 验证：
   ```bash
   # 在你的电脑上
   ping api.你的域名
   # 应该解析到你的服务器 IP
   ```

### 步骤 11：在 1Panel 创建反向代理网站

**详见第五部分。**

### 步骤 12：配置 HTTPS

**详见第五部分。**

### 步骤 13：验证子域名可访问

```bash
# 从你的电脑上
curl https://api.你的域名/health
# 预期：{"status":"ok"}

# 浏览器访问
# https://api.你的域名/docs
# 应该看到 Swagger UI
```

### 步骤 14：修改 Flutter baseUrl

```dart
// app/lib/core/network/api_client.dart
static const String defaultBaseUrl = 'https://api.你的域名/api';
```

---

## 第五部分：1Panel 中具体操作

### 创建反向代理网站

1. 打开 1Panel 面板
2. 左侧菜单 → **网站**
3. 点击 **创建网站**
4. 选择类型：**反向代理**
5. 填写：
   - 主域名：`api.你的域名`
   - 代理地址：`http://127.0.0.1:8000`
6. 点击确认

此时 1Panel 会自动：
- 在 OpenResty/Nginx 中生成一个 server block
- 监听 80 端口，server_name 为 `api.你的域名`
- 将请求 proxy_pass 到 `http://127.0.0.1:8000`

### 配置 HTTPS

1. 在 **网站列表** 中找到刚创建的 `api.你的域名`
2. 点击右侧 **设置**（或网站名进入详情）
3. 切换到 **HTTPS** 标签页
4. 选择 **申请证书**
5. 提供商选 **Let's Encrypt** 或 **ZeroSSL**
6. 申请方式选 **HTTP 验证**（域名已解析到服务器即可）
7. 勾选 **自动续签**
8. 点击申请

申请成功后：
- 1Panel 会自动配置 SSL 证书
- 自动配置 HTTP → HTTPS 跳转
- 你不需要手动编辑任何 Nginx 配置文件

### 如何避免影响 Halo 博客

- Halo 博客使用**主域名**（如 `example.com`），API 使用**子域名**（如 `api.example.com`）
- 在 1Panel 中它们是**两个独立的网站**，各自有独立配置
- 创建 API 网站时只要域名填的是 `api.你的域名`，就不会碰到博客的配置
- 两个网站各自有独立的 HTTPS 证书

### 验证 API 子域名正常工作

创建并配置 HTTPS 后，在你的电脑上：

```bash
# HTTP 应该自动跳转到 HTTPS
curl -I http://api.keleoz.cn/health
# 预期：301 或 302 跳转到 https://

# HTTPS 直接访问
curl https://api.keleoz.cn/health
# 预期：{"status":"ok"}

# 确认博客没受影响
curl https://keleoz.cn
# 预期：正常返回博客页面
```

---

## 第六部分：MySQL 处理

### 如果 1Panel 已有 MySQL（最常见情况）

直接在 1Panel 面板 → 数据库 → 创建数据库即可，**不需要任何额外安装**。

只需要：
1. 创建数据库 `lesson_search`（utf8mb4）
2. 创建用户 `lesson_search`，授权给该数据库
3. 记下密码，填到 `.env`

### 如何确认 1Panel MySQL 的连接信息

在 1Panel → 数据库 → 右上角设置：
- 查看端口号（默认 3306，但 1Panel 可能改过）
- 查看 root 密码（如果需要命令行操作）
- 查看 socket 路径

### .env 中应该填什么

```
DB_HOST=127.0.0.1        # 不要填 localhost，某些 MySQL 配置下 localhost 走 socket 而非 TCP
DB_PORT=3306             # 从 1Panel 数据库设置中确认
DB_USER=lesson_search
DB_PASSWORD=你设的密码
DB_NAME=lesson_search
```

### 验证数据库连接

```bash
cd /opt/lesson-search
source venv/bin/activate
cd server
python -c "
from database import engine
from sqlalchemy import text
with engine.connect() as conn:
    conn.execute(text('SELECT 1'))
    print('数据库连接成功')
"
```

### 什么时候需要重新安装 MySQL

**几乎不需要。** 只有以下情况才考虑：
- 服务器上完全没有 MySQL（极少见，1Panel 默认装了）
- 现有 MySQL 版本低于 5.7（不支持 utf8mb4）
- 现有 MySQL 已损坏无法启动

---

## 第七部分：2GB 内存轻量化建议

### uvicorn 配置

```
--workers 1              # 不要开多个 worker，1 个足够
--limit-max-requests 1000  # 每处理 1000 个请求自动重启，防内存泄漏
```

已写入 `lesson-search.service`。

### systemd 内存限制

```ini
MemoryMax=256M           # 已写入 service 文件，硬限 256MB
```

FastAPI + uvicorn 空载约 50MB，满载约 80-120MB，256M 绰绰有余。

### 不要重复部署的服务

| 服务 | 说明 |
|------|------|
| MySQL | 用 1Panel 自带的，不要再装 |
| Nginx/OpenResty | 用 1Panel 管理的，不要再装 |
| Redis | 当前不需要，不要装 |
| Docker | 1Panel 自带，API 不需要容器化部署 |

### 内存分配参考（2GB 总量）

| 组件 | 预估内存 |
|------|---------|
| 系统 + sshd | ~200MB |
| 1Panel | ~100MB |
| MySQL | ~300-500MB |
| OpenResty/Nginx | ~30MB |
| Halo 博客（Java） | ~400-600MB |
| **FastAPI (lesson-search)** | **~80-120MB** |
| 剩余 | ~200-400MB |

如果内存紧张：
- Halo 是内存大户，考虑给 Halo 设置 JVM 内存上限（如 `-Xmx512m`）
- FastAPI 已限制 256M
- 开 swap：`sudo fallocate -l 1G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile`

### 日志轻量化

```bash
# systemd 日志默认会自动轮转，不需要额外配置
# 如果想限制日志大小：
sudo journalctl --vacuum-size=100M
```

---

## 第八部分：部署后验证

### 服务器本机验证

```bash
# 1. 服务状态
sudo systemctl status lesson-search
# 预期：active (running)

# 2. 健康检查
curl http://127.0.0.1:8000/health
# 预期：{"status":"ok"}

# 3. 查询数据
curl http://127.0.0.1:8000/api/grades
# 预期：年级列表 JSON

# 4. 创建任务
curl -X POST http://127.0.0.1:8000/api/tasks \
  -H 'Content-Type: application/json' \
  -d '{"id":"deploy-test","type":"roll_call","class_ids":[1]}'
# 预期：201 Created

# 5. 查询任务
curl http://127.0.0.1:8000/api/tasks/deploy-test
# 预期：返回任务 JSON，record_count=0

# 6. 清理测试数据
cd /opt/lesson-search && source venv/bin/activate
python -c "
from server.database import SessionLocal
from server.models import AttendanceTask
db = SessionLocal()
t = db.query(AttendanceTask).filter(AttendanceTask.id == 'deploy-test').first()
if t:
    db.delete(t)
    db.commit()
    print('已清理')
"
```

### 外网验证（你的电脑上执行）

```bash
# 1. HTTPS 健康检查
curl https://api.你的域名/health
# 预期：{"status":"ok"}

# 2. Swagger 文档（浏览器打开）
# https://api.你的域名/docs

# 3. 查询年级
curl https://api.你的域名/api/grades

# 4. 创建任务
curl -X POST https://api.你的域名/api/tasks \
  -H 'Content-Type: application/json' \
  -d '{"id":"remote-test","type":"roll_call","class_ids":[1]}'
```

### Flutter 联调验证

1. 修改 `api_client.dart`：
   ```dart
   static const String defaultBaseUrl = 'https://api.你的域名/api';
   ```

2. 运行 App，观察：
   - 首页正常加载 → 基础连通OK
   - 后续接入选择页/点名流程时，数据来自远程服务器

---

## 第九部分：常见错误排查

### 1. systemd 服务没起来

```bash
sudo systemctl status lesson-search
sudo journalctl -u lesson-search -n 30 --no-pager
```

常见原因：
- `.env` 路径不对 → 确认 `/opt/lesson-search/server/.env` 存在
- Python 路径不对 → 确认 `/opt/lesson-search/venv/bin/uvicorn` 存在
- 权限问题 → `sudo chown -R www-data:www-data /opt/lesson-search`

### 2. MySQL 连接失败

```bash
# 手动测试连接
mysql -u lesson_search -p -h 127.0.0.1 -P 3306 lesson_search
```

常见原因：
- 端口不是 3306 → 在 1Panel 数据库设置中确认
- 用户密码不对 → 在 1Panel 中重置密码
- DB_HOST 写了 `localhost` → 改成 `127.0.0.1`

### 3. 子域名无法访问（但 localhost:8000 正常）

检查顺序：
```bash
# DNS 是否生效
ping api.你的域名
# 应该解析到服务器 IP

# 1Panel 网站是否创建成功
# 在 1Panel → 网站 列表中确认 api.你的域名 存在

# Nginx 配置是否正确
sudo nginx -t
# 或 1Panel 使用的 OpenResty：
sudo /usr/local/openresty/bin/openresty -t
```

### 4. HTTPS 证书问题

- 证书申请失败 → 确认 DNS 已解析、80 端口可访问
- 证书过期 → 1Panel 勾选了自动续签的话不会过期
- 浏览器提示不安全 → 可能是证书还没生效，等几分钟

### 5. 502 Bad Gateway

说明 Nginx/OpenResty 启动了，但后端没有响应：
```bash
# 检查 uvicorn 是否在运行
ss -tlnp | grep 8000
# 应该有一行 127.0.0.1:8000

# 如果没有，重启服务
sudo systemctl restart lesson-search
```

### 6. Halo 博客受影响

- API 站点和博客站点在 1Panel 中是**独立的网站**
- 如果博客访问异常，检查 1Panel → 网站中博客站点的配置是否被改动
- 创建 API 站点时不要修改任何博客相关的配置

### 7. Flutter 仍然请求旧地址

- 确认 `api_client.dart` 中的 `defaultBaseUrl` 已改
- `flutter clean && flutter run` 重新编译
- 安卓模拟器中 `10.0.2.2` 只能访问宿主机，不能访问远程服务器
