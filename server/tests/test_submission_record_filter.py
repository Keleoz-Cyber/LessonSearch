import unittest
from types import SimpleNamespace

from app.routers.submission import _filter_valid_submission_records


class SubmissionRecordFilterTest(unittest.TestCase):
    def test_filters_records_that_no_longer_match_current_roster(self):
        tasks = [
            SimpleNamespace(
                id="task-1",
                task_classes=[SimpleNamespace(class_id=10)],
            )
        ]
        records = [
            SimpleNamespace(id=1, task_id="task-1", student_id=101, class_id=10),
            SimpleNamespace(id=2, task_id="task-1", student_id=102, class_id=10),
            SimpleNamespace(id=3, task_id="task-1", student_id=103, class_id=99),
        ]
        students_by_id = {
            101: SimpleNamespace(id=101, class_id=10),
            102: SimpleNamespace(id=102, class_id=11),
        }

        filtered = _filter_valid_submission_records(
            records,
            tasks,
            students_by_id,
        )

        self.assertEqual([r.id for r in filtered], [1])


if __name__ == "__main__":
    unittest.main()
