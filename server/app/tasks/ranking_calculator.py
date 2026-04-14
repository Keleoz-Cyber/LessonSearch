"""
排行榜计算任务
每天凌晨2点执行，计算并缓存排行榜数据
"""
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from sqlalchemy import and_, func
from typing import List, Dict, Tuple
import logging

from app.core.database import SessionLocal
from app.models import (
    AttendanceRecord,
    AttendanceTask,
    Submission,
    SubmissionRecord,
    Class,
    Grade,
    Major,
    RankingCache,
    RankingSummary,
)

logger = logging.getLogger(__name__)

# 状态权重配置
WEIGHTS = {
    "absent": 1.0,
    "leave": 0.5,
    "late": 0.3,
    "other": 0.2,
}

PERIOD_TYPES = ["7d", "30d", "total"]
RANK_TYPES = ["score", "rate", "count"]


def calculate_rankings():
    """计算所有排行榜"""
    logger.info("开始计算排行榜...")
    db = SessionLocal()

    try:
        # 清空旧缓存
        db.query(RankingCache).delete()
        db.query(RankingSummary).delete()
        db.commit()

        today = datetime.now().date()
        yesterday = today - timedelta(days=1)

        for period_type in PERIOD_TYPES:
            for rank_type in RANK_TYPES:
                logger.info(f"计算 {period_type} {rank_type} 榜单...")

                # 获取统计周期
                period_start, period_end = get_period_range(period_type, yesterday)
                prev_start, prev_end = get_previous_period_range(period_type, yesterday)

                # 获取所有班级的统计数据
                class_stats = calculate_class_stats(
                    db, period_start, period_end, rank_type
                )

                if not class_stats:
                    # 无数据，写入空概览
                    save_empty_summary(db, period_type, rank_type)
                    continue

                # 计算上一个周期的数据（用于趋势）
                prev_stats = calculate_class_stats(db, prev_start, prev_end, rank_type)

                # 排序并生成排名
                sorted_stats = sort_and_rank(class_stats, rank_type)
                prev_sorted = sort_and_rank(prev_stats, rank_type) if prev_stats else {}

                # 保存榜单数据
                save_ranking_cache(db, period_type, rank_type, sorted_stats, prev_sorted)
                save_ranking_summary(
                    db, period_type, rank_type, sorted_stats, prev_stats
                )

        db.commit()
        logger.info("排行榜计算完成")

    except Exception as e:
        logger.error(f"排行榜计算失败: {e}")
        db.rollback()
        raise
    finally:
        db.close()


def get_period_range(period_type: str, yesterday: datetime) -> Tuple[datetime, datetime]:
    """获取统计周期范围"""
    if period_type == "7d":
        start = yesterday - timedelta(days=7)
        return datetime.combine(start, datetime.min.time()), datetime.combine(yesterday, datetime.max.time())
    elif period_type == "30d":
        start = yesterday - timedelta(days=30)
        return datetime.combine(start, datetime.min.time()), datetime.combine(yesterday, datetime.max.time())
    else:  # total
        # 从系统启用开始
        return datetime.min, datetime.combine(yesterday, datetime.max.time())


def get_previous_period_range(period_type: str, yesterday: datetime) -> Tuple[datetime, datetime]:
    """获取上一个统计周期范围"""
    if period_type == "7d":
        start = yesterday - timedelta(days=14)
        end = yesterday - timedelta(days=8)
        return datetime.combine(start, datetime.min.time()), datetime.combine(end, datetime.max.time())
    elif period_type == "30d":
        start = yesterday - timedelta(days=60)
        end = yesterday - timedelta(days=31)
        return datetime.combine(start, datetime.min.time()), datetime.combine(end, datetime.max.time())
    else:  # total 无上一周期
        return None, None


def calculate_class_stats(
    db: Session,
    period_start: datetime,
    period_end: datetime,
    rank_type: str,
) -> Dict[int, Dict]:
    """计算每个班级的统计数据"""
    if period_start is None:
        return {}

    # 获取已审核通过的提交
    approved_submissions = db.query(Submission).filter(
        Submission.status == "approved",
        Submission.submitted_at >= period_start,
        Submission.submitted_at <= period_end,
    ).all()

    if not approved_submissions:
        return {}

    # 获取这些提交对应的记录
    submission_ids = [s.id for s in approved_submissions]
    submission_records = db.query(SubmissionRecord).filter(
        SubmissionRecord.submission_id.in_(submission_ids),
    ).all()

    if not submission_records:
        return {}

    record_ids = [sr.record_id for sr in submission_records]
    records = db.query(AttendanceRecord).filter(
        AttendanceRecord.id.in_(record_ids),
    ).all()

    # 按班级统计
    class_stats = {}

    for record in records:
        class_id = record.class_id
        if class_id not in class_stats:
            class_stats[class_id] = {
                "total_expected": 0,
                "absent": 0,
                "late": 0,
                "leave": 0,
                "other": 0,
                "present": 0,
            }

        class_stats[class_id]["total_expected"] += 1
        status = record.status
        if status in class_stats[class_id]:
            class_stats[class_id][status] += 1

    # 计算排名值
    for class_id, stats in class_stats.items():
        stats["score"] = calculate_score(stats)
        stats["rate"] = calculate_rate(stats)
        stats["count"] = stats["absent"]

    return class_stats


