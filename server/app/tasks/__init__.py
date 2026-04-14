"""
定时任务模块
"""
from app.tasks.ranking_calculator import calculate_rankings

__all__ = ["calculate_rankings"]