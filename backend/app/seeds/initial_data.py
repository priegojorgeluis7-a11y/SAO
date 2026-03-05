"""Database seed routines for initial SAO bootstrap data."""

from datetime import date
import os
from uuid import uuid4

from sqlalchemy.orm import Session

from app.core.security import get_password_hash
from app.models.front import Front
from app.models.permission import Permission
from app.models.project import Project, ProjectStatus
from app.models.reject_reason import RejectReason
from app.models.role import Role
from app.models.user import User, UserStatus
from app.models.user_role_scope import UserRoleScope
from app.seeds.mexico_locations import seed_mexico_locations_catalog


def _create_if_missing(db: Session, model, lookup_filters: dict, create_kwargs: dict) -> tuple[object, bool]:
    """Get existing row by filters, or create it when not found."""
    instance = db.query(model).filter_by(**lookup_filters).first()
    if instance:
        return instance, False
    instance = model(**create_kwargs)
    db.add(instance)
    return instance, True


def _get_role_or_raise(db: Session, role_name: str) -> Role:
    """Fetch role by name and raise explicit error if seed order is broken."""
    role = db.query(Role).filter(Role.name == role_name).first()
    if not role:
        raise ValueError(f"Role '{role_name}' not found. Ensure role seeds run first.")
    return role


def _assign_permissions_by_codes(db: Session, role_name: str, permission_codes: list[str]) -> None:
    """Assign a role's permissions using permission codes."""
    role = _get_role_or_raise(db, role_name)
    permissions = db.query(Permission).filter(Permission.code.in_(permission_codes)).all()
    role.permissions = permissions


def _assign_view_only_permissions(db: Session, role_name: str) -> None:
    """Assign view-only permissions to a role."""
    role = _get_role_or_raise(db, role_name)
    role.permissions = db.query(Permission).filter(Permission.action == "view").all()


def seed_roles(db: Session):
    """Crear 5 roles base"""
    roles = [
        Role(id=1, name="ADMIN", description="Administrador del sistema"),
        Role(id=2, name="COORD", description="Coordinador de proyecto"),
        Role(id=3, name="SUPERVISOR", description="Supervisor de frente"),
        Role(id=4, name="OPERATIVO", description="Personal operativo de campo"),
        Role(id=5, name="LECTOR", description="Solo lectura (stakeholders)"),
    ]
    
    for role in roles:
        _, created = _create_if_missing(
            db,
            Role,
            lookup_filters={"id": role.id},
            create_kwargs={"id": role.id, "name": role.name, "description": role.description},
        )
        if created:
            print(f"[OK] Created role: {role.name}")
    
    db.commit()


def seed_permissions(db: Session):
    """Crear permisos básicos"""
    permissions = [
        # Activities
        Permission(id=1, code="activity.create", resource="activity", action="create"),
        Permission(id=2, code="activity.edit", resource="activity", action="edit"),
        Permission(id=3, code="activity.delete", resource="activity", action="delete"),
        Permission(id=4, code="activity.view", resource="activity", action="view"),
        
        # Events
        Permission(id=5, code="event.create", resource="event", action="create"),
        Permission(id=6, code="event.edit", resource="event", action="edit"),
        Permission(id=7, code="event.view", resource="event", action="view"),
        
        # Catalog
        Permission(id=8, code="catalog.publish", resource="catalog", action="publish"),
        Permission(id=9, code="catalog.edit", resource="catalog", action="edit"),
        Permission(id=10, code="catalog.view", resource="catalog", action="view"),
        
        # Users
        Permission(id=11, code="user.create", resource="user", action="create"),
        Permission(id=12, code="user.edit", resource="user", action="edit"),
        Permission(id=13, code="user.view", resource="user", action="view"),
    ]
    
    for perm in permissions:
        _, created = _create_if_missing(
            db,
            Permission,
            lookup_filters={"id": perm.id},
            create_kwargs={
                "id": perm.id,
                "code": perm.code,
                "resource": perm.resource,
                "action": perm.action,
            },
        )
        if created:
            print(f"[OK] Created permission: {perm.code}")
    
    db.commit()


def seed_role_permissions(db: Session):
    """Asignar permisos a roles"""
    _get_role_or_raise(db, "ADMIN").permissions = db.query(Permission).all()

    _assign_permissions_by_codes(
        db,
        role_name="COORD",
        permission_codes=[
            "activity.create",
            "activity.edit",
            "activity.view",
            "event.create",
            "event.edit",
            "event.view",
            "catalog.view",
        ],
    )

    _assign_permissions_by_codes(
        db,
        role_name="SUPERVISOR",
        permission_codes=[
            "activity.create",
            "activity.edit",
            "activity.view",
            "event.create",
            "event.edit",
            "event.view",
        ],
    )

    _assign_permissions_by_codes(
        db,
        role_name="OPERATIVO",
        permission_codes=[
            "activity.create",
            "activity.view",
            "event.create",
            "event.view",
        ],
    )

    _assign_view_only_permissions(db, role_name="LECTOR")
    
    db.commit()
    print("[OK] Assigned permissions to roles")


