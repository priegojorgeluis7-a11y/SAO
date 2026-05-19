import json
import logging
import time
from contextlib import asynccontextmanager
from pathlib import Path
from uuid import uuid4

from fastapi import Depends, FastAPI, HTTPException, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from app.api.v1 import (
    activities,
    activities_cancel,
    activities_validate,
    assignments,
    audit,
    auth,
    catalog,
    catalog_candidates,
    invitations,
    completed_activities,
    dashboard,
    dashboard_kpis,
    evidences,
    events,
    me,
    notifications,
    ocr,
    observations,
    projects,
    reports,
    review,
    sync,
    system_config,
    territory,
    users,
)
from app.core.config import settings
from app.core.firestore import check_firestore_connection
from app.core.request_context import reset_trace_id, set_trace_id

_access_logger = logging.getLogger("sao.access")


class _JsonFormatter(logging.Formatter):
    """Emit each log record as a single JSON line (Cloud Run compatible)."""

    def format(self, record: logging.LogRecord) -> str:
        payload: dict = {
            "severity": record.levelname,
            "message": record.getMessage(),
            "logger": record.name,
            "ts": self.formatTime(record, "%Y-%m-%dT%H:%M:%S"),
        }
        for key in ("trace_id", "method", "path", "status_code", "latency_ms", "user_id", "project_id"):
            if hasattr(record, key):
                payload[key] = getattr(record, key)
        if record.exc_info:
            payload["exc"] = self.formatException(record.exc_info)
        return json.dumps(payload, ensure_ascii=False)


def _configure_logging() -> None:
    """Switch root logger to JSON output when running in production."""
    from app.core.config import settings as _s  # local import avoids circular

    if _s.ENV == "development":
        return
    root = logging.getLogger()
    if root.handlers:
        for h in list(root.handlers):
            root.removeHandler(h)
    handler = logging.StreamHandler()
    handler.setFormatter(_JsonFormatter())
    root.addHandler(handler)
    root.setLevel(logging.INFO)


@asynccontextmanager
async def lifespan(_app: FastAPI):
    """Application lifespan hook to validate required settings at startup."""
    _configure_logging()
    _ = settings.JWT_SECRET
    _ = settings.FIRESTORE_PROJECT_ID
    if settings.EVIDENCE_STORAGE_BACKEND == "local":
        Path(settings.LOCAL_UPLOADS_DIR).mkdir(parents=True, exist_ok=True)
    else:
        _ = settings.GCS_BUCKET
    yield

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    lifespan=lifespan,
)


@app.middleware("http")
async def attach_trace_id(request: Request, call_next):
    """Attach and propagate request trace_id in context and response headers."""
    incoming_trace_id = request.headers.get("X-Trace-Id")
    trace_id = incoming_trace_id.strip() if incoming_trace_id else uuid4().hex
    request.state.trace_id = trace_id
    token = set_trace_id(trace_id)
    start_ms = time.monotonic()
    try:
        response = await call_next(request)
    finally:
        reset_trace_id(token)
    latency_ms = round((time.monotonic() - start_ms) * 1000, 1)
    response.headers["X-Trace-Id"] = trace_id
    user_id = getattr(request.state, "user_id", None)
    project_id = getattr(request.state, "project_id", None)
    _access_logger.info(
        "%s %s %s",
        request.method,
        request.url.path,
        response.status_code,
        extra={
            "trace_id": trace_id,
            "method": request.method,
            "path": request.url.path,
            "status_code": response.status_code,
            "latency_ms": latency_ms,
            "user_id": user_id,
            "project_id": project_id,
        },
    )
    return response

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.get_cors_origins_list(),
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-Request-Id"],
)

# Local file storage — serve uploaded evidence files as static assets (dev only)
if settings.EVIDENCE_STORAGE_BACKEND == "local":
    uploads_dir = Path(settings.LOCAL_UPLOADS_DIR)
    uploads_dir.mkdir(parents=True, exist_ok=True)
    app.mount("/uploads", StaticFiles(directory=str(uploads_dir)), name="uploads")

