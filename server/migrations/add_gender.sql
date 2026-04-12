-- 添加 gender 字段到 students 表
ALTER TABLE students ADD COLUMN gender VARCHAR(10) NULL AFTER pinyin_abbr;