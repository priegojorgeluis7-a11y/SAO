import os
from uuid import uuid4

from app.core.database import SessionLocal
from app.core.security import get_password_hash
from app.models.role import Role
from app.models.user import User, UserStatus
from app.models.user_role_scope import UserRoleScope


DEMO_EMAIL = os.getenv("SAO_DEMO_EMAIL", "operativo.demo@sao.mx").strip()
DEMO_PASSWORD = os.getenv("SAO_DEMO_PASSWORD", "").strip()
DEMO_FULL_NAME = "Operativo Demo"
OPERATIVO_ROLE = "OPERATIVO"


def run() -> None:
    if not DEMO_PASSWORD:
        raise RuntimeError(
            "Missing demo password. Set SAO_DEMO_PASSWORD before running this script."
        )

    db = SessionLocal()
    try:
        role = db.query(Role).filter(Role.name == OPERATIVO_ROLE).first()
        if role is None:
            raise RuntimeError(
                f"Role '{OPERATIVO_ROLE}' not found. Run seeds/migrations first."
            )

        user = db.query(User).filter(User.email == DEMO_EMAIL).first()
        if user is None:
            user = User(
                id=uuid4(),
                email=DEMO_EMAIL,
                password_hash=get_password_hash(DEMO_PASSWORD),
                full_name=DEMO_FULL_NAME,
                status=UserStatus.ACTIVE,
            )
            db.add(user)
            db.flush()
        else:
            user.full_name = DEMO_FULL_NAME
            user.password_hash = get_password_hash(DEMO_PASSWORD)
            user.status = UserStatus.ACTIVE

        existing_scopes = db.query(UserRoleScope).filter(UserRoleScope.user_id == user.id).all()
        for scope in existing_scopes:
            db.delete(scope)

        db.add(
            UserRoleScope(
                id=uuid4(),
                user_id=user.id,
                role_id=role.id,
                project_id=None,
                front_id=None,
                location_id=None,
                assigned_by_id=None,
            )
        )

        db.commit()

        print("user_email=operativo.demo@sao.mx")
        print("user_password=<from_env:SAO_DEMO_PASSWORD>")
        print("user_role=OPERATIVO")
        print("permissions_scope=operativo_only")
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


if __name__ == "__main__":
    run()