"""
排行榜缓存模型
"""
from sqlalchemy import Column, Integer, String, DECIMAL, DateTime, ForeignKey
from sqlalchemy.sql import func

from app.core.database import Base


class RankingCache(Base):
    __tablename__ = "ranking_cache"

    id = Column(Integer, primary_key=True, autoincrement=True)
    period_type = Column(String(10), nullable=False)  # '7d', '30d', 'total'
    rank_type = Column(String(10), nullable=False)    # 'score', 'rate', 'count'
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False)
    rank_position = Column(Integer, nullable=False)
    rank_value = Column(DECIMAL(10, 4), nullable=False)
    trend_value = Column(DECIMAL(10, 4))
    trend_rank = Column(String(10))  # 'UP2', 'DOWN1', 'SAME', 'NEW'
    total_expected = Column(Integer)
    total_absent = Column(Integer)
    total_late = Column(Integer)
    total_leave = Column(Integer)
    total_other = Column(Integer)
    calculated_at = Column(DateTime, server_default=func.now())


class RankingSummary(Base):
    __tablename__ = "ranking_summary"

    id = Column(Integer, primary_key=True, autoincrement=True)
    period_type = Column(String(10), nullable=False)
    rank_type = Column(String(10), nullable=False)
    avg_value = Column(DECIMAL(10, 4), nullable=False)
    avg_trend = Column(DECIMAL(10, 4))
    top_class_id = Column(Integer)
    top_class_name = Column(String(50))
    top_value = Column(DECIMAL(10, 4))
    top_trend = Column(DECIMAL(10, 4))
    total_classes = Column(Integer)
    calculated_at = Column(DateTime, server_default=func.now())