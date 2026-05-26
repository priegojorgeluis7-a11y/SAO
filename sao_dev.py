#!/usr/bin/env python3.11
"""
SAO Developer Console
─────────────────────
Herramienta de gestión y diagnóstico para desarrolladores del sistema SAO.

Uso:
    python3.11 sao_dev.py              # Modo interactivo (menú)
    python3.11 sao_dev.py health       # Solo check de salud
    python3.11 sao_dev.py tests        # Correr tests
    python3.11 sao_dev.py firestore    # Diagnóstico Firestore interactivo
    python3.11 sao_dev.py backend      # Iniciar backend local
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib import error as urllib_error
from urllib import request as urllib_request

# ─── Bootstrap rich/questionary ──────────────────────────────────────────────

def _ensure_dep(pkg: str) -> None:
    try:
        __import__(pkg)
    except ImportError:
        print(f"[sao_dev] Instalando {pkg}…")
        subprocess.check_call(
            [sys.executable, "-m", "pip", "install", pkg, "--quiet"],
            stdout=subprocess.DEVNULL,
        )

_ensure_dep("rich")
_ensure_dep("questionary")

from rich import box
from rich.columns import Columns
from rich.console import Console
from rich.panel import Panel
from rich.progress import Progress, SpinnerColumn, TextColumn
from rich.prompt import Confirm, Prompt
from rich.table import Table
from rich.text import Text
import questionary
from questionary import Style as QStyle

# ─── Config ──────────────────────────────────────────────────────────────────

ROOT = Path(__file__).resolve().parent
BACKEND_DIR = ROOT / "backend"
MOBILE_DIR  = ROOT / "frontend_flutter" / "sao_windows"
DESKTOP_DIR = ROOT / "desktop_flutter" / "sao_desktop"

PROD_URL    = "https://sao-api-97150883570.us-central1.run.app"
LOCAL_URL   = "http://localhost:8000"
FIRESTORE_PROJECT = "sao-prod-488416"

PYTHON = sys.executable  # usa el mismo intérprete con el que se lanzó este script

console = Console()

SAO_STYLE = QStyle([
    ("qmark",        "fg:#00b4d8 bold"),
    ("question",     "bold"),
    ("answer",       "fg:#90e0ef bold"),
    ("pointer",      "fg:#00b4d8 bold"),
    ("highlighted",  "fg:#00b4d8 bold"),
    ("selected",     "fg:#90e0ef"),
    ("separator",    "fg:#6c757d"),
    ("instruction",  "fg:#6c757d"),
])


# ─── Helpers HTTP ─────────────────────────────────────────────────────────────

def _get_json(url: str, token: str | None = None, timeout: int = 8) -> tuple[int, Any]:
    headers: dict[str, str] = {"Accept": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib_request.Request(url, headers=headers)
    try:
        with urllib_request.urlopen(req, timeout=timeout) as resp:
            return resp.status, json.loads(resp.read())
    except urllib_error.HTTPError as e:
        try:
            body = json.loads(e.read())
        except Exception:
            body = {}
        return e.code, body
    except Exception as e:
        return 0, {"error": str(e)}


def _post_json(url: str, data: dict, token: str | None = None, timeout: int = 10) -> tuple[int, Any]:
    headers: dict[str, str] = {"Content-Type": "application/json", "Accept": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    payload = json.dumps(data).encode()
    req = urllib_request.Request(url, data=payload, headers=headers, method="POST")
    try:
        with urllib_request.urlopen(req, timeout=timeout) as resp:
            return resp.status, json.loads(resp.read())
    except urllib_error.HTTPError as e:
        try:
            body = json.loads(e.read())
        except Exception:
            body = {}
        return e.code, body
    except Exception as e:
        return 0, {"error": str(e)}


def _login(base_url: str, email: str, password: str) -> str | None:
    code, body = _post_json(f"{base_url}/api/v1/auth/login", {"username": email, "password": password})
    if code == 200:
        return body.get("access_token")
    return None


# ─── Firestore helper ─────────────────────────────────────────────────────────

def _get_firestore():
    """Retorna cliente Firestore configurado para sao-prod-488416."""
    sys.path.insert(0, str(BACKEND_DIR))
    os.environ.setdefault("FIRESTORE_PROJECT_ID", FIRESTORE_PROJECT)
    os.environ.setdefault("DATA_BACKEND", "firestore")
    from google.cloud import firestore  # type: ignore
    return firestore.Client(project=FIRESTORE_PROJECT)


# ─── Secciones ────────────────────────────────────────────────────────────────

# ── 1. SALUD DEL SISTEMA ──────────────────────────────────────────────────────

def section_health(target: str = "both") -> None:
    """Comprueba el estado del backend local y/o productivo."""
    console.rule("[bold cyan]Salud del Sistema")
    table = Table(box=box.ROUNDED, show_header=True, header_style="bold magenta")
    table.add_column("Entorno", style="bold")
    table.add_column("URL")
    table.add_column("Estado")
    table.add_column("Versión")
    table.add_column("Latencia")

    targets: list[tuple[str, str]] = []
    if target in ("local", "both"):
        targets.append(("Local", LOCAL_URL))
    if target in ("prod", "both"):
        targets.append(("Producción", PROD_URL))

    with Progress(SpinnerColumn(), TextColumn("[progress.description]{task.description}"), transient=True) as p:
        task = p.add_task("Verificando endpoints…", total=None)
        for name, url in targets:
            t0 = time.monotonic()
            code, body = _get_json(f"{url}/health", timeout=12)
            latency = int((time.monotonic() - t0) * 1000)
            if code == 200:
                status_txt = Text("✅ OK", style="green bold")
                version = body.get("version", "—")
            elif code == 0:
                status_txt = Text("❌ Sin conexión", style="red bold")
                version = "—"
            else:
                status_txt = Text(f"⚠️  HTTP {code}", style="yellow bold")
                version = "—"
            table.add_row(name, url, status_txt, str(version), f"{latency} ms")
    console.print(table)

    # Firestore
    console.print("\n[bold]Verificando Firestore…[/bold]")
    try:
        db = _get_firestore()
        t0 = time.monotonic()
        list(db.collections())
        latency = int((time.monotonic() - t0) * 1000)
        console.print(f"  [green]✅ Firestore OK[/green]  proyecto=[cyan]{FIRESTORE_PROJECT}[/cyan]  latencia=[yellow]{latency} ms[/yellow]")
    except Exception as exc:
        console.print(f"  [red]❌ Firestore error:[/red] {exc}")


# ── 2. BACKEND LOCAL ──────────────────────────────────────────────────────────

def section_backend() -> None:
    console.rule("[bold cyan]Backend Local")
    opciones = [
        "Iniciar backend local (uvicorn)",
        "Ver estado del proceso uvicorn",
        "Correr todos los tests",
        "Correr tests por módulo",
        "Correr E2E local",
        "Instalar dependencias (pip install -r requirements.txt)",
        "← Volver",
    ]
    choice = questionary.select("Acción:", choices=opciones, style=SAO_STYLE).ask()
    if choice is None or choice.startswith("←"):
        return

    if choice.startswith("Iniciar"):
        _start_backend()
    elif choice.startswith("Ver estado"):
        _check_uvicorn_process()
    elif choice == "Correr todos los tests":
        _run_tests()
    elif choice.startswith("Correr tests por módulo"):
        _run_tests_by_module()
    elif choice.startswith("Correr E2E"):
        _run_e2e()
    elif choice.startswith("Instalar"):
        _install_backend_deps()


def _start_backend() -> None:
    console.print("\n[yellow]Iniciando uvicorn en localhost:8000…[/yellow]")
    console.print("[dim]Presiona Ctrl+C para detener.[/dim]\n")
    env = {**os.environ,
           "FIRESTORE_PROJECT_ID": FIRESTORE_PROJECT,
           "DATA_BACKEND": "firestore",
           "EVIDENCE_STORAGE_BACKEND": "local",
           "JWT_SECRET": os.environ.get("JWT_SECRET", "dev-secret-change-me")}
    try:
        subprocess.run(
            [PYTHON, "-m", "uvicorn", "app.main:app", "--reload",
             "--host", "0.0.0.0", "--port", "8000"],
            cwd=BACKEND_DIR,
            env=env,
        )
    except KeyboardInterrupt:
        console.print("\n[yellow]Backend detenido.[/yellow]")


def _check_uvicorn_process() -> None:
    result = subprocess.run(
        ["pgrep", "-a", "-f", "uvicorn"], capture_output=True, text=True
    )
    if result.stdout.strip():
        console.print(f"[green]uvicorn corriendo:[/green]\n{result.stdout.strip()}")
    else:
        console.print("[yellow]uvicorn no está corriendo.[/yellow]")


def _run_tests(module: str = "") -> None:
    console.rule("[bold cyan]Ejecutando Tests")
    cmd = [PYTHON, "-m", "pytest", "tests", "-v", "--tb=short", "-q"]
    if module:
        cmd = [PYTHON, "-m", "pytest", f"tests/{module}", "-v", "--tb=short"]
    env = {**os.environ,
           "FIRESTORE_PROJECT_ID": FIRESTORE_PROJECT,
           "DATA_BACKEND": "firestore"}
    console.print(f"[dim]$ {' '.join(cmd)}[/dim]\n")
    subprocess.run(cmd, cwd=BACKEND_DIR, env=env)


def _run_tests_by_module() -> None:
    test_files = sorted([f.name for f in (BACKEND_DIR / "tests").glob("test_*.py")])
    if not test_files:
        console.print("[red]No se encontraron archivos de test.[/red]")
        return
    choice = questionary.select("Módulo de test:", choices=test_files + ["← Cancelar"], style=SAO_STYLE).ask()
    if choice and not choice.startswith("←"):
        _run_tests(choice)


def _run_e2e() -> None:
    console.rule("[bold cyan]E2E Local")
    console.print("[yellow]Asegúrate de que el backend local esté corriendo en :8000[/yellow]\n")
    script = BACKEND_DIR / "scripts" / "e2e_local.py"
    subprocess.run([PYTHON, str(script)], cwd=BACKEND_DIR)


def _install_backend_deps() -> None:
    console.print("[cyan]Instalando dependencias…[/cyan]")
    subprocess.run([PYTHON, "-m", "pip", "install", "-r", "requirements.txt"], cwd=BACKEND_DIR)


# ── 3. FIRESTORE DATA ─────────────────────────────────────────────────────────

def section_firestore() -> None:
    console.rule("[bold cyan]Firestore Data Explorer")
    opciones = [
        "Resumen de proyectos",
        "Actividades por proyecto",
        "Actividades COMPLETADA sin review_decision",
        "Actividades en estado problemático",
        "Usuarios del sistema",
        "Catálogos activos",
        "Buscar actividad por ID",
        "← Volver",
    ]
    choice = questionary.select("Consulta:", choices=opciones, style=SAO_STYLE).ask()
    if choice is None or choice.startswith("←"):
        return

    try:
        db = _get_firestore()
    except Exception as exc:
        console.print(f"[red]Error conectando a Firestore:[/red] {exc}")
        return

    if choice.startswith("Resumen"):
        _fs_projects_summary(db)
    elif choice.startswith("Actividades por proyecto"):
        _fs_activities_by_project(db)
    elif choice.startswith("Actividades COMPLETADA"):
        _fs_completadas_sin_review(db)
    elif choice.startswith("Actividades en estado problemático"):
        _fs_problematic_activities(db)
    elif choice.startswith("Usuarios"):
        _fs_users(db)
    elif choice.startswith("Catálogos"):
        _fs_catalogs(db)
    elif choice.startswith("Buscar actividad"):
        _fs_activity_by_id(db)


def _fs_projects_summary(db) -> None:
    console.print("[dim]Cargando proyectos…[/dim]")
    projects = [d.to_dict() or {} for d in db.collection("projects").stream()]
    table = Table(title="Proyectos", box=box.ROUNDED)
    table.add_column("ID", style="cyan bold")
    table.add_column("Nombre")
    table.add_column("Estado")
    table.add_column("Activo")
    for p in sorted(projects, key=lambda x: x.get("project_id", "")):
        pid = p.get("project_id", p.get("id", "—"))
        table.add_row(
            str(pid),
            str(p.get("name", p.get("project_name", "—"))),
            str(p.get("status", "—")),
            "✅" if p.get("is_active", p.get("active", True)) else "❌",
        )
    console.print(table)
    console.print(f"\n[bold]Total: {len(projects)} proyectos[/bold]")


def _fs_activities_by_project(db) -> None:
    projects = [d.to_dict() or {} for d in db.collection("projects").stream()]
    pids = sorted([p.get("project_id", p.get("id", "")) for p in projects if p.get("project_id") or p.get("id")])
    if not pids:
        console.print("[yellow]Sin proyectos en Firestore.[/yellow]")
        return
    pid = questionary.select("Proyecto:", choices=pids + ["← Cancelar"], style=SAO_STYLE).ask()
    if not pid or pid.startswith("←"):
        return

    console.print(f"[dim]Cargando actividades de {pid}…[/dim]")
    docs = list(db.collection("activities").where("project_id", "==", pid).stream())
    activities = [d.to_dict() or {} for d in docs]
    active = [a for a in activities if not a.get("deleted_at")]

    # Conteo por estado
    from collections import Counter
    states = Counter(str(a.get("execution_state", "—")).upper() for a in active)

    table = Table(title=f"Actividades — {pid} ({len(active)} activas / {len(activities)} total)", box=box.ROUNDED)
    table.add_column("Estado", style="bold")
    table.add_column("Cantidad", justify="right")
    STATE_COLOR = {
        "REVISION_PENDIENTE": "yellow",
        "COMPLETADA": "green",
        "APROBADA": "bright_green",
        "RECHAZADA": "red",
        "EN_PROGRESO": "cyan",
        "CANCELADA": "dim",
    }
    for state, count in sorted(states.items()):
        color = STATE_COLOR.get(state, "white")
        table.add_row(f"[{color}]{state}[/{color}]", str(count))
    console.print(table)


def _fs_completadas_sin_review(db) -> None:
    console.print("[dim]Buscando actividades COMPLETADA sin review_decision…[/dim]")
    query = (db.collection("activities")
             .where("execution_state", "==", "COMPLETADA"))
    results = []
    for snap in query.stream():
        doc = snap.to_dict() or {}
        if doc.get("deleted_at"):
            continue
        if not str(doc.get("review_decision") or "").strip():
            doc["_id"] = snap.id
            results.append(doc)

    if not results:
        console.print("[green]✅ No hay actividades COMPLETADA sin review_decision.[/green]")
        return

    table = Table(title=f"COMPLETADA sin review_decision ({len(results)})", box=box.ROUNDED)
    table.add_column("ID Doc", style="dim", max_width=36)
    table.add_column("Proyecto", style="cyan")
    table.add_column("Tipo")
    table.add_column("front_id")
    table.add_column("pk_start")
    table.add_column("Usuario")
    for d in results[:50]:
        table.add_row(
            d["_id"], str(d.get("project_id", "—")),
            str(d.get("activity_type_code", "—")),
            str(d.get("front_id", "—")),
            str(d.get("pk_start", "—")),
            str(d.get("created_by_user_id", "—")),
        )
    console.print(table)
    if len(results) > 50:
        console.print(f"[yellow]… y {len(results) - 50} más[/yellow]")


def _fs_problematic_activities(db) -> None:
    console.print("[dim]Analizando actividades problemáticas…[/dim]")
    problems: list[dict] = []

    # REVISION_PENDIENTE sin assignment_end_at (posiblemente colgadas)
    for snap in db.collection("activities").where("execution_state", "==", "REVISION_PENDIENTE").stream():
        doc = snap.to_dict() or {}
        if doc.get("deleted_at"):
            continue
        if not doc.get("assignment_end_at"):
            doc["_id"] = snap.id
            doc["_issue"] = "REVISION_PENDIENTE sin fecha fin"
            problems.append(doc)

    if not problems:
        console.print("[green]✅ No se detectaron actividades problemáticas.[/green]")
        return

    table = Table(title=f"Actividades Problemáticas ({len(problems)})", box=box.ROUNDED)
    table.add_column("Problema", style="yellow bold")
    table.add_column("Proyecto")
    table.add_column("ID Doc", style="dim", max_width=36)
    table.add_column("Tipo")
    table.add_column("Usuario")
    for d in problems[:30]:
        table.add_row(
            d.get("_issue", "—"), str(d.get("project_id", "—")),
            d["_id"], str(d.get("activity_type_code", "—")),
            str(d.get("created_by_user_id", "—")),
        )
    console.print(table)


def _fs_users(db) -> None:
    console.print("[dim]Cargando usuarios…[/dim]")
    users = [d.to_dict() or {} for d in db.collection("users").stream()]
    table = Table(title=f"Usuarios ({len(users)})", box=box.ROUNDED)
    table.add_column("ID", style="cyan")
    table.add_column("Email")
    table.add_column("Rol", style="magenta")
    table.add_column("Activo")
    table.add_column("Proyectos")
    for u in sorted(users, key=lambda x: str(x.get("email", ""))):
        projs = ", ".join(u.get("assigned_projects", u.get("projects", [])) or [])
        table.add_row(
            str(u.get("user_id", u.get("id", "—"))),
            str(u.get("email", "—")),
            str(u.get("role", u.get("roles", ["—"])[0] if isinstance(u.get("roles"), list) else "—")),
            "✅" if u.get("is_active", True) else "❌",
            projs or "—",
        )
    console.print(table)


def _fs_catalogs(db) -> None:
    console.print("[dim]Cargando catálogos activos…[/dim]")
    cats = [d.to_dict() or {} for d in db.collection("catalog_bundles").stream()]
    if not cats:
        cats = [d.to_dict() or {} for d in db.collection("catalogs").stream()]
    table = Table(title=f"Catálogos ({len(cats)})", box=box.ROUNDED)
    table.add_column("ID", style="cyan", max_width=36)
    table.add_column("Versión")
    table.add_column("Activo")
    table.add_column("Proyecto")
    for c in cats:
        table.add_row(
            str(c.get("id", c.get("catalog_id", "—"))),
            str(c.get("version", "—")),
            "✅" if c.get("is_active", c.get("active", True)) else "❌",
            str(c.get("project_id", "todos")),
        )
    console.print(table)


def _fs_activity_by_id(db) -> None:
    activity_id = Prompt.ask("ID del documento Firestore o front_id")
    if not activity_id.strip():
        return

    doc = db.collection("activities").document(activity_id.strip()).get()
    if doc.exists:
        data = doc.to_dict() or {}
        _print_activity_detail(activity_id, data)
        return

    # Buscar por front_id
    console.print("[dim]Buscando por front_id…[/dim]")
    results = list(db.collection("activities").where("front_id", "==", activity_id.strip()).stream())
    if not results:
        console.print(f"[yellow]No se encontró actividad con ID/front_id '{activity_id}'[/yellow]")
        return
    for snap in results:
        _print_activity_detail(snap.id, snap.to_dict() or {})


def _print_activity_detail(doc_id: str, data: dict) -> None:
    table = Table(title=f"Actividad: {doc_id}", box=box.ROUNDED, show_header=False)
    table.add_column("Campo", style="cyan bold", min_width=28)
    table.add_column("Valor")
    fields = [
        "project_id", "activity_type_code", "execution_state", "review_decision",
        "assigned_to_user_id", "created_by_user_id", "front_id", "pk_start",
        "assignment_start_at", "assignment_end_at",
        "activity_group_id", "deleted_at", "updated_at", "created_at",
    ]
    for f in fields:
        val = data.get(f)
        if val is not None:
            table.add_row(f, str(val))
    console.print(table)


# ── 4. GESTIÓN DE USUARIOS ────────────────────────────────────────────────────

def section_users() -> None:
    console.rule("[bold cyan]Gestión de Usuarios")
    opciones = [
        "Listar usuarios (vía API local)",
        "Listar usuarios (Firestore directo)",
        "Resetear usuario admin",
        "← Volver",
    ]
    choice = questionary.select("Acción:", choices=opciones, style=SAO_STYLE).ask()
    if choice is None or choice.startswith("←"):
        return

    if "API local" in choice:
        _users_via_api()
    elif "Firestore directo" in choice:
        db = _get_firestore()
        _fs_users(db)
    elif "Resetear" in choice:
        _reset_admin()


def _users_via_api() -> None:
    email = Prompt.ask("Email admin", default="admin@sao.mx")
    password = Prompt.ask("Password", password=True)
    token = _login(LOCAL_URL, email, password)
    if not token:
        console.print("[red]Login fallido. ¿Está corriendo el backend local?[/red]")
        return
    code, body = _get_json(f"{LOCAL_URL}/api/v1/users", token=token)
    if code != 200:
        console.print(f"[red]Error {code}:[/red] {body}")
        return
    users = body if isinstance(body, list) else body.get("items", [])
    table = Table(title=f"Usuarios ({len(users)})", box=box.ROUNDED)
    table.add_column("ID", style="cyan")
    table.add_column("Email")
    table.add_column("Rol")
    table.add_column("Activo")
    for u in users:
        table.add_row(
            str(u.get("user_id", "—")),
            str(u.get("email", "—")),
            str(u.get("role", "—")),
            "✅" if u.get("is_active", True) else "❌",
        )
    console.print(table)


def _reset_admin() -> None:
    script = BACKEND_DIR / "scripts" / "reset_admin_user.py"
    if not script.exists():
        console.print(f"[red]Script no encontrado: {script}[/red]")
        return
    env = {**os.environ,
           "FIRESTORE_PROJECT_ID": FIRESTORE_PROJECT,
           "DATA_BACKEND": "firestore"}
    subprocess.run([PYTHON, str(script)], cwd=BACKEND_DIR, env=env)


# ── 5. DIAGNÓSTICOS ───────────────────────────────────────────────────────────

def section_diagnostics() -> None:
    console.rule("[bold cyan]Diagnósticos")
    opciones = [
        "Smoke test producción (API)",
        "Análisis de sync (Firestore)",
        "Actividades sin group_id (deduplicación)",
        "Verificar catálogos base",
        "Health check completo",
        "← Volver",
    ]
    choice = questionary.select("Diagnóstico:", choices=opciones, style=SAO_STYLE).ask()
    if choice is None or choice.startswith("←"):
        return

    if choice.startswith("Smoke"):
        _smoke_test()
    elif choice.startswith("Análisis de sync"):
        _sync_analysis()
    elif choice.startswith("Actividades sin group_id"):
        _check_group_ids()
    elif choice.startswith("Verificar catálogos"):
        _verify_catalogs()
    elif choice.startswith("Health check"):
        section_health()


def _smoke_test() -> None:
    console.rule("[bold cyan]Smoke Test — Producción")
    email = Prompt.ask("Email", default=os.environ.get("SAO_SMOKE_EMAIL", ""))
    password = Prompt.ask("Password", password=True)
    if not email or not password:
        console.print("[red]Credenciales requeridas.[/red]")
        return

    with Progress(SpinnerColumn(), TextColumn("[progress.description]{task.description}"), transient=True) as p:
        p.add_task("Conectando a producción…", total=None)
        code, body = _get_json(f"{PROD_URL}/health")

    if code != 200:
        console.print(f"[red]❌ Backend prod no responde (HTTP {code})[/red]")
        return
    console.print(f"[green]✅ Health OK[/green] — versión: {body.get('version', '—')}")

    token = _login(PROD_URL, email, password)
    if token:
        console.print("[green]✅ Login exitoso[/green]")
        code2, me_body = _get_json(f"{PROD_URL}/api/v1/auth/me", token=token)
        if code2 == 200:
            console.print(f"   Usuario: [cyan]{me_body.get('email')}[/cyan]  rol: [magenta]{me_body.get('role')}[/magenta]")
    else:
        console.print("[red]❌ Login fallido[/red]")


def _sync_analysis() -> None:
    console.print("[dim]Analizando sync…[/dim]")
    db = _get_firestore()
    projects = [d.to_dict() or {} for d in db.collection("projects").stream()]
    pid = questionary.select(
        "Proyecto:",
        choices=[p.get("project_id", p.get("id", "")) for p in projects] + ["← Cancelar"],
        style=SAO_STYLE,
    ).ask()
    if not pid or pid.startswith("←"):
        return

    docs = list(db.collection("activities").where("project_id", "==", pid).stream())
    from collections import Counter
    states = Counter()
    sync_issues = []
    for snap in docs:
        doc = snap.to_dict() or {}
        if doc.get("deleted_at"):
            continue
        state = str(doc.get("execution_state", "—")).upper()
        states[state] += 1
        # Detectar actividades con sync_status problemático
        ss = str(doc.get("sync_status") or "").upper()
        if ss in ("ERROR", "CONFLICT", "PENDING"):
            doc["_id"] = snap.id
            doc["_sync_status"] = ss
            sync_issues.append(doc)

    console.print(f"\n[bold]Distribución de estados — {pid}:[/bold]")
    for st, cnt in sorted(states.items()):
        console.print(f"  {st}: [yellow]{cnt}[/yellow]")

    if sync_issues:
        console.print(f"\n[bold yellow]Problemas de sync detectados: {len(sync_issues)}[/bold yellow]")
        for d in sync_issues[:10]:
            console.print(f"  [{d['_sync_status']}] {d['_id']} — estado: {d.get('execution_state')}")
    else:
        console.print("\n[green]✅ Sin problemas de sync detectados.[/green]")


def _check_group_ids() -> None:
    console.print("[dim]Verificando activity_group_id…[/dim]")
    db = _get_firestore()
    docs = list(db.collection("activities").stream())
    sin_gid = [d for d in docs if not (d.to_dict() or {}).get("activity_group_id") and not (d.to_dict() or {}).get("deleted_at")]
    console.print(f"Total actividades: [cyan]{len(docs)}[/cyan]")
    console.print(f"Sin activity_group_id (no eliminadas): [yellow]{len(sin_gid)}[/yellow]")
    if sin_gid and Confirm.ask("¿Ver primeras 10?", default=False):
        for snap in sin_gid[:10]:
            data = snap.to_dict() or {}
            console.print(f"  {snap.id}  proyecto={data.get('project_id')}  estado={data.get('execution_state')}")


def _verify_catalogs() -> None:
    script = BACKEND_DIR / "scripts" / "ensure_firestore_base_catalogs.py"
    if not script.exists():
        console.print(f"[red]Script no encontrado: {script}[/red]")
        return
    env = {**os.environ,
           "FIRESTORE_PROJECT_ID": FIRESTORE_PROJECT,
           "DATA_BACKEND": "firestore"}
    dry_run = Confirm.ask("¿Solo verificar (dry-run)?", default=True)
    cmd = [PYTHON, str(script)]
    if dry_run:
        cmd.append("--dry-run")
    subprocess.run(cmd, cwd=BACKEND_DIR, env=env)


# ── 6. FLUTTER APPS ───────────────────────────────────────────────────────────

def section_flutter() -> None:
    console.rule("[bold cyan]Flutter Apps")
    opciones = [
        "📱 Mobile — flutter analyze",
        "📱 Mobile — flutter test",
        "📱 Mobile — flutter pub get",
        "📱 Mobile — build_runner",
        "🖥  Desktop — flutter analyze",
        "🖥  Desktop — flutter test",
        "🖥  Desktop — flutter pub get",
        "🖥  Desktop — build_runner",
        "🖥  Desktop — Run macOS (prod backend)",
        "🖥  Desktop — Run macOS (local backend)",
        "← Volver",
    ]
    choice = questionary.select("Acción Flutter:", choices=opciones, style=SAO_STYLE).ask()
    if choice is None or choice.startswith("←"):
        return

    flutter = shutil.which("flutter") or "flutter"

    def run_flutter(args: list[str], cwd: Path) -> None:
        cmd = [flutter] + args
        console.print(f"[dim]$ cd {cwd.name} && {' '.join(cmd)}[/dim]\n")
        subprocess.run(cmd, cwd=cwd)

    if "Mobile" in choice:
        work_dir = MOBILE_DIR
    else:
        work_dir = DESKTOP_DIR

    if "analyze" in choice:
        run_flutter(["analyze"], work_dir)
    elif "flutter test" in choice:
        run_flutter(["test"], work_dir)
    elif "pub get" in choice:
        run_flutter(["pub", "get"], work_dir)
    elif "build_runner" in choice:
        dart = shutil.which("dart") or "dart"
        cmd = [dart, "run", "build_runner", "build", "--delete-conflicting-outputs"]
        console.print(f"[dim]$ {' '.join(cmd)}[/dim]\n")
        subprocess.run(cmd, cwd=work_dir)
    elif "Run macOS (prod" in choice:
        run_flutter([
            "run", "-d", "macos",
            f"--dart-define=SAO_BACKEND_URL={PROD_URL}",
        ], DESKTOP_DIR)
    elif "Run macOS (local" in choice:
        local_ip = _get_local_ip()
        run_flutter([
            "run", "-d", "macos",
            f"--dart-define=SAO_BACKEND_URL=http://{local_ip}:8000",
        ], DESKTOP_DIR)


def _get_local_ip() -> str:
    try:
        import socket
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
    except Exception:
        return "192.168.1.100"


# ── 7. DEPLOY ─────────────────────────────────────────────────────────────────

def section_deploy() -> None:
    console.rule("[bold cyan]Deploy")
    opciones = [
        "Ver revisión activa en Cloud Run",
        "Logs recientes de Cloud Run",
        "← Volver",
    ]
    choice = questionary.select("Acción:", choices=opciones, style=SAO_STYLE).ask()
    if choice is None or choice.startswith("←"):
        return

    gcloud = shutil.which("gcloud")
    if not gcloud:
        console.print("[red]gcloud CLI no encontrado. Instala Google Cloud SDK.[/red]")
        return

    if choice.startswith("Ver revisión"):
        subprocess.run([gcloud, "run", "services", "describe", "sao-api",
                        "--region", "us-central1",
                        "--project", FIRESTORE_PROJECT,
                        "--format", "table(status.traffic[].revisionName,status.traffic[].percent)"])
    elif choice.startswith("Logs"):
        lines = Prompt.ask("Cuántas líneas", default="50")
        subprocess.run([gcloud, "logging", "read",
                        "resource.type=cloud_run_revision AND resource.labels.service_name=sao-api",
                        f"--limit={lines}",
                        "--project", FIRESTORE_PROJECT,
                        "--format", "table(timestamp,severity,textPayload)"])


# ── 8. HERRAMIENTAS RÁPIDAS ───────────────────────────────────────────────────

def section_quick_tools() -> None:
    console.rule("[bold cyan]Herramientas Rápidas")
    opciones = [
        "Generar reporte CSV (plantilla_reporte_attrapi.py)",
        "Ver VERSION del proyecto",
        "Ver git log reciente",
        "Abrir docs en browser",
        "← Volver",
    ]
    choice = questionary.select("Tool:", choices=opciones, style=SAO_STYLE).ask()
    if choice is None or choice.startswith("←"):
        return

    if "reporte CSV" in choice:
        script = ROOT / "tools" / "plantilla_reporte_attrapi.py"
        if script.exists():
            subprocess.run([PYTHON, str(script)], cwd=ROOT)
        else:
            console.print(f"[red]Script no encontrado: {script}[/red]")
    elif "VERSION" in choice:
        ver = (ROOT / "VERSION").read_text().strip()
        console.print(f"[bold green]Versión:[/bold green] {ver}")
    elif "git log" in choice:
        subprocess.run(["git", "--no-pager", "log", "--oneline", "-20"], cwd=ROOT)
    elif "docs" in choice:
        subprocess.run(["open", str(ROOT / "docs" / "README.md")])


# ─── Menú principal ───────────────────────────────────────────────────────────

MENU_ITEMS = [
    ("🔍  Salud del Sistema",          section_health),
    ("⚙️   Backend Local & Tests",     section_backend),
    ("🗄️   Firestore Data Explorer",   section_firestore),
    ("👥  Gestión de Usuarios",        section_users),
    ("🩺  Diagnósticos",               section_diagnostics),
    ("📲  Flutter Apps",               section_flutter),
    ("🚀  Deploy & Cloud Run",         section_deploy),
    ("🛠️   Herramientas Rápidas",      section_quick_tools),
    ("❌  Salir",                       None),
]


def print_header() -> None:
    now = datetime.now().strftime("%d/%m/%Y %H:%M")
    console.print(Panel.fit(
        f"[bold cyan]SAO Developer Console[/bold cyan]\n"
        f"[dim]Sistema de Administración de Obras[/dim]\n"
        f"[dim]Proyecto: {FIRESTORE_PROJECT} · {now}[/dim]",
        box=box.DOUBLE_EDGE,
        border_style="cyan",
    ))


def main_menu() -> None:
    print_header()
    while True:
        console.print()
        labels = [label for label, _ in MENU_ITEMS]
        choice = questionary.select(
            "Selecciona una sección:",
            choices=labels,
            style=SAO_STYLE,
        ).ask()
        if choice is None:
            break
        for label, fn in MENU_ITEMS:
            if label == choice:
                if fn is None:
                    console.print("[dim]¡Hasta luego![/dim]")
                    return
                console.print()
                try:
                    fn()
                except KeyboardInterrupt:
                    console.print("\n[yellow]Operación cancelada.[/yellow]")
                except Exception as exc:
                    console.print_exception()
                break


# ─── CLI directa ──────────────────────────────────────────────────────────────

def main() -> None:
    args = sys.argv[1:]
    if not args:
        main_menu()
        return

    cmd = args[0].lower()
    COMMANDS = {
        "health":      lambda: section_health("both"),
        "health-local":lambda: section_health("local"),
        "health-prod": lambda: section_health("prod"),
        "tests":       _run_tests,
        "e2e":         _run_e2e,
        "backend":     _start_backend,
        "firestore":   section_firestore,
        "users":       section_users,
        "diagnostics": section_diagnostics,
        "flutter":     section_flutter,
        "deploy":      section_deploy,
    }
    if cmd in COMMANDS:
        print_header()
        COMMANDS[cmd]()
    elif cmd in ("--help", "-h", "help"):
        console.print(__doc__)
    else:
        console.print(f"[red]Comando desconocido: {cmd}[/red]")
        console.print(f"Disponibles: {', '.join(COMMANDS)}")
        sys.exit(1)


if __name__ == "__main__":
    main()
