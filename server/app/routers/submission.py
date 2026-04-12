"""
提交审核API
"""
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List
from datetime import datetime
from io import BytesIO
from urllib.parse import quote
import openpyxl
from openpyxl.styles import Font, Alignment, Border, Side

from app.core.database import get_db
from app.core.security import get_current_user
from app.models import User, Submission, SubmissionRecord, AttendanceRecord, AttendanceTask, Student, Class, Major
from app.models.week import WeekExport
from app.schemas.submission import (
    CreateSubmissionRequest,
    SubmissionResponse,
    SubmissionDetailResponse,
    ApproveSubmissionRequest,
    RejectSubmissionRequest,
    WeekSummaryResponse,
    ExportStatusResponse,
    SubmissionRecordsResponse,
    RecordDetail
)
from app.routers.week import get_current_week_config, calculate_week_number

router = APIRouter(prefix="/submissions", tags=["submissions"])


@router.post("/", response_model=SubmissionResponse)
async def create_submission(
    body: CreateSubmissionRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """创建提交"""
    tasks = db.query(AttendanceTask).filter(
        AttendanceTask.id.in_(body.task_ids)
    ).all()
    
    for task in tasks:
        if task.user_id != current_user.id:
            raise HTTPException(
                status_code=403,
                detail=f"任务 {task.id} 不属于当前用户"
            )
    
    records = db.query(AttendanceRecord).filter(
        AttendanceRecord.task_id.in_(body.task_ids)
    ).all()
    
    existing_submission_ids = db.query(SubmissionRecord.record_id).filter(
        SubmissionRecord.record_id.in_([r.id for r in records if r.id])
    ).all()
    
    if existing_submission_ids:
        raise HTTPException(
            status_code=400,
            detail="部分记录已提交，无法重复提交"
        )
    
    submission = Submission(
        user_id=current_user.id,
        week_number=body.week_number,
        status="pending"
    )
    db.add(submission)
    db.flush()
    
    for record in records:
        if record.id:
            sr = SubmissionRecord(
                submission_id=submission.id,
                record_id=record.id
            )
            db.add(sr)
    
    db.commit()
    db.refresh(submission)
    
    return submission


@router.get("/submitted-task-ids")
async def get_submitted_task_ids(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取已提交的任务ID列表"""
    submissions = db.query(Submission).filter(
        Submission.user_id == current_user.id
    ).all()
    
    submitted_task_ids = set()
    for sub in submissions:
        submission_records = db.query(SubmissionRecord).filter(
            SubmissionRecord.submission_id == sub.id
        ).all()
        for sr in submission_records:
            record = db.query(AttendanceRecord).filter(
                AttendanceRecord.id == sr.record_id
            ).first()
            if record:
                submitted_task_ids.add(record.task_id)
    
    return {"task_ids": list(submitted_task_ids)}


@router.get("/", response_model=List[SubmissionResponse])
async def get_submissions(
    week_number: int = None,
    status: str = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取提交列表"""
    query = db.query(Submission).filter(Submission.user_id == current_user.id)
    
    if week_number:
        query = query.filter(Submission.week_number == week_number)
    
    if status:
        query = query.filter(Submission.status == status)
    
    return query.order_by(Submission.submitted_at.desc()).all()


@router.get("/pending", response_model=List[SubmissionDetailResponse])
async def get_pending_submissions(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取待审核提交列表（管理员）"""
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="需要管理员权限")
    
    submissions = db.query(Submission).filter(
        Submission.status == "pending"
    ).all()
    
    result = []
    for sub in submissions:
        user = db.query(User).filter(User.id == sub.user_id).first()
        
        submission_records = db.query(SubmissionRecord).filter(
            SubmissionRecord.submission_id == sub.id
        ).all()
        record_count = len(submission_records)
        task_ids = set()
        for sr in submission_records:
            record = db.query(AttendanceRecord).filter(AttendanceRecord.id == sr.record_id).first()
            if record:
                task_ids.add(record.task_id)
        
        result.append(SubmissionDetailResponse(
            id=sub.id,
            user_id=sub.user_id,
            user_name=user.real_name if user else None,
            user_email=user.email if user else None,
            week_number=sub.week_number,
            status=sub.status,
            reviewer_id=sub.reviewer_id,
            reviewer_name=None,
            review_time=sub.review_time,
            review_note=sub.review_note,
            submitted_at=sub.submitted_at,
            task_count=len(task_ids),
            record_count=record_count
        ))
    
    return result


@router.get("/week-summary/{week_number}", response_model=WeekSummaryResponse)
async def get_week_summary(
    week_number: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取周汇总统计"""
    from sqlalchemy import func as sql_func
    
    submissions = db.query(Submission).filter(
        Submission.week_number == week_number
    ).all()
    
    pending = len([s for s in submissions if s.status == "pending"])
    approved = len([s for s in submissions if s.status == "approved"])
    rejected = len([s for s in submissions if s.status == "rejected"])
    
    late_count = 0
    absent_count = 0
    
    approved_ids = [s.id for s in submissions if s.status == "approved"]
    if approved_ids:
        late_count = db.query(sql_func.count()).select_from(SubmissionRecord).join(
            AttendanceRecord, SubmissionRecord.record_id == AttendanceRecord.id
        ).filter(
            SubmissionRecord.submission_id.in_(approved_ids),
            AttendanceRecord.status == "late"
        ).scalar() or 0
        
        absent_count = db.query(sql_func.count()).select_from(SubmissionRecord).join(
            AttendanceRecord, SubmissionRecord.record_id == AttendanceRecord.id
        ).filter(
            SubmissionRecord.submission_id.in_(approved_ids),
            AttendanceRecord.status == "absent"
        ).scalar() or 0
    
    export = db.query(WeekExport).filter(
        WeekExport.week_number == week_number
    ).order_by(WeekExport.exported_at.desc()).first()
    
    return WeekSummaryResponse(
        week_number=week_number,
        total_submissions=len(submissions),
        pending_count=pending,
        approved_count=approved,
        rejected_count=rejected,
        late_count=late_count,
        absent_count=absent_count,
        is_published=export is not None
    )


@router.get("/week-summary-detail/{week_number}")
async def get_week_summary_detail(
    week_number: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取周汇总详细名单（管理员）- 表格形式"""
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="需要管理员权限")
    
    approved_submissions = db.query(Submission).filter(
        Submission.week_number == week_number,
        Submission.status == "approved"
    ).all()
    
    approved_ids = [s.id for s in approved_submissions]
    
    student_stats = {}
    submission_records = []
    
    if approved_ids:
        submission_records = db.query(SubmissionRecord).filter(
            SubmissionRecord.submission_id.in_(approved_ids)
        ).all()
        
        for sr in submission_records:
            record = db.query(AttendanceRecord).filter(
                AttendanceRecord.id == sr.record_id
            ).first()
            
            if record and record.status in ("late", "absent"):
                student = db.query(Student).filter(
                    Student.id == record.student_id
                ).first()
                
                if student:
                    class_ = db.query(Class).filter(Class.id == student.class_id).first()
                    major = None
                    if class_:
                        major = db.query(Major).filter(Major.id == class_.major_id).first()
                    
                    sid = student.id
                    if sid not in student_stats:
                        student_stats[sid] = {
                            "student_id": sid,
                            "name": student.name,
                            "student_no": student.student_no,
                            "class_name": class_.display_name if class_ else "未知",
                            "major_short_name": major.short_name if major else "",
                            "class_code": class_.class_code if class_ else "",
                            "late": 0,
                            "absent": 0,
                        }
                    
                    if record.status == "late":
                        student_stats[sid]["late"] += 1
                    elif record.status == "absent":
                        student_stats[sid]["absent"] += 1
    
    sorted_students = sorted(
        student_stats.values(),
        key=lambda x: (x["major_short_name"], int(x["class_code"]) if x["class_code"].isdigit() else 0, x["student_no"])
    )
    
    table_data = []
    for i, s in enumerate(sorted_students, 1):
        table_data.append({
            "index": i,
            "name": s["name"],
            "class_name": s["class_name"],
            "student_no": s["student_no"],
            "late": s["late"],
            "absent": s["absent"],
            "total": (s["late"] // 2) + s["absent"],
        })
    
    return {
        "week_number": week_number,
        "table_data": table_data,
        "total_count": len(table_data),
        "debug": {
            "approved_submission_count": len(approved_submissions),
            "approved_ids": approved_ids,
            "submission_record_count": len(submission_records) if approved_ids else 0,
            "student_stats_count": len(student_stats),
        }
    }


@router.get("/export-status/{week_number}", response_model=ExportStatusResponse)
async def get_export_status(
    week_number: int,
    db: Session = Depends(get_db)
):
    """获取周导出状态"""
    export = db.query(WeekExport).filter(
        WeekExport.week_number == week_number
    ).order_by(WeekExport.exported_at.desc()).first()
    
    if not export:
        return ExportStatusResponse(
            week_number=week_number,
            is_published=False
        )
    
    exporter = db.query(User).filter(User.id == export.exported_by).first()
    
    return ExportStatusResponse(
        week_number=week_number,
        is_published=True,
        exported_at=export.exported_at,
        exported_by_name=exporter.real_name if exporter else None
    )


@router.get("/export/{week_number}")
async def export_week_excel(
    week_number: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """导出周考勤Excel（管理员）"""
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="需要管理员权限")
    
    submissions = db.query(Submission).filter(
        Submission.week_number == week_number,
        Submission.status == "approved"
    ).all()
    
    if not submissions:
        raise HTTPException(status_code=400, detail="该周无已审核通过的提交")
    
    records_data = []
    for sub in submissions:
        submission_records = db.query(SubmissionRecord).filter(
            SubmissionRecord.submission_id == sub.id
        ).all()
        
        for sr in submission_records:
            record = db.query(AttendanceRecord).filter(
                AttendanceRecord.id == sr.record_id
            ).first()
            if record and record.status in ("late", "absent"):
                student = db.query(Student).filter(
                    Student.id == record.student_id
                ).first()
                if student:
                    class_ = db.query(Class).filter(Class.id == student.class_id).first()
                    major = None
                    if class_:
                        major = db.query(Major).filter(Major.id == class_.major_id).first()
                    
                    records_data.append({
                        "student_id": student.id,
                        "name": student.name,
                        "student_no": student.student_no,
                        "class_name": class_.display_name if class_ else "未知",
                        "major_short_name": major.short_name if major else "",
                        "class_code": class_.class_code if class_ else "",
                        "status": record.status,
                    })
    
    student_stats = {}
    for r in records_data:
        sid = r["student_id"]
        if sid not in student_stats:
            student_stats[sid] = {
                "name": r["name"],
                "student_no": r["student_no"],
                "class_name": r["class_name"],
                "major_short_name": r["major_short_name"],
                "class_code": r["class_code"],
                "late": 0,
                "absent": 0,
            }
        if r["status"] == "late":
            student_stats[sid]["late"] += 1
        elif r["status"] == "absent":
            student_stats[sid]["absent"] += 1
    
    sorted_students = sorted(
        student_stats.values(),
        key=lambda x: (x["major_short_name"], int(x["class_code"]) if x["class_code"].isdigit() else 0, x["student_no"])
    )
    
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = f"第{week_number}周考勤"
    
    headers = ["序号", "姓名", "班级", "学号", "迟到/早退", "旷课", "累计"]
    ws.append(headers)
    
    for cell in ws[1]:
        cell.font = Font(bold=True)
        cell.alignment = Alignment(horizontal="center")
    
    for i, s in enumerate(sorted_students, 1):
        row = [
            i,
            s["name"],
            s["class_name"],
            s["student_no"],
            s["late"],
            s["absent"],
            None,
        ]
        ws.append(row)
        
        ws.cell(row=i+1, column=7).value = f"=ROUNDDOWN(E{i+1}/2+F{i+1},0)"
    
    thin_border = Border(
        left=Side(style='thin'),
        right=Side(style='thin'),
        top=Side(style='thin'),
        bottom=Side(style='thin')
    )
    for row in ws.iter_rows(min_row=1, max_row=ws.max_row, min_col=1, max_col=7):
        for cell in row:
            cell.border = thin_border
            cell.alignment = Alignment(horizontal="center")
    
    ws.column_dimensions['A'].width = 6
    ws.column_dimensions['B'].width = 12
    ws.column_dimensions['C'].width = 12
    ws.column_dimensions['D'].width = 16
    ws.column_dimensions['E'].width = 12
    ws.column_dimensions['F'].width = 8
    ws.column_dimensions['G'].width = 8
    
    output = BytesIO()
    wb.save(output)
    output.seek(0)
    
    export = WeekExport(
        week_number=week_number,
        exported_by=current_user.id
    )
    db.add(export)
    db.commit()
    
    filename = f"第{week_number}周周考勤表.xlsx"
    encoded_filename = quote(filename)
    return StreamingResponse(
        output,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f"attachment; filename*=UTF-8''{encoded_filename}"}
    )


@router.get("/{submission_id}", response_model=SubmissionDetailResponse)
async def get_submission_detail(
    submission_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取提交详情"""
    submission = db.query(Submission).filter(Submission.id == submission_id).first()
    
    if not submission:
        raise HTTPException(status_code=404, detail="提交不存在")
    
    if submission.user_id != current_user.id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="无权查看此提交")
    
    user = db.query(User).filter(User.id == submission.user_id).first()
    reviewer = None
    if submission.reviewer_id:
        reviewer = db.query(User).filter(User.id == submission.reviewer_id).first()
    
    submission_records = db.query(SubmissionRecord).filter(
        SubmissionRecord.submission_id == submission.id
    ).all()
    record_count = len(submission_records)
    task_ids = set()
    for sr in submission_records:
        record = db.query(AttendanceRecord).filter(AttendanceRecord.id == sr.record_id).first()
        if record:
            task_ids.add(record.task_id)
    
    return SubmissionDetailResponse(
        id=submission.id,
        user_id=submission.user_id,
        user_name=user.real_name if user else None,
        user_email=user.email if user else None,
        week_number=submission.week_number,
        status=submission.status,
        reviewer_id=submission.reviewer_id,
        reviewer_name=reviewer.real_name if reviewer else None,
        review_time=submission.review_time,
        review_note=submission.review_note,
        submitted_at=submission.submitted_at,
        task_count=len(task_ids),
        record_count=record_count
    )


@router.get("/{submission_id}/records", response_model=SubmissionRecordsResponse)
async def get_submission_records(
    submission_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取提交的详细记录列表"""
    submission = db.query(Submission).filter(Submission.id == submission_id).first()
    
    if not submission:
        raise HTTPException(status_code=404, detail="提交不存在")
    
    if submission.user_id != current_user.id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="无权查看此提交")
    
    user = db.query(User).filter(User.id == submission.user_id).first()
    
    submission_records = db.query(SubmissionRecord).filter(
        SubmissionRecord.submission_id == submission.id
    ).all()
    
    records = []
    late_count = 0
    absent_count = 0
    leave_count = 0
    other_count = 0
    
    for sr in submission_records:
        record = db.query(AttendanceRecord).filter(
            AttendanceRecord.id == sr.record_id
        ).first()
        
        if record:
            student = db.query(Student).filter(
                Student.id == record.student_id
            ).first()
            
            if student:
                class_ = db.query(Class).filter(Class.id == student.class_id).first()
                
                records.append(RecordDetail(
                    student_id=student.id,
                    student_name=student.name,
                    student_no=student.student_no,
                    class_name=class_.display_name if class_ else "未知",
                    status=record.status
                ))
                
                if record.status == "late":
                    late_count += 1
                elif record.status == "absent":
                    absent_count += 1
                elif record.status == "leave":
                    leave_count += 1
                elif record.status == "other":
                    other_count += 1
    
    return SubmissionRecordsResponse(
        id=submission.id,
        user_id=submission.user_id,
        user_name=user.real_name if user else None,
        user_email=user.email if user else None,
        week_number=submission.week_number,
        status=submission.status,
        submitted_at=submission.submitted_at,
        records=records,
        late_count=late_count,
        absent_count=absent_count,
        leave_count=leave_count,
        other_count=other_count
    )


@router.put("/{submission_id}/approve")
async def approve_submission(
    submission_id: int,
    body: ApproveSubmissionRequest = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """审核通过"""
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="需要管理员权限")
    
    submission = db.query(Submission).filter(Submission.id == submission_id).first()
    
    if not submission:
        raise HTTPException(status_code=404, detail="提交不存在")
    
    if submission.status != "pending":
        raise HTTPException(status_code=400, detail="提交状态不是待审核")
    
    submission.status = "approved"
    submission.reviewer_id = current_user.id
    submission.review_time = datetime.now()
    if body and body.note:
        submission.review_note = body.note
    
    db.commit()
    
    return {"message": "审核通过", "submission_id": submission_id}


@router.put("/{submission_id}/reject")
async def reject_submission(
    submission_id: int,
    body: RejectSubmissionRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """审核拒绝"""
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="需要管理员权限")
    
    submission = db.query(Submission).filter(Submission.id == submission_id).first()
    
    if not submission:
        raise HTTPException(status_code=404, detail="提交不存在")
    
    if submission.status != "pending":
        raise HTTPException(status_code=400, detail="提交状态不是待审核")
    
    submission.status = "rejected"
    submission.reviewer_id = current_user.id
    submission.review_time = datetime.now()
    submission.review_note = body.note
    
    db.query(SubmissionRecord).filter(
        SubmissionRecord.submission_id == submission_id
    ).delete()
    
    db.commit()
    
    return {"message": "审核拒绝", "submission_id": submission_id}


@router.delete("/{submission_id}")
async def cancel_submission(
    submission_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """撤销提交"""
    submission = db.query(Submission).filter(Submission.id == submission_id).first()
    
    if not submission:
        raise HTTPException(status_code=404, detail="提交不存在")
    
    if submission.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="只能撤销自己的提交")
    
    if submission.status != "pending":
        raise HTTPException(status_code=400, detail="只能撤销待审核的提交")
    
    db.query(SubmissionRecord).filter(
        SubmissionRecord.submission_id == submission_id
    ).delete()
    
    submission.status = "cancelled"
    db.commit()
    
    return {"message": "提交已撤销", "submission_id": submission_id}