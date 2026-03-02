import uuid
from datetime import datetime

from main import Session, engine, User

email = "testuser@test.com"

with Session(engine) as db:
    existing = db.query(User).filter(User.email == email).first()
    if existing:
        print("user_exists")
    else:
        user = User(
            id=uuid.uuid4(),
            email=email,
            password_hash="dev-not-checked",
            full_name="Test User",
            phone="0000000000",
            status="active",
            role="operativo",
            last_login=datetime.utcnow(),
        )
        db.add(user)
        db.commit()
        print("user_created")