# Include routers
app.include_router(auth.router, prefix=settings.API_V1_STR)
app.include_router(catalog.router, prefix=settings.API_V1_STR)
app.include_router(catalog_candidates.router, prefix=settings.API_V1_STR)
app.include_router(activities.router, prefix=settings.API_V1_STR)
app.include_router(activities_validate.router, prefix=settings.API_V1_STR)
app.include_router(activities_cancel.router, prefix=settings.API_V1_STR)
app.include_router(sync.router, prefix=settings.API_V1_STR)
app.include_router(evidences.router, prefix=settings.API_V1_STR)
app.include_router(events.router, prefix=settings.API_V1_STR)
app.include_router(notifications.router, prefix=settings.API_V1_STR)
app.include_router(me.router, prefix=settings.API_V1_STR)
app.include_router(users.router, prefix=settings.API_V1_STR)
app.include_router(invitations.router, prefix=settings.API_V1_STR)
app.include_router(assignments.router, prefix=settings.API_V1_STR)
app.include_router(projects.router, prefix=settings.API_V1_STR)
app.include_router(territory.router, prefix=settings.API_V1_STR)
app.include_router(audit.router, prefix=settings.API_V1_STR)
app.include_router(review.router, prefix=settings.API_V1_STR)
app.include_router(observations.router, prefix=settings.API_V1_STR)
app.include_router(ocr.router, prefix=settings.API_V1_STR)
app.include_router(reports.router, prefix=settings.API_V1_STR)
app.include_router(dashboard.router, prefix=settings.API_V1_STR)
app.include_router(system_config.router, prefix=settings.API_V1_STR)
app.include_router(dashboard_kpis.router, prefix=settings.API_V1_STR)
app.include_router(completed_activities.router, prefix=settings.API_V1_STR)


@app.get("/privacy-policy", response_class=HTMLResponse, include_in_schema=False)
def privacy_policy():
    """Política de privacidad pública de SAO (sin autenticación)."""
    html = """<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Política de Privacidad – SAO</title>
<style>
  body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;max-width:860px;margin:40px auto;padding:0 20px;color:#1a1a1a;line-height:1.7}
  h1{font-size:1.8rem;margin-bottom:4px}
  h2{font-size:1.2rem;margin-top:2rem;border-bottom:1px solid #ddd;padding-bottom:4px}
  p,li{font-size:0.97rem}
  a{color:#0066cc}
  .meta{color:#555;font-size:0.9rem;margin-bottom:2rem}
</style>
</head>
<body>
<h1>Política de Privacidad de SAO</h1>
<p class="meta">Sistema de Administración Operativa (SAO) &mdash; Versión 1.0 &mdash; 2026-04-06</p>

<p>SAO respeta la privacidad de sus usuarios y protege la información personal que se utiliza durante la operación de la plataforma. Los datos que pueden tratarse incluyen información de identificación básica, datos operativos, evidencias, registros de actividad, datos técnicos de sesión y, cuando aplica, ubicación vinculada a actividades de campo.</p>
<p>Esta información se utiliza exclusivamente para fines de autenticación, operación del sistema, seguimiento de actividades, sincronización, seguridad, auditoría y soporte. SAO no vende datos personales ni los utiliza para fines publicitarios ajenos a la funcionalidad de la plataforma.</p>
<p>El usuario puede solicitar información sobre el tratamiento de sus datos o ejercer sus derechos de acceso, rectificación, cancelación u oposición escribiendo a: <a href="mailto:priegojorgeluis7@gmail.com">priegojorgeluis7@gmail.com</a>.</p>

<h2>1. Responsable del tratamiento</h2>
<p>Correo de privacidad: <a href="mailto:priegojorgeluis7@gmail.com">priegojorgeluis7@gmail.com</a> &mdash; Teléfono: 5537741179</p>

<h2>2. Datos que SAO puede tratar</h2>
<ul>
  <li>Datos de identificación: nombre, correo, rol, proyecto asignado.</li>
  <li>Datos operativos: actividades, asignaciones, estatus, comentarios, historial.</li>
  <li>Evidencias: fotografías, videos, documentos y sus metadatos.</li>
  <li>Ubicación: coordenadas GPS cuando la operación lo requiere.</li>
  <li>Datos técnicos: tokens de sesión, registros de acceso, IP y bitácoras de auditoría.</li>
</ul>

<h2>3. Finalidad del tratamiento</h2>
<p>Los datos se usan para autenticar usuarios, operar flujos de trabajo, registrar evidencias, coordinar actividades, mantener sincronización, generar reportes y cumplir obligaciones contractuales y legales. SAO no comercializa datos personales.</p>

<h2>4. Permisos del dispositivo</h2>
<p>La aplicación puede solicitar acceso a <strong>cámara</strong> (captura de evidencias), <strong>ubicación</strong> (georreferenciación de actividades), <strong>fotos/archivos</strong> (adjuntar documentos) y <strong>biometría/PIN</strong> (inicio de sesión seguro). En iOS los permisos se solicitan de forma contextual y pueden revocarse desde Configuración.</p>

<h2>5. Derechos ARCO</h2>
<p>Los titulares pueden solicitar acceso, rectificación, cancelación u oposición enviando un correo a <a href="mailto:priegojorgeluis7@gmail.com">priegojorgeluis7@gmail.com</a> con asunto <em>"Ejercicio de derechos ARCO – SAO"</em>.</p>

<h2>6. Seguridad</h2>
<p>SAO usa HTTPS/TLS, autenticación por roles, tokens de sesión, registros de auditoría y almacenamiento controlado de evidencias.</p>

<h2>7. Cambios a esta política</h2>
<p>Esta política puede actualizarse ante cambios normativos o funcionales. La versión vigente se publicará en esta URL.</p>

<h2>8. Contacto</h2>
<p>Para dudas sobre privacidad: <a href="mailto:priegojorgeluis7@gmail.com">priegojorgeluis7@gmail.com</a></p>
</body>
</html>"""
    return HTMLResponse(content=html, status_code=200)


