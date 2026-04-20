# 故障报告：2026-04-20 服务器内存耗尽导致 App 服务异常

## 故障时间

- **发现时间**：2026-04-20（周末期间已出现异常）
- **恢复时间**：2026-04-20 13:15

## 故障现象

- App 端无法获取服务端数据，记名模块加载失败
- 错误信息：`同步学生数据失败: DioException [receive timeout]`（10秒超时）
- 服务器域名返回 502

## 根因分析

### 1. Halo 博客容器自动重启

Halo 博客（Java/Spring Boot）此前被手动停止，但未禁止自动重启策略，容器重新拉起后占用大量内存：

- Java 进程占用 4.1% 内存（~83MB）+ 25.8% CPU
- Java 启动进一步加剧内存压力

### 2. 服务器内存严重不足

服务器仅 2GB 内存，运行了过多服务：

| 服务 | 内存占用 |
|------|----------|
| Halo 博客（Java） | ~83MB |
| MySQL（Docker） | ~29MB + 128MB buffer pool |
| 京东云监控（jdog-kunlunmirror） | ~51MB |
| 京东云 Agent（JCSAgentCore + MonitorPlugin） | ~25MB |
| 1Panel（agent + core） | ~30MB |
| Docker Daemon | ~32MB |
| lesson-search（uvicorn） | ~60-100MB |
| 其他（containerd、systemd 等） | ~200MB+ |

**总计远超 2GB 物理内存**，导致大量使用 Swap（峰值 1GB+）。

### 3. MySQL 连接丢失

内存耗尽导致系统疯狂换页（kswapd0 占 16.7% CPU，I/O wait 高达 67.3%），MySQL 查询从正常的毫秒级退化到 10-20 秒：

```
sqlalchemy.exc.OperationalError: (pymysql.err.OperationalError)
(2013, 'Lost connection to MySQL server during query')
```

### 4. Python 进程被换出

由于内存不足，长时间无请求时 Python 进程被 Swap 换出到磁盘，下次请求需要 10-20 秒才能换回内存，导致 App 超时。

### 5. SQLAlchemy 连接池无保护配置

`create_engine` 未配置 `pool_recycle` 和 `pool_pre_ping`，长时间运行后连接池中的连接过期失效，访问时触发连接错误。

### 6. App 超时时间过短

`receiveTimeout` 仅 10 秒，在服务器冷启动场景下不足以等待进程换入内存。

## 修复措施

### 服务器端

| 措施 | 说明 |
|------|------|
| 停止 Halo 容器并禁止自动重启 | `docker stop 1Panel-halo-oTNP && docker update --restart=no 1Panel-halo-oTNP` |
| 停止并禁用京东云监控服务 | `systemctl stop jdog_service.service ifritd.service && systemctl disable` |
| 缩小 MySQL buffer pool | `SET GLOBAL innodb_buffer_pool_size = 67108864`（128MB → 64MB） |
| 添加 cron 保活 | 每分钟请求 `/health` 防止 Python 进程被换出 |

### 代码层

| 文件 | 修改 |
|------|------|
| `server/app/core/database.py` | 添加 `pool_recycle=1800`、`pool_pre_ping=True`、`pool_size=5`、`max_overflow=5`、`pool_timeout=30` |
| `app/lib/core/network/api_client.dart` | `connectTimeout` 10s→15s，`receiveTimeout` 10s→30s |
| `server/main.py` | 注册 `data_version` router（修复 404） |

## 修复后效果

| 指标 | 修复前 | 修复后 |
|------|--------|--------|
| API 响应时间（冷启动） | 21 秒 | 4.5 秒 |
| API 响应时间（热请求） | 9 秒 | 0.098 秒 |
| 可用内存 | 60MB | 128MB |
| Swap 使用 | 1GB | 722MB |
| App 加载数据 | 超时失败 | 正常 |

## 长期建议

1. **升级服务器内存**：2GB 跑 MySQL + Docker + 1Panel + App 服务太紧张，建议升级到 4GB
2. **考虑外部 MySQL**：使用云数据库（如京东云 RDS），释放本地 MySQL 内存开销
3. **精简监控 Agent**：如不需要京东云监控，可彻底卸载释放约 75MB 内存
4. **博客独立部署**：Halo 博客不应和 App 服务共用 2GB 服务器
5. **添加内存告警**：当可用内存低于 200MB 时发送通知
6. **App 增加重试机制**：首次请求超时时自动重试一次，覆盖冷启动场景
