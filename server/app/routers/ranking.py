"""
排行榜 API
"""
from datetime import datetime
from fastapi import APIRouter, Depends
from typing import Literal
from sqlalchemy.orm import Session
from sqlalchemy import and_

from app.core.database import get_db
from app.models import RankingCache, RankingSummary, Class
from app.schemas.ranking import RankingListResponse, RankingSummaryResponse, RankingItem
from app.services.semesters import resolve_semester

router = APIRouter(prefix="/ranking", tags=["ranking"])


@router.get("/list", response_model=RankingListResponse)
async def get_ranking_list(
    period_type: Literal["7d", "30d", "total"] = "7d",
    rank_type: Literal["score", "rate", "count"] = "score",
    semester_id: int | None = None,
    db: Session = Depends(get_db),
):
    """获取排行榜列表"""
    # 获取概览
    semester = resolve_semester(db, semester_id)
    summary = db.query(RankingSummary).filter(
        RankingSummary.semester_id == semester.id,
        and_(
            RankingSummary.period_type == period_type,
            RankingSummary.rank_type == rank_type,
        )
    ).first()

    if not summary:
        # 返回空状态
        return RankingListResponse(
            semester_id=semester.id,
            period_type=period_type,
            rank_type=rank_type,
            summary=RankingSummaryResponse(
                avg_value=0,
                avg_trend=None,
                top_class_name=None,
                top_value=None,
                top_trend=None,
                total_classes=0,
            ),
            items=[],
            calculated_at=datetime.now(),
        )

    # 获取榜单列表
    cache_items = db.query(RankingCache).filter(
        RankingCache.semester_id == semester.id,
        and_(
            RankingCache.period_type == period_type,
            RankingCache.rank_type == rank_type,
        )
    ).order_by(RankingCache.rank_position).all()

    # 组装数据
    items = []
    for item in cache_items:
        class_info = db.query(Class).filter(Class.id == item.class_id).first()
        items.append(RankingItem(
            rank=item.rank_position,
            class_id=item.class_id,
            class_name=class_info.display_name if class_info else "未知班级",
            rank_value=float(item.rank_value),
            trend_value=float(item.trend_value) if item.trend_value is not None else None,
            trend_rank=item.trend_rank,
            absent_count=item.total_absent,
            leave_count=item.total_leave,
            late_count=item.total_late,
            other_count=item.total_other,
        ))

    return RankingListResponse(
        semester_id=semester.id,
        period_type=period_type,
        rank_type=rank_type,
        summary=RankingSummaryResponse(
            avg_value=float(summary.avg_value),
            avg_trend=float(summary.avg_trend) if summary.avg_trend is not None else None,
            top_class_name=summary.top_class_name,
            top_value=float(summary.top_value) if summary.top_value is not None else None,
            top_trend=float(summary.top_trend) if summary.top_trend is not None else None,
            total_classes=summary.total_classes,
        ),
        items=items,
        calculated_at=summary.calculated_at,
    )
