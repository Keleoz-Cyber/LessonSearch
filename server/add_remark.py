from sqlalchemy import text
from database import engine
with engine.connect() as conn:
    conn.execute(text('ALTER TABLE attendance_records ADD COLUMN remark VARCHAR(200) DEFAULT NULL'))
    conn.commit()
    print('OK')