def calculate_score(stats: Dict) -> float:
    """计算综合异常分数"""
    total = stats["total_expected"]
    if total == 0:
        return 0.0

    raw_score = (
        stats["absent"] * WEIGHTS["absent"]
        + stats["leave"] * WEIGHTS["leave"]
        + stats["late"] * WEIGHTS["late"]
        + stats["other"] * WEIGHTS["other"]
    )

    return raw_score / total


def calculate_rate(stats: Dict) -> float:
    """计算缺勤率"""
    total = stats["total_expected"]
    if total == 0:
        return 0.0

    return stats["absent"] / total


def sort_and_rank(stats: Dict[int, Dict], rank_type: str) -> List[Tuple[int, Dict]]:
    """排序并生成排名"""
    items = [(class_id, data) for class_id, data in stats.items()]

    # 按值降序排序
    items.sort(key=lambda x: (-x[1][rank_type], x[0]))

    # 添加排名
    for i, (class_id, data) in enumerate(items):
        data["rank"] = i + 1

    return items


def save_ranking_cache(
    db: Session,
    period_type: str,
    rank_type: str,
    sorted_stats: List[Tuple[int, Dict]],
    prev_sorted: List[Tuple[int, Dict]],
):
    """保存排行榜缓存"""
    # 构建上一周期的排名映射
    prev_rank_map = {item[0]: item[1]["rank"] for item in prev_sorted}

    for class_id, data in sorted_stats:
        # 计算趋势
        prev_data = prev_rank_map.get(class_id)
        if prev_data:
            current_rank = data["rank"]
            prev_rank = prev_rank_map.get(class_id, None)
            
            if prev_rank is None:
                trend_rank = "NEW"
            elif current_rank < prev_rank:
                trend_rank = f"UP{prev_rank - current_rank}"
            elif current_rank > prev_rank:
                trend_rank = f"DOWN{current_rank - prev_rank}"
            else:
                trend_rank = "SAME"
        else:
            trend_rank = "NEW"

        cache = RankingCache(
            period_type=period_type,
            rank_type=rank_type,
            class_id=class_id,
            rank_position=data["rank"],
            rank_value=data[rank_type],
            trend_value=None if period_type == "total" else data.get("trend_value"),
            trend_rank=None if period_type == "total" else trend_rank,
            total_expected=data["total_expected"],
            total_absent=data["absent"],
            total_late=data["late"],
            total_leave=data["leave"],
            total_other=data["other"],
        )
        db.add(cache)


def save_ranking_summary(
    db: Session,
    period_type: str,
    rank_type: str,
    sorted_stats: List[Tuple[int, Dict]],
    prev_stats: Dict[int, Dict],
):
    """保存概览数据"""
    if not sorted_stats:
        save_empty_summary(db, period_type, rank_type)
        return

    values = [data[rank_type] for _, data in sorted_stats]
    avg_value = sum(values) / len(values)

    # 最高班级
    top_class_id, top_data = sorted_stats[0]
    top_class = db.query(Class).filter(Class.id == top_class_id).first()

    summary = RankingSummary(
        period_type=period_type,
        rank_type=rank_type,
        avg_value=avg_value,
        avg_trend=None if period_type == "total" else None,
        top_class_id=top_class_id,
        top_class_name=top_class.display_name if top_class else None,
        top_value=top_data[rank_type],
        top_trend=None if period_type == "total" else None,
        total_classes=len(sorted_stats),
    )
    db.add(summary)


def save_empty_summary(db: Session, period_type: str, rank_type: str):
    """保存空概览"""
    summary = RankingSummary(
        period_type=period_type,
        rank_type=rank_type,
        avg_value=0,
        avg_trend=None,
        top_class_id=None,
        top_class_name=None,
        top_value=None,
        top_trend=None,
        total_classes=0,
    )
    db.add(summary)


if __name__ == "__main__":
    calculate_rankings()