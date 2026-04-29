from models import Base
from database import engine
from sqlalchemy import text
with engine.connect() as conn:
    conn.execute(text('SET FOREIGN_KEY_CHECKS=0'))
    conn.commit()
Base.metadata.drop_all(engine)
with engine.connect() as conn:
    conn.execute(text('SET FOREIGN_KEY_CHECKS=1'))
    conn.commit()
Base.metadata.create_all(engine)
print('OK')