@app.get("/support", response_class=HTMLResponse, include_in_schema=False)
def support():
    """Página de soporte pública de SAO (sin autenticación)."""
    html = """<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Soporte – SAO</title>
<style>
  body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;max-width:760px;margin:40px auto;padding:0 20px;color:#1a1a1a;line-height:1.7}
  h1{font-size:1.8rem;margin-bottom:4px}
  h2{font-size:1.2rem;margin-top:2rem;border-bottom:1px solid #ddd;padding-bottom:4px}
  p,li{font-size:0.97rem}
  a{color:#0066cc}
  .meta{color:#555;font-size:0.9rem;margin-bottom:2rem}
  .card{background:#f5f5f7;border-radius:12px;padding:20px 24px;margin:16px 0}
</style>
</head>
<body>
<h1>Soporte SAO</h1>
<p class="meta">Sistema de Administración Operativa – SAO</p>

<div class="card">
  <strong>Contacto de soporte</strong><br>
  Correo: <a href="mailto:priegojorgeluis7@gmail.com">priegojorgeluis7@gmail.com</a><br>
  Teléfono: 55 3774 1179<br>
  Horario: Lunes a viernes, 9:00–18:00 (hora Ciudad de México)
</div>

<h2>Preguntas frecuentes</h2>

<p><strong>¿Cómo obtengo una cuenta?</strong><br>
Las cuentas son creadas por el administrador del sistema. Contacta a tu supervisor o al equipo de soporte para solicitar acceso.</p>

<p><strong>¿Olvidé mi contraseña. ¿Qué hago?</strong><br>
En la pantalla de inicio de sesión, selecciona <em>"¿Olvidaste tu contraseña?"</em> e ingresa tu correo registrado. Recibirás un enlace de restablecimiento.</p>

<p><strong>La aplicación no sincroniza mis actividades.</strong><br>
Verifica tu conexión a internet. Si el problema persiste, ve a Configuración → Sincronización → "Reintentar sincronización". Si el error continúa, escríbenos a <a href="mailto:priegojorgeluis7@gmail.com">priegojorgeluis7@gmail.com</a>.</p>

<p><strong>¿Cómo reporto un problema en la app?</strong><br>
Envía un correo a <a href="mailto:priegojorgeluis7@gmail.com">priegojorgeluis7@gmail.com</a> con una descripción del problema, capturas de pantalla si es posible, y el modelo de tu dispositivo.</p>

<h2>Política de privacidad</h2>
<p>Consulta nuestra <a href="/privacy-policy">Política de Privacidad</a>.</p>
</body>
</html>"""
    return HTMLResponse(content=html, status_code=200)


@app.get("/")
def root():
    return {"status": "ok"}


@app.get("/health")
def health_check():
    checks: dict[str, str] = {}

    try:
        check_firestore_connection()
        checks["firestore"] = "ok"
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Firestore connectivity check failed",
        ) from exc

    return {
        "status": "healthy",
        "data_backend": settings.DATA_BACKEND,
        "checks": checks,
    }


@app.get("/version")
def version_info():
    """Returns version and environment — used by clients for diagnostics."""
    return {
        "version": settings.VERSION,
        "env": settings.ENV,
        "api_prefix": settings.API_V1_STR,
    }
