"""
排行榜 API schemas
"""
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


class RankingItem(BaseModel):
    rank: int
    class_id: int
    class_name: str
    rank_value: float
    trend_value: Optional[float] = None
    trend_rank: Optional[str] = None
    absent_count: Optional[int] = None
    leave_count: Optional[int] = None
    late_count: Optional[int] = None
    other_count: Optional[int] = None


class RankingSummaryResponse(BaseModel):
    avg_value: float
    avg_trend: Optional[float] = None
    top_class_name: Optional[str] = None
    top_value: Optional[float] = None
    top_trend: Optional[float] = None
    total_classes: int


class RankingListResponse(BaseModel):
    period_type: str
    rank_type: str
    summary: RankingSummaryResponse
    items: List[RankingItem]
    calculated_at: datetime