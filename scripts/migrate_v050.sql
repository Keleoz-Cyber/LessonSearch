-- v0.5.0 数据库迁移 SQL
-- 执行方式：mysql -u lesson_search -p lesson_search < migrate_v050.sql

-- 1. 修改 users 表
ALTER TABLE users ADD COLUMN role VARCHAR(20) DEFAULT 'member';
ALTER TABLE users ADD COLUMN real_name VARCHAR(50);

-- 2. 创建 week_config 表
CREATE TABLE IF NOT EXISTS week_config (
    id INT PRIMARY KEY AUTO_INCREMENT,
    start_date DATE NOT NULL,
    semester_name VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 3. 创建 submissions 表
CREATE TABLE IF NOT EXISTS submissions (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    week_number INT NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    reviewer_id INT,
    review_time DATETIME,
    review_note TEXT,
    submitted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (reviewer_id) REFERENCES users(id),
    INDEX idx_user_week (user_id, week_number),
    INDEX idx_status (status),
    INDEX idx_week (week_number)
);

-- 4. 创建 submission_records 表
CREATE TABLE IF NOT EXISTS submission_records (
    id INT PRIMARY KEY AUTO_INCREMENT,
    submission_id INT NOT NULL,
    record_id INT NOT NULL,
    FOREIGN KEY (submission_id) REFERENCES submissions(id),
    FOREIGN KEY (record_id) REFERENCES attendance_records(id),
    UNIQUE KEY uk_record (record_id)
);

-- 5. 创建 week_exports 表
CREATE TABLE IF NOT EXISTS week_exports (
    id INT PRIMARY KEY AUTO_INCREMENT,
    week_number INT NOT NULL,
    exported_by INT NOT NULL,
    exported_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (exported_by) REFERENCES users(id),
    INDEX idx_week (week_number)
);

-- 6. 创建 duty_assignments 表
CREATE TABLE IF NOT EXISTS duty_assignments (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    assigned_by INT NOT NULL,
    assigned_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    deactivated_at DATETIME,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (assigned_by) REFERENCES users(id),
    UNIQUE KEY uk_user (user_id)
);

-- 完成
SELECT 'v0.5.0 迁移完成' AS message;