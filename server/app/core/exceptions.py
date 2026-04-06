"""
自定义异常
"""
from fastapi import HTTPException


class AppException(HTTPException):
    """应用基础异常"""
    pass


class AuthenticationError(AppException):
    """认证错误"""
    def __init__(self, detail: str = "认证失败"):
        super().__init__(status_code=401, detail=detail)


class PermissionDenied(AppException):
    """权限不足"""
    def __init__(self, detail: str = "权限不足"):
        super().__init__(status_code=403, detail=detail)


class NotFoundError(AppException):
    """资源不存在"""
    def __init__(self, detail: str = "资源不存在"):
        super().__init__(status_code=404, detail=detail)


class ValidationError(AppException):
    """验证错误"""
    def __init__(self, detail: str = "数据验证失败"):
        super().__init__(status_code=422, detail=detail)