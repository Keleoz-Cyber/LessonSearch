# LessonSearch 服务端上线准备

适用于 0.7.1 FastAPI 服务、`www-data` systemd 账号、Docker MySQL 和 OpenResty。以下命令是运维模板，不表示已经完成目标环境的备份或迁移；必须根据实际部署核对，不应未经评审重复执行迁移或恢复。生产发布记录、数据库清单和备份位置应保存在私有运维记录中。

## 升级前检查

先只读核对系统和数据库版本、活动代码目录、API 版本、表结构和定时任务。模板中 API 监听 `127.0.0.1:8000`，数据库仅映射本机；其他环境应显式替换容器名和目录。

配置文件须仅允许运维账号和服务账号读取，例如 `root:www-data 0640`。SSH、面板访问、云防火墙及密钥轮换应单独评审，不随应用升级擅自变更。

代码或配置文件的 `.bak` 不是数据库备份。必须核对近期逻辑备份和隔离恢复结果，另行落实异地副本、保留策略及云快照。

## 本次服务端变化

- API 和健康检查统一版本 `0.7.1`，健康响应声明学期隔离、记录删除及工作流结束能力；保留旧客户端的 PUT 更新入口，不放宽认证和任务归属。
- `/api/version` 只返回稳定发布中实际存在的 APK，不推测镜像下载链接。发布顺序为完成测试、上传签名 APK、核对公开下载，再同步服务端版本与公告。公告序号是独立递增整数，不是应用版本号。
- `/health` 是存活检查，不访问数据库；`/health/db` 执行 `SELECT 1`，失败返回 `503`，不回传连接异常文本；`/health/ready` 再检查新增表列、学期非空约束和外键，未完成升级时返回 `503`。
- 配置优先使用 `LESSONSEARCH_ENV_FILE` 指定的文件，否则依次使用 `server/.env`、项目根 `.env`；系统已注入的环境变量不被覆盖。数据库使用 SQLAlchemy URL 对象处理原始凭据中的特殊字符，不把真实密码拼接到字符串或日志。[SQLAlchemy 文档](https://docs.sqlalchemy.org/en/20/core/engines.html#creating-urls-programmatically)
- 生产模式拒绝默认或不足 32 字符的 JWT 密钥以及空数据库密码。不要直接覆盖现有 `.env`：先核对已有配置；变更 JWT 密钥会使现有 Token 失效。示例中的应用数据库账号不代表生产已创建该账号。

## 只读预检

以下命令在已获得检查授权、且新代码已经按批准流程放入目标环境后，由服务账号执行。它会按应用正常方式加载配置和连接数据库，但只读取结构元数据，不查询业务记录、不改表、不 chmod、不备份、不重启；输出不包含配置值或数据库异常详情。

```bash
cd /opt/lesson-search/current/server
sudo -u www-data env APP_ENV=production /opt/lesson-search/current/venv/bin/python -m deploy.preflight
```

退出码 `0` 表示启动配置和所列结构检查通过，不表示备份、历史归属和上线审批已经完成。`--backup /私有目录/文件.sql.gz` 可附加现有备份的大小、权限及最近 24 小时时间检查，始终输出 `restore_verified: false`；它不是解压校验或恢复演练。

附加备份检查由能访问该备份的运维账号执行；服务账号不需要获得 root 私有备份目录的读取权限。是否可以启动服务，仍以 `www-data` 身份的预检和实际启动验证为准。

新 systemd 模板使用预检作为 `ExecStartPre`，保留本机监听、单 worker、256MB 内存上限及请求数达到上限后的自动重启，并新增私有临时目录、禁止提权、只读系统目录和隐藏 home。配置文件应由运维设置为服务账号可读且其他用户不可读，例如 `root:www-data` 的 `0640`；不能简单改成 `root:root 0600` 后导致服务无法启动。模板在生产启用前须以目标系统验证。[systemd 文档](https://github.com/systemd/systemd/blob/main/man/systemd.exec.xml)

## 显式创建数据库备份

`deploy.backup_mysql` 仅在运维显式调用时执行。先将独立备份账号的 MySQL 客户端配置安全安装到**容器内部**，例如 `/run/secrets/lesson-search-backup.cnf`；模板见 [mysql-backup.cnf.example](mysql-backup.cnf.example)。真实配置设为仅所有者可读，不能提交到 Git，也不通过命令行参数或聊天传递口令。账号权限由运维按 MySQL 的表、视图、触发器、事件和存储过程备份要求设置。

以下是后续操作示例，不能覆盖已保存的发布备份：

```bash
cd /opt/lesson-search/current/server
/opt/lesson-search/current/venv/bin/python -m deploy.backup_mysql \
  --container mysql-container \
  --defaults-file /run/secrets/lesson-search-backup.cnf \
  --output /var/backups/lesson-search/lesson_search_YYYYMMDD_HHMMSS.sql.gz
```

工具流式压缩转储，输出文件以 `0600` 创建，Linux 备份目录需为 `0700`。转储失败或磁盘写入失败时清理临时文件，成功后以不覆盖方式发布，并返回 SHA-256；不会删除旧备份、自动恢复或迁移。

转储使用 `--single-transaction --quick`，一致性前提是 InnoDB 表，转储期间不得运行建表、改表等 DDL。`--set-gtid-purged=OFF` 避免将实例全局 GTID 状态写进业务库转储；若需要复制或时间点恢复，须另行设计 binlog 备份。[MySQL 8.4 文档](https://dev.mysql.com/doc/refman/8.4/en/mysqldump.html)

成功退出、非空文件和哈希都不证明可恢复。必须在与生产隔离的 MySQL 环境恢复，核对表结构、行数、字符集、快照和学期数据；不要把恢复演练指向生产库。同机备份还须另行落实异地副本和保留策略，本工具不擅自创建定时任务。

## 迁移和发布顺序

1. 确认业务库备份及独立恢复演练完成，记录旧服务代码、配置和结构。需要轮换已泄露凭据时，协调全部使用方；不得直接替换口令导致服务断连。
2. 按批准的维护窗口停止 API、排行榜及导入等全部写入者。新代码和配置的安装、停写以及服务重启都是生产变更，不由预检自动执行。
3. 在同版本隔离数据库先走完整迁移。历史缺少快照表时，先评审既有快照迁移；不能用 `reset_db.py` 或重新导入名单代替升级。
4. 学期迁移默认仅盘点，实际应用必须提供近期私有备份和人工恢复确认：

   ```bash
   python -m migrations.add_semester_scope
   python -m migrations.add_semester_scope --apply \
     --backup /var/backups/lesson-search/已核对的备份.sql.gz \
     --confirm-restore-tested
   ```

   `--confirm-restore-tested` 是操作者声明，不是脚本验证结果。迁移对多候选、重复开学日及无法归档的数据进行隔离，既有归属重跑不变；应核对全部自动归属和隔离学期。MySQL DDL 隐式提交，备份不能省略。
5. 完成配置权限和结构预检，在预发布验证新旧客户端、账号隔离、撤销、提交审核、跨学期历史及导出，再按批准流程启动新服务和发布客户端。systemd 模板使用 current 发布目录；更换目录或环境时仍需先验证。
6. 生产启用后核对 `/health`、`/health/db`、`/health/ready` 与日志，确认版本和新接口。不要未评估就用旧代码回滚读取新结构。

若数据库已完成学期升级，纯版本和公告更新不需要重跑迁移，更不能恢复旧备份覆盖发布后的业务写入。

## 本地回归

在仓库根目录安装测试依赖后，从 `server` 目录执行：

```powershell
python -m pip install -r server/requirements-test.txt
Push-Location server
try { python -m unittest discover -s tests -v } finally { Pop-Location }
```

本地回归测试使用 SQLite、假进程和临时文件，不连接生产、不执行真实 Docker 转储或 systemd 启动。配置、健康检查、结构未就绪、旧 PUT 和新 DELETE、备份失败清理与竞态不覆盖都包含回归；真实 MySQL 恢复、唯一索引迁移及 systemd 加固须在目标环境独立验收并私有留档。
