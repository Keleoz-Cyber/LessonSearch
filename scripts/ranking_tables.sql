-- 排行榜数据库表迁移
-- 执行方式: docker exec -it 1Panel-mysql-ErMk mysql -u root -pWw3277977 lesson_search < ranking_tables.sql

-- 创建 ranking_cache 表
CREATE TABLE IF NOT EXISTS ranking_cache (
    id INT AUTO_INCREMENT PRIMARY KEY,
    period_type VARCHAR(10) NOT NULL COMMENT '统计周期: 7d, 30d, total',
    rank_type VARCHAR(10) NOT NULL COMMENT '榜单类型: score, rate, count',
    class_id INT NOT NULL,
    rank_position INT NOT NULL COMMENT '排名',
    rank_value DECIMAL(10, 4) NOT NULL COMMENT '当前值',
    trend_value DECIMAL(10, 4) COMMENT '趋势值',
    trend_rank VARCHAR(10) COMMENT '趋势排名: UP2, DOWN1, SAME, NEW',
    total_expected INT COMMENT '应到人次',
    total_absent INT COMMENT '缺勤人次',
    total_late INT COMMENT '迟到人次',
    total_leave INT COMMENT '请假人次',
    total_other INT COMMENT '其他人次',
    calculated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_period_rank (period_type, rank_type, rank_position)
);

-- 创建 ranking_summary 表
CREATE TABLE IF NOT EXISTS ranking_summary (
    id INT AUTO_INCREMENT PRIMARY KEY,
    period_type VARCHAR(10) NOT NULL,
    rank_type VARCHAR(10) NOT NULL,
    avg_value DECIMAL(10, 4) NOT NULL COMMENT '平均值',
    avg_trend DECIMAL(10, 4) COMMENT '平均值趋势',
    top_class_id INT COMMENT '最高班级ID',
    top_class_name VARCHAR(50) COMMENT '最高班级名称',
    top_value DECIMAL(10, 4) COMMENT '最高值',
    top_trend DECIMAL(10, 4) COMMENT '最高值趋势',
    total_classes INT COMMENT '上榜班级数',
    calculated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_period_rank (period_type, rank_type)
);