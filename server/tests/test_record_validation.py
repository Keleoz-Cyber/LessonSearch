import unittest
from types import SimpleNamespace

from fastapi import HTTPException

from routers.records import _validate_student_record_membership


class RecordValidationTest(unittest.TestCase):
    def test_rejects_student_from_different_class(self):
        student = SimpleNamespace(id=10, class_id=2)

        with self.assertRaises(HTTPException) as ctx:
            _validate_student_record_membership(
                task_class_ids={1},
                student=student,
                payload_class_id=1,
            )

        self.assertEqual(ctx.exception.status_code, 400)
        self.assertIn("学生不属于提交的班级", str(ctx.exception.detail))

    def test_rejects_class_not_attached_to_task(self):
        student = SimpleNamespace(id=10, class_id=2)

        with self.assertRaises(HTTPException) as ctx:
            _validate_student_record_membership(
                task_class_ids={1},
                student=student,
                payload_class_id=2,
            )

        self.assertEqual(ctx.exception.status_code, 400)
        self.assertIn("班级不属于该任务", str(ctx.exception.detail))


if __name__ == "__main__":
    unittest.main()
