-- 添加 class_names 字段到 submissions 表
ALTER TABLE submissions ADD COLUMN class_names VARCHAR(200) NULL;

-- 为已存在的提交补充 class_names 数据（从 submission_records 关联查询）
UPDATE submissions s
SET class_names = (
    SELECT GROUP_CONCAT(DISTINCT c.display_name SEPARATOR ', ')
    FROM submission_records sr
    JOIN attendance_records ar ON sr.record_id = ar.id
    JOIN classes c ON ar.class_id = c.id
    WHERE sr.submission_id = s.id
)
WHERE s.class_names IS NULL AND s.status IN ('pending', 'approved');