def seed_project_tmq(db: Session):
    """Crear proyecto TMQ con 2 frentes"""
    # Proyecto
    _tmq, created_project = _create_if_missing(
        db,
        Project,
        lookup_filters={"id": "TMQ"},
        create_kwargs={
            "id": "TMQ",
            "name": "Tren México-Querétaro",
            "status": ProjectStatus.ACTIVE,
            "start_date": date(2024, 1, 1),
        },
    )
    if created_project:
        db.flush()
        print("[OK] Created project: TMQ")
    
    # Frentes
    fronts_data = [
        {"code": "F1", "name": "Frente 1 (CDMX-Tula)", "pk_start": 0, "pk_end": 60000},
        {"code": "F2", "name": "Frente 2 (Tula-Querétaro)", "pk_start": 60000, "pk_end": 210000},
    ]
    
    for front_data in fronts_data:
        front, created = _create_if_missing(
            db,
            Front,
            lookup_filters={"project_id": "TMQ", "code": front_data["code"]},
            create_kwargs={"id": uuid4(), "project_id": "TMQ", **front_data},
        )

        if created:
            print(f"[OK] Created front: {front.code}")
    
    db.commit()


def seed_reject_reasons(db: Session):
    """Crear razones de rechazo base (idempotente)."""
    default_reasons = [
        {
            "reason_code": "FOTO_BORROSA",
            "label": "Foto borrosa o ilegible",
            "severity": "MED",
            "requires_comment": False,
        },
        {
            "reason_code": "GPS_NO_COINCIDE",
            "label": "GPS no coincide con ubicación declarada",
            "severity": "HIGH",
            "requires_comment": True,
        },
        {
            "reason_code": "FALTA_INFORMACION",
            "label": "Falta información requerida",
            "severity": "MED",
            "requires_comment": True,
        },
        {
            "reason_code": "FOTO_INSUFICIENTE",
            "label": "Cantidad de fotos insuficiente",
            "severity": "MED",
            "requires_comment": False,
        },
        {
            "reason_code": "DATOS_INCONSISTENTES",
            "label": "Datos inconsistentes con el frente",
            "severity": "HIGH",
            "requires_comment": True,
        },
    ]
    inserted = 0
    for r in default_reasons:
        _, created = _create_if_missing(
            db,
            RejectReason,
            lookup_filters={"reason_code": r["reason_code"]},
            create_kwargs={**r, "is_active": True},
        )
        if created:
            inserted += 1
    db.commit()
    if inserted:
        print(f"[OK] Created {inserted} reject reason(s)")
    else:
        print("[SKIP] Reject reasons already seeded")


def seed_admin_user(db: Session):
    """Crear usuario admin"""
    admin, created = _create_if_missing(
        db,
        User,
        lookup_filters={"email": "admin@sao.mx"},
        create_kwargs={
            "id": uuid4(),
            "email": "admin@sao.mx",
            "password_hash": get_password_hash("admin123"),
            "full_name": "Administrador SAO",
            "status": UserStatus.ACTIVE,
        },
    )

    if created:
        db.flush()

        # Asignar rol ADMIN con scope global
        admin_role = _get_role_or_raise(db, "ADMIN")
        scope = UserRoleScope(
            id=uuid4(),
            user_id=admin.id,
            role_id=admin_role.id,
            project_id=None,  # Global
            front_id=None,
            location_id=None
        )
        db.add(scope)

        db.commit()
        print(f"[OK] Created admin user: {admin.email} (password: admin123)")
    else:
        print("[WARN] Admin user already exists")


def run_all_seeds(db: Session):
    """Ejecutar todos los seeds en orden"""
    print("\n[SEEDS] Running seeds...\n")

    seed_roles(db)
    seed_permissions(db)
    seed_role_permissions(db)
    processed_locations, inserted_locations = seed_mexico_locations_catalog(db)
    print(
        f"[OK] Mexico locations catalog processed={processed_locations} inserted={inserted_locations}"
    )
    seed_project_tmq(db)
    seed_admin_user(db)
    seed_reject_reasons(db)

    skip_effective_catalog_seed = os.getenv("SAO_SKIP_EFFECTIVE_CATALOG_SEED", "0").strip().lower() in {
        "1",
        "true",
        "yes",
        "on",
    }

    if skip_effective_catalog_seed:
        print("[WARN] Skipping effective catalog seed (SAO_SKIP_EFFECTIVE_CATALOG_SEED enabled)")
    else:
        # Catálogo efectivo (tablas catalog_version, cat_activities, etc.)
        # Requiere que la migración d3e4f5a6b7c8 esté aplicada.
        from app.seeds.effective_catalog_tmq_v1 import seed_effective_catalog_tmq
        seed_effective_catalog_tmq(db)

    print("\n[OK] Seeds completed successfully!\n")
