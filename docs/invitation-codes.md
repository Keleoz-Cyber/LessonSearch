# 邀请码管理指南

## 机制说明

- **一人一码**：每个邀请码只能注册一个新用户
- **注册时需要**：新用户注册必须提供有效邀请码
- **登录时不需要**：老用户登录只需邮箱+验证码
- **账户不存在**：登录时若邮箱未注册，会提示"账户不存在，请先注册"

## 常用指令

### 查看所有邀请码

```bash
docker exec -it $(docker ps | grep mysql | awk '{print $1}') mysql -u lesson_search -p lesson_search -e "SELECT id, code, used, used_by, used_at FROM invitation_codes;"
```

### 查看未使用的邀请码

```bash
docker exec -it $(docker ps | grep mysql | awk '{print $1}') mysql -u lesson_search -p lesson_search -e "SELECT code FROM invitation_codes WHERE used = 0;"
```

### 查看已使用的邀请码及使用者

```bash
docker exec -it $(docker ps | grep mysql | awk '{print $1}') mysql -u lesson_search -p lesson_search -e "SELECT i.code, u.email, i.used_at FROM invitation_codes i JOIN users u ON i.used_by = u.id WHERE i.used = 1;"
```

### 添加单个邀请码

```bash
docker exec -it $(docker ps | grep mysql | awk '{print $1}') mysql -u lesson_search -p lesson_search -e "INSERT INTO invitation_codes (code) VALUES ('your_code');"
```

### 批量添加邀请码

```bash
docker exec -it $(docker ps | grep mysql | awk '{print $1}') mysql -u lesson_search -p lesson_search -e "INSERT INTO invitation_codes (code) VALUES ('code1'),('code2'),('code3');"
```

### 随机生成邀请码

```bash
cd /opt/lesson-search/server
source ../venv/bin/activate
python ../scripts/generate_invitation_codes.py 10
```

### 删除指定邀请码

```bash
docker exec -it $(docker ps | grep mysql | awk '{print $1}') mysql -u lesson_search -p lesson_search -e "DELETE FROM invitation_codes WHERE code = '要删除的码';"
```

### 删除多个邀请码

```bash
docker exec -it $(docker ps | grep mysql | awk '{print $1}') mysql -u lesson_search -p lesson_search -e "DELETE FROM invitation_codes WHERE code IN ('code1','code2','code3');"
```

### 删除所有未使用的随机码（8位字母数字）

```bash
docker exec -it $(docker ps | grep mysql | awk '{print $1}') mysql -u lesson_search -p lesson_search -e "DELETE FROM invitation_codes WHERE used = 0 AND code REGEXP '^[a-z0-9]{8}$';"
```

---

## 用户管理

### 查看所有用户

```bash
docker exec -it $(docker ps | grep mysql | awk '{print $1}') mysql -u lesson_search -p lesson_search -e "SELECT id, email, nickname, created_at, last_login_at FROM users;"
```

### 查看用户数量

```bash
docker exec -it $(docker ps | grep mysql | awk '{print $1}') mysql -u lesson_search -p lesson_search -e "SELECT COUNT(*) as total FROM users;"
```

---

## 快捷脚本

可以将常用命令添加到 `~/.bashrc`：

```bash
# 邀请码管理
alias inv-list='docker exec -it $(docker ps | grep mysql | awk "{print \$1}") mysql -u lesson_search -p lesson_search -e "SELECT id, code, used FROM invitation_codes;"'
alias inv-unused='docker exec -it $(docker ps | grep mysql | awk "{print \$1}") mysql -u lesson_search -p lesson_search -e "SELECT code FROM invitation_codes WHERE used = 0;"'
alias users='docker exec -it $(docker ps | grep mysql | awk "{print \$1}") mysql -u lesson_search -p lesson_search -e "SELECT id, email, created_at FROM users;"'
```

然后执行 `source ~/.bashrc`，之后就可以直接用 `inv-list`、`inv-unused`、`users` 等快捷命令。