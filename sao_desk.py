#!/usr/bin/env python3.11
"""SAO Developer Console — tkinter GUI."""
from __future__ import annotations

import json, os, subprocess, sys, threading, time
from datetime import datetime
from pathlib import Path
from typing import Any
from urllib import error as urllib_error, request as urllib_request
import tkinter as tk
from tkinter import ttk, scrolledtext, messagebox

# ── paths ──────────────────────────────────────────────────────────────────────
ROOT        = Path(__file__).resolve().parent
BACKEND_DIR = ROOT / "backend"
MOBILE_DIR  = ROOT / "frontend_flutter" / "sao_windows"
DESKTOP_DIR = ROOT / "desktop_flutter" / "sao_desktop"
PROD_URL    = "https://sao-api-97150883570.us-central1.run.app"
LOCAL_URL   = "http://localhost:8000"
FS_PROJECT  = "sao-prod-488416"
PYTHON      = sys.executable

# ── palette ───────────────────────────────────────────────────────────────────
BG       = "#0f1117"
SIDEBAR  = "#1a1d27"
CARD     = "#20232e"
ACCENT   = "#00b4d8"
GREEN    = "#2ecc71"
YELLOW   = "#f39c12"
RED      = "#e74c3c"
TEXT     = "#e8eaf0"
MUTED    = "#8892a4"
BORDER   = "#2d3244"
NAV_SEL  = "#1e3a42"
NAV_HOV  = "#1a2d35"

# ── HTTP helpers ──────────────────────────────────────────────────────────────
def _get(url: str, timeout: int = 8) -> tuple[int, Any]:
    req = urllib_request.Request(url, headers={"Accept": "application/json"})
    try:
        with urllib_request.urlopen(req, timeout=timeout) as r:
            return r.status, json.loads(r.read())
    except urllib_error.HTTPError as e:
        try: body = json.loads(e.read())
        except Exception: body = {}
        return e.code, body
    except Exception as exc:
        return 0, {"error": str(exc)}

def _firestore():
    sys.path.insert(0, str(BACKEND_DIR))
    os.environ.setdefault("FIRESTORE_PROJECT_ID", FS_PROJECT)
    os.environ.setdefault("DATA_BACKEND", "firestore")
    from google.cloud import firestore  # type: ignore
    return firestore.Client(project=FS_PROJECT)

# ── widget helpers ────────────────────────────────────────────────────────────
def _lbl(parent, text, color=TEXT, size=13, bold=False, anchor="w"):
    font = ("Helvetica", size, "bold" if bold else "normal")
    return tk.Label(parent, text=text, fg=color, bg=parent["bg"],
                    font=font, anchor=anchor)

def _btn(parent, text, cmd, color=ACCENT, fg="#000000", width=18):
    b = tk.Button(parent, text=text, command=cmd,
                  bg=color, fg=fg, activebackground=color,
                  relief="flat", padx=12, pady=6, cursor="hand2",
                  font=("Helvetica", 12), width=width)
    return b

def _outline_btn(parent, text, cmd, color=ACCENT, width=18):
    b = tk.Button(parent, text=text, command=cmd,
                  bg=CARD, fg=color, activebackground=BORDER,
                  relief="flat", padx=12, pady=6, cursor="hand2",
                  highlightthickness=1, highlightbackground=color,
                  font=("Helvetica", 12), width=width)
    return b

def _separator(parent):
    return tk.Frame(parent, bg=BORDER, height=1)

def _card_frame(parent):
    f = tk.Frame(parent, bg=CARD, padx=16, pady=12)
    return f

def _log_widget(parent, height=20):
    st = scrolledtext.ScrolledText(
        parent, bg=SIDEBAR, fg=TEXT, insertbackground=TEXT,
        font=("Courier New", 11), relief="flat", padx=8, pady=8,
        height=height, state="disabled",
    )
    return st

def _log_append(widget, text):
    widget.configure(state="normal")
    widget.insert("end", text)
    widget.see("end")
    widget.configure(state="disabled")

def _log_clear(widget):
    widget.configure(state="normal")
    widget.delete("1.0", "end")
    widget.configure(state="disabled")

def _status_dot(ok: bool | None) -> tuple[str, str]:
    """Returns (symbol, color)."""
    if ok is True:  return "● En línea", GREEN
    if ok is False: return "● Sin conexión", RED
    return "○ Verificando…", MUTED

# ─────────────────────────────────────────────────────────────────────────────
# PANELS
# ─────────────────────────────────────────────────────────────────────────────

class DashboardPanel:
    def __init__(self, parent: tk.Frame, after_fn):
        self.after = after_fn
        self.frame = tk.Frame(parent, bg=BG)
        self._build()

    def _build(self):
        f = self.frame
        # heading
        tk.Label(f, text="Dashboard del Sistema", fg=TEXT, bg=BG,
                 font=("Helvetica", 20, "bold"), anchor="w").pack(fill="x", pady=(0, 2))
        tk.Label(f, text=f"Proyecto: {FS_PROJECT}  ·  {datetime.now().strftime('%d/%m/%Y')}",
                 fg=MUTED, bg=BG, font=("Helvetica", 12), anchor="w").pack(fill="x", pady=(0, 10))
        _separator(f).pack(fill="x", pady=(0, 14))

        # status cards row
        cards_row = tk.Frame(f, bg=BG)
        cards_row.pack(fill="x", pady=(0, 14))

        # LOCAL card
        lc = _card_frame(cards_row)
        lc.pack(side="left", padx=(0, 10), fill="y")
        tk.Label(lc, text="Backend Local", fg=MUTED, bg=CARD,
                 font=("Helvetica", 11)).pack(anchor="w")
        self._local_lbl = tk.Label(lc, text="○ Verificando…", fg=MUTED, bg=CARD,
                                    font=("Helvetica", 13, "bold"))
        self._local_lbl.pack(anchor="w", pady=(4, 2))
        self._local_lat = tk.Label(lc, text="Latencia: —", fg=MUTED, bg=CARD,
                                    font=("Helvetica", 11))
        self._local_lat.pack(anchor="w")

        # PROD card
        pc = _card_frame(cards_row)
        pc.pack(side="left", padx=(0, 10), fill="y")
        tk.Label(pc, text="Backend Producción", fg=MUTED, bg=CARD,
                 font=("Helvetica", 11)).pack(anchor="w")
        self._prod_lbl = tk.Label(pc, text="○ Verificando…", fg=MUTED, bg=CARD,
                                   font=("Helvetica", 13, "bold"))
        self._prod_lbl.pack(anchor="w", pady=(4, 2))
        self._prod_ver = tk.Label(pc, text="Versión: —", fg=MUTED, bg=CARD,
                                   font=("Helvetica", 11))
        self._prod_ver.pack(anchor="w")
        self._prod_lat = tk.Label(pc, text="Latencia: —", fg=MUTED, bg=CARD,
                                   font=("Helvetica", 11))
        self._prod_lat.pack(anchor="w")

        # FIRESTORE card
        fc = _card_frame(cards_row)
        fc.pack(side="left", fill="y")
        tk.Label(fc, text="Firestore", fg=MUTED, bg=CARD,
                 font=("Helvetica", 11)).pack(anchor="w")
        self._fs_lbl = tk.Label(fc, text="○ Verificando…", fg=MUTED, bg=CARD,
                                 font=("Helvetica", 13, "bold"))
        self._fs_lbl.pack(anchor="w", pady=(4, 2))
        self._fs_lat = tk.Label(fc, text="Latencia: —", fg=MUTED, bg=CARD,
                                 font=("Helvetica", 11))
        self._fs_lat.pack(anchor="w")
        tk.Label(fc, text=FS_PROJECT, fg=MUTED, bg=CARD,
                 font=("Helvetica", 10)).pack(anchor="w")

        # refresh button
        self._spin_lbl = tk.Label(f, text="", fg=YELLOW, bg=BG, font=("Helvetica", 12))
        self._spin_lbl.pack(anchor="w", pady=(0, 4))
        _btn(f, "↺  Verificar ahora", self._run, width=22).pack(anchor="w", pady=(0, 14))

        _separator(f).pack(fill="x", pady=(0, 14))

        # log
        tk.Label(f, text="Log", fg=MUTED, bg=BG, font=("Helvetica", 11)).pack(anchor="w")
        self._log = _log_widget(f, height=8)
        self._log.pack(fill="both", expand=True)

    def show(self):
        self.frame.pack(fill="both", expand=True)
        self._run()

    def hide(self):
        self.frame.pack_forget()

    def _run(self):
        self._spin_lbl.config(text="Verificando…")
        threading.Thread(target=self._check, daemon=True).start()

    def _upd(self, fn):
        self.after(0, fn)

    def _check(self):
        _log_clear(self._log)

        t0 = time.monotonic()
        code, _ = _get(LOCAL_URL + "/health", timeout=4)
        ms = int((time.monotonic()-t0)*1000)
        ok = code == 200
        sym, col = _status_dot(ok)
        self._upd(lambda: self._local_lbl.config(text=sym, fg=col))
        self._upd(lambda: self._local_lat.config(text=f"Latencia: {ms} ms"))
        self._upd(lambda: _log_append(self._log, f"[{datetime.now().strftime('%H:%M:%S')}] Local  HTTP {code}  {ms} ms\n"))

        t0 = time.monotonic()
        code2, body2 = _get(PROD_URL + "/health", timeout=12)
        ms2 = int((time.monotonic()-t0)*1000)
        ok2 = code2 == 200
        sym2, col2 = _status_dot(ok2)
        ver = str(body2.get("version","—")) if ok2 else "—"
        self._upd(lambda: self._prod_lbl.config(text=sym2, fg=col2))
        self._upd(lambda: self._prod_ver.config(text=f"Versión: {ver}"))
        self._upd(lambda: self._prod_lat.config(text=f"Latencia: {ms2} ms"))
        self._upd(lambda: _log_append(self._log, f"[{datetime.now().strftime('%H:%M:%S')}] Prod   HTTP {code2}  {ms2} ms  v{ver}\n"))

        try:
            db = _firestore()
            t0 = time.monotonic()
            list(db.collections())
            ms3 = int((time.monotonic()-t0)*1000)
            sym3, col3 = _status_dot(True)
            self._upd(lambda: self._fs_lbl.config(text=sym3, fg=col3))
            self._upd(lambda: self._fs_lat.config(text=f"Latencia: {ms3} ms"))
            self._upd(lambda: _log_append(self._log, f"[{datetime.now().strftime('%H:%M:%S')}] Firestore OK  {ms3} ms\n"))
        except Exception as exc:
            sym3, col3 = _status_dot(False)
            self._upd(lambda: self._fs_lbl.config(text=sym3, fg=col3))
            self._upd(lambda: _log_append(self._log, f"[{datetime.now().strftime('%H:%M:%S')}] Firestore ERROR: {exc}\n"))

        self._upd(lambda: self._spin_lbl.config(text=""))


# ─────────────────────────────────────────────────────────────────────────────

class FirestorePanel:
    def __init__(self, parent: tk.Frame, after_fn):
        self.after = after_fn
        self.frame = tk.Frame(parent, bg=BG)
        self._db = None
        self._build()

    def _db_(self):
        if not self._db:
            self._db = _firestore()
        return self._db

    def _build(self):
        f = self.frame
        tk.Label(f, text="Firestore Explorer", fg=TEXT, bg=BG,
                 font=("Helvetica", 20, "bold"), anchor="w").pack(fill="x", pady=(0, 2))
        tk.Label(f, text="Consultas directas a la base de datos de producción",
                 fg=MUTED, bg=BG, font=("Helvetica", 12), anchor="w").pack(fill="x", pady=(0, 10))
        _separator(f).pack(fill="x", pady=(0, 12))

        btn_row = tk.Frame(f, bg=BG)
        btn_row.pack(fill="x", pady=(0, 12))

        self._spin = tk.Label(btn_row, text="", fg=YELLOW, bg=BG, font=("Helvetica", 12))
        self._spin.pack(side="right")

        _btn(btn_row, "Proyectos", lambda: self._load("projects"), width=14).pack(side="left", padx=(0,6))
        _outline_btn(btn_row, "Actividades", self._pick_project, width=14).pack(side="left", padx=(0,6))
        _outline_btn(btn_row, "Usuarios", lambda: self._load("users"), width=14).pack(side="left", padx=(0,6))
        _outline_btn(btn_row, "Completadas sin rev.", lambda: self._load("stuck"),
                     color=YELLOW, width=20).pack(side="left", padx=(0,6))
        _outline_btn(btn_row, "Catálogos", lambda: self._load("catalogs"), width=12).pack(side="left")

        _separator(f).pack(fill="x", pady=(0, 10))

        self._output = _log_widget(f, height=30)
        self._output.pack(fill="both", expand=True)

    def show(self): self.frame.pack(fill="both", expand=True)
    def hide(self): self.frame.pack_forget()

    def _log(self, text):
        self.after(0, lambda: _log_append(self._output, text))

    def _clear(self):
        self.after(0, lambda: _log_clear(self._output))

    def _busy(self, v: bool):
        self.after(0, lambda: self._spin.config(text="Cargando…" if v else ""))

    def _load(self, section: str, arg: str = ""):
        self._clear()
        self._busy(True)
        threading.Thread(target=self._fetch, args=(section, arg), daemon=True).start()

    def _pick_project(self):
        self._busy(True)
        def _work():
            try:
                pids = sorted(
                    (d.to_dict() or {}).get("project_id","")
                    for d in self._db_().collection("projects").stream()
                    if (d.to_dict() or {}).get("project_id")
                )
            except Exception as exc:
                self._log(f"Error: {exc}\n")
                self._busy(False)
                return
            self._busy(False)

            def _show_dialog():
                dlg = tk.Toplevel()
                dlg.title("Selecciona proyecto")
                dlg.configure(bg=CARD)
                dlg.geometry("300x350")
                tk.Label(dlg, text="Proyecto", fg=TEXT, bg=CARD,
                         font=("Helvetica", 13, "bold")).pack(pady=(12,6))
                lb = tk.Listbox(dlg, bg=SIDEBAR, fg=TEXT, selectbackground=ACCENT,
                                font=("Helvetica", 12), relief="flat", height=14)
                lb.pack(fill="both", expand=True, padx=12)
                for p in pids:
                    lb.insert("end", p)
                def _select():
                    sel = lb.curselection()
                    if sel:
                        pid = pids[sel[0]]
                        dlg.destroy()
                        self._load("activities", pid)
                tk.Button(dlg, text="Seleccionar", command=_select,
                          bg=ACCENT, fg="#000", font=("Helvetica", 12),
                          relief="flat", padx=12, pady=6).pack(pady=10)
            self.after(0, _show_dialog)
        threading.Thread(target=_work, daemon=True).start()

    def _fetch(self, section: str, arg: str):
        try:
            db = self._db_()
            if section == "projects":     self._projects(db)
            elif section == "activities": self._activities(db, arg)
            elif section == "users":      self._users(db)
            elif section == "stuck":      self._stuck(db)
            elif section == "catalogs":   self._catalogs(db)
        except Exception as exc:
            self._log(f"ERROR: {exc}\n")
        finally:
            self._busy(False)

    def _projects(self, db):
        docs = sorted([d.to_dict() or {} for d in db.collection("projects").stream()],
                      key=lambda x: str(x.get("project_id","")))
        self._log(f"{'ID':<20} {'Nombre':<40} Activo\n")
        self._log("-" * 65 + "\n")
        for p in docs:
            pid = str(p.get("project_id","—"))[:20]
            name = str(p.get("name", p.get("project_name","—")))[:40]
            active = "✅" if p.get("is_active", True) else "❌"
            self._log(f"{pid:<20} {name:<40} {active}\n")
        self._log(f"\nTotal: {len(docs)} proyectos\n")

    def _activities(self, db, pid: str):
        from collections import Counter
        docs = list(db.collection("activities").where("project_id","==",pid).stream())
        active = [d.to_dict() or {} for d in docs if not (d.to_dict() or {}).get("deleted_at")]
        states = Counter(str(a.get("execution_state","—")).upper() for a in active)
        self._log(f"Actividades — {pid}\n")
        self._log(f"Total: {len(docs)}  Activas: {len(active)}\n\n")
        for st, cnt in sorted(states.items(), key=lambda x: -x[1]):
            bar = "█" * min(cnt, 40)
            self._log(f"  {st:<28} {cnt:>4}  {bar}\n")

    def _users(self, db):
        docs = sorted([d.to_dict() or {} for d in db.collection("users").stream()],
                      key=lambda x: str(x.get("email","")))
        self._log(f"{'Email':<40} {'Rol':<20} Activo\n")
        self._log("-" * 70 + "\n")
        for u in docs:
            email = str(u.get("email","—"))[:40]
            role  = str(u.get("role","—"))[:20]
            active = "✅" if u.get("is_active", True) else "❌"
            self._log(f"{email:<40} {role:<20} {active}\n")
        self._log(f"\nTotal: {len(docs)} usuarios\n")

    def _stuck(self, db):
        results = []
        for snap in db.collection("activities").where("execution_state","==","COMPLETADA").stream():
            doc = snap.to_dict() or {}
            if doc.get("deleted_at"): continue
            if not str(doc.get("review_decision") or "").strip():
                doc["_id"] = snap.id; results.append(doc)
        if not results:
            self._log("✅ Sin actividades COMPLETADA sin review_decision\n")
            return
        self._log(f"⚠️  {len(results)} actividades COMPLETADA sin review_decision:\n\n")
        for d in results[:60]:
            self._log(f"  {d['_id'][:28]}  proyecto={d.get('project_id','—')}  tipo={d.get('activity_type_code','—')}\n")
            self._log(f"    front_id={d.get('front_id','—')}  user={d.get('created_by_user_id','—')}\n\n")

    def _catalogs(self, db):
        docs = [d.to_dict() or {} for d in db.collection("catalog_bundles").stream()]
        if not docs:
            docs = [d.to_dict() or {} for d in db.collection("catalogs").stream()]
        self._log(f"{'ID':<36} {'Versión':<12} {'Activo':<8} Proyecto\n")
        self._log("-" * 70 + "\n")
        for c in docs:
            cid     = str(c.get("id", c.get("catalog_id","—")))[:36]
            ver     = str(c.get("version","—"))[:12]
            active  = "✅" if c.get("is_active", True) else "❌"
            proj    = str(c.get("project_id","todos"))
            self._log(f"{cid:<36} {ver:<12} {active:<8} {proj}\n")
        self._log(f"\nTotal: {len(docs)} catálogos\n")


# ─────────────────────────────────────────────────────────────────────────────

class BackendPanel:
    def __init__(self, parent: tk.Frame, after_fn):
        self.after = after_fn
        self.frame = tk.Frame(parent, bg=BG)
        self._proc = None
        self._build()

    def _build(self):
        f = self.frame
        tk.Label(f, text="Backend Local", fg=TEXT, bg=BG,
                 font=("Helvetica", 20, "bold"), anchor="w").pack(fill="x", pady=(0, 2))
        tk.Label(f, text="Gestión del servidor FastAPI en localhost:8000",
                 fg=MUTED, bg=BG, font=("Helvetica", 12), anchor="w").pack(fill="x", pady=(0, 10))
        _separator(f).pack(fill="x", pady=(0, 12))

        ctrl = tk.Frame(f, bg=BG)
        ctrl.pack(fill="x", pady=(0, 12))

        self._status_lbl = tk.Label(ctrl, text="● Detenido", fg=RED, bg=BG,
                                     font=("Helvetica", 13, "bold"))
        self._status_lbl.pack(side="left", padx=(0, 16))

        self._start_btn = _btn(ctrl, "▶  Iniciar", self._start, width=14)
        self._start_btn.pack(side="left", padx=(0, 6))

        self._stop_btn = _outline_btn(ctrl, "■  Detener", self._stop, color=RED, width=14)
        self._stop_btn.config(state="disabled")
        self._stop_btn.pack(side="left", padx=(0, 16))

        _outline_btn(ctrl, "Tests", self._run_tests, width=10).pack(side="left", padx=(0, 6))
        _outline_btn(ctrl, "E2E",   self._run_e2e,   width=8).pack(side="left", padx=(0, 6))
        _outline_btn(ctrl, "pip install", self._install_deps, width=14).pack(side="left")

        _separator(f).pack(fill="x", pady=(0, 10))
        tk.Label(f, text="Consola", fg=MUTED, bg=BG, font=("Helvetica", 11)).pack(anchor="w")
        self._log = _log_widget(f, height=30)
        self._log.pack(fill="both", expand=True)

    def show(self): self.frame.pack(fill="both", expand=True)
    def hide(self): self.frame.pack_forget()

    def _append(self, text):
        self.after(0, lambda: _log_append(self._log, text))

    def _start(self):
        if self._proc and self._proc.poll() is None:
            self._append("⚠️  Ya está corriendo.\n"); return
        self._append(f"\n[{datetime.now().strftime('%H:%M:%S')}] Iniciando uvicorn…\n")
        env = {**os.environ, "FIRESTORE_PROJECT_ID": FS_PROJECT,
               "DATA_BACKEND": "firestore",
               "EVIDENCE_STORAGE_BACKEND": "local",
               "JWT_SECRET": os.environ.get("JWT_SECRET", "dev-secret")}
        self._proc = subprocess.Popen(
            [PYTHON, "-m", "uvicorn", "app.main:app", "--reload",
             "--host", "0.0.0.0", "--port", "8000"],
            cwd=BACKEND_DIR, env=env,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
        )
        self.after(0, lambda: (
            self._status_lbl.config(text="● Corriendo :8000", fg=GREEN),
            self._start_btn.config(state="disabled"),
            self._stop_btn.config(state="normal"),
        ))
        threading.Thread(target=self._stream, daemon=True).start()

    def _stream(self):
        if not self._proc: return
        for line in iter(self._proc.stdout.readline, ""):  # type: ignore
            self._append(line)
        self._proc.wait()
        self._append(f"\n[{datetime.now().strftime('%H:%M:%S')}] Detenido.\n")
        self.after(0, lambda: (
            self._status_lbl.config(text="● Detenido", fg=RED),
            self._start_btn.config(state="normal"),
            self._stop_btn.config(state="disabled"),
        ))

    def _stop(self):
        if self._proc:
            self._proc.terminate()

    def _run_cmd(self, cmd: list[str]):
        _log_clear(self._log)
        self._append(f"$ {' '.join(cmd)}\n\n")
        env = {**os.environ, "FIRESTORE_PROJECT_ID": FS_PROJECT, "DATA_BACKEND": "firestore"}
        def _w():
            try:
                p = subprocess.Popen(cmd, cwd=BACKEND_DIR, env=env,
                                     stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
                for line in iter(p.stdout.readline, ""):  # type: ignore
                    self._append(line)
                p.wait()
                self._append(f"\n─── Exit {p.returncode} {'✅' if p.returncode==0 else '❌'} ───\n")
            except Exception as exc:
                self._append(f"\nError: {exc}\n")
        threading.Thread(target=_w, daemon=True).start()

    def _run_tests(self): self._run_cmd([PYTHON, "-m", "pytest", "tests", "-v", "--tb=short", "-q"])
    def _run_e2e(self): self._run_cmd([PYTHON, str(BACKEND_DIR / "scripts" / "e2e_local.py")])
    def _install_deps(self): self._run_cmd([PYTHON, "-m", "pip", "install", "-r", "requirements.txt"])


# ─────────────────────────────────────────────────────────────────────────────

class DiagnosticsPanel:
    def __init__(self, parent: tk.Frame, after_fn):
        self.after = after_fn
        self.frame = tk.Frame(parent, bg=BG)
        self._build()

    def _build(self):
        f = self.frame
        tk.Label(f, text="Diagnósticos", fg=TEXT, bg=BG,
                 font=("Helvetica", 20, "bold"), anchor="w").pack(fill="x", pady=(0, 2))
        tk.Label(f, text="Análisis y detección de problemas del sistema",
                 fg=MUTED, bg=BG, font=("Helvetica", 12), anchor="w").pack(fill="x", pady=(0, 10))
        _separator(f).pack(fill="x", pady=(0, 12))

        btn_row = tk.Frame(f, bg=BG)
        btn_row.pack(fill="x", pady=(0, 12))
        self._spin = tk.Label(btn_row, text="", fg=YELLOW, bg=BG, font=("Helvetica", 12))
        self._spin.pack(side="right")

        _btn(btn_row, "Smoke Test Prod", self._smoke, width=18).pack(side="left", padx=(0,6))
        _outline_btn(btn_row, "Sync Issues", self._sync_issues, color=YELLOW, width=14).pack(side="left", padx=(0,6))
        _outline_btn(btn_row, "Sin group_id", self._check_gids, width=14).pack(side="left", padx=(0,6))
        _outline_btn(btn_row, "Catálogos", self._cats, width=12).pack(side="left")

        _separator(f).pack(fill="x", pady=(0, 10))
        self._log = _log_widget(f, height=30)
        self._log.pack(fill="both", expand=True)

    def show(self): self.frame.pack(fill="both", expand=True)
    def hide(self): self.frame.pack_forget()

    def _w(self, text): self.after(0, lambda: _log_append(self._log, text))
    def _busy(self, v): self.after(0, lambda: self._spin.config(text="Cargando…" if v else ""))

    def _smoke(self):
        _log_clear(self._log); self._busy(True)
        def _run():
            t0 = time.monotonic()
            code, body = _get(PROD_URL + "/health", timeout=12)
            ms = int((time.monotonic()-t0)*1000)
            ok = code == 200
            sym = "✅" if ok else "❌"
            self._w(f"{sym} HTTP {code}  {ms} ms\n")
            if ok:
                self._w(f"Versión: {body.get('version','—')}\n")
            self._busy(False)
        threading.Thread(target=_run, daemon=True).start()

    def _sync_issues(self):
        _log_clear(self._log); self._busy(True)
        def _run():
            try:
                from collections import Counter
                db = _firestore()
                docs = list(db.collection("activities").stream())
                states: Counter = Counter()
                issues: list[str] = []
                for snap in docs:
                    doc = snap.to_dict() or {}
                    if doc.get("deleted_at"): continue
                    states[str(doc.get("execution_state","—")).upper()] += 1
                    ss = str(doc.get("sync_status") or "").upper()
                    if ss in ("ERROR","CONFLICT","PENDING"):
                        issues.append(f"[{ss}] {snap.id[:24]}  {doc.get('project_id')}")
                self._w("Distribución de estados:\n")
                for s, c in sorted(states.items(), key=lambda x: -x[1]):
                    self._w(f"  {s:<28} {c}\n")
                if issues:
                    self._w(f"\n⚠️  Sync issues ({len(issues)}):\n")
                    for i in issues[:20]: self._w(f"  {i}\n")
                else:
                    self._w("\n✅ Sin sync issues detectados.\n")
            except Exception as exc:
                self._w(f"ERROR: {exc}\n")
            finally:
                self._busy(False)
        threading.Thread(target=_run, daemon=True).start()

    def _check_gids(self):
        _log_clear(self._log); self._busy(True)
        def _run():
            try:
                db = _firestore()
                docs = list(db.collection("activities").stream())
                sin = [d for d in docs
                       if not (d.to_dict() or {}).get("activity_group_id")
                       and not (d.to_dict() or {}).get("deleted_at")]
                self._w(f"Total actividades: {len(docs)}\n")
                self._w(f"Sin activity_group_id: {len(sin)}\n")
                if not sin: self._w("✅ Todas tienen group_id\n")
                else: self._w(f"⚠️  {len(sin)} sin group_id\n")
            except Exception as exc:
                self._w(f"ERROR: {exc}\n")
            finally:
                self._busy(False)
        threading.Thread(target=_run, daemon=True).start()

    def _cats(self):
        _log_clear(self._log); self._busy(True)
        def _run():
            try:
                db = _firestore()
                cats = list(db.collection("catalog_bundles").stream())
                active = [c for c in cats if (c.to_dict() or {}).get("is_active")]
                self._w(f"Total bundles: {len(cats)}\n")
                self._w(f"Activos: {len(active)}\n")
                if active: self._w("✅ Catálogos OK\n")
                else: self._w("⚠️  Sin catálogos activos\n")
            except Exception as exc:
                self._w(f"ERROR: {exc}\n")
            finally:
                self._busy(False)
        threading.Thread(target=_run, daemon=True).start()


# ─────────────────────────────────────────────────────────────────────────────

class FlutterPanel:
    def __init__(self, parent: tk.Frame, after_fn):
        self.after = after_fn
        self.frame = tk.Frame(parent, bg=BG)
        import shutil
        self._flutter = shutil.which("flutter") or "flutter"
        self._dart    = shutil.which("dart") or "dart"
        self._build()

    def _build(self):
        f = self.frame
        tk.Label(f, text="Flutter Apps", fg=TEXT, bg=BG,
                 font=("Helvetica", 20, "bold"), anchor="w").pack(fill="x", pady=(0, 2))
        tk.Label(f, text="Build, analyze y run para mobile y desktop",
                 fg=MUTED, bg=BG, font=("Helvetica", 12), anchor="w").pack(fill="x", pady=(0, 10))
        _separator(f).pack(fill="x", pady=(0, 12))

        # Mobile section
        mc = _card_frame(f)
        mc.pack(fill="x", pady=(0, 10))
        tk.Label(mc, text="📱  Mobile — sao_windows", fg=ACCENT, bg=CARD,
                 font=("Helvetica", 13, "bold")).pack(anchor="w", pady=(0, 8))
        mb_row = tk.Frame(mc, bg=CARD)
        mb_row.pack(anchor="w")
        for lbl, cmd in [
            ("analyze",       [self._flutter, "analyze"]),
            ("test",          [self._flutter, "test"]),
            ("pub get",       [self._flutter, "pub", "get"]),
            ("build_runner",  [self._dart, "run", "build_runner", "build", "--delete-conflicting-outputs"]),
        ]:
            _outline_btn(mb_row, lbl, lambda c=cmd: self._run(c, MOBILE_DIR), width=14).pack(side="left", padx=(0, 6))

        # Desktop section
        dc = _card_frame(f)
        dc.pack(fill="x", pady=(0, 10))
        tk.Label(dc, text="🖥  Desktop — sao_desktop", fg=ACCENT, bg=CARD,
                 font=("Helvetica", 13, "bold")).pack(anchor="w", pady=(0, 8))
        db_row = tk.Frame(dc, bg=CARD)
        db_row.pack(anchor="w")
        for lbl, cmd in [
            ("analyze",       [self._flutter, "analyze"]),
            ("test",          [self._flutter, "test"]),
            ("pub get",       [self._flutter, "pub", "get"]),
            ("build_runner",  [self._dart, "run", "build_runner", "build", "--delete-conflicting-outputs"]),
            ("run (prod)",    [self._flutter, "run", "-d", "macos", f"--dart-define=SAO_BACKEND_URL={PROD_URL}"]),
        ]:
            _outline_btn(db_row, lbl, lambda c=cmd: self._run(c, DESKTOP_DIR), width=14).pack(side="left", padx=(0, 6))

        _separator(f).pack(fill="x", pady=(0, 10))
        tk.Label(f, text="Salida", fg=MUTED, bg=BG, font=("Helvetica", 11)).pack(anchor="w")
        self._log = _log_widget(f, height=20)
        self._log.pack(fill="both", expand=True)

    def show(self): self.frame.pack(fill="both", expand=True)
    def hide(self): self.frame.pack_forget()

    def _run(self, cmd: list[str], cwd: Path):
        _log_clear(self._log)
        _log_append(self._log, f"$ cd {cwd.name} && {' '.join(cmd)}\n\n")
        def _w():
            try:
                p = subprocess.Popen(cmd, cwd=cwd,
                                     stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
                for line in iter(p.stdout.readline, ""):  # type: ignore
                    self.after(0, lambda l=line: _log_append(self._log, l))
                p.wait()
                self.after(0, lambda: _log_append(
                    self._log, f"\n─── Exit {p.returncode} {'✅' if p.returncode==0 else '❌'} ───\n"))
            except Exception as exc:
                self.after(0, lambda: _log_append(self._log, f"\nError: {exc}\n"))
        threading.Thread(target=_w, daemon=True).start()


# ─────────────────────────────────────────────────────────────────────────────

class OperativosPanel:
    """Resuelve problemas de sync y pérdida de datos en actividades."""

    def __init__(self, parent: tk.Frame, after_fn):
        self.after = after_fn
        self.frame = tk.Frame(parent, bg=BG)
        self._db = None
        self._project_var = tk.StringVar(value="(todos)")
        self._projects: list[str] = []
        self._proj_menu: tk.OptionMenu | None = None
        self._build()

    def _db_(self):
        if not self._db:
            self._db = _firestore()
        return self._db

    def _build(self):
        f = self.frame
        tk.Label(f, text="Operativos — Sync & Recuperación", fg=TEXT, bg=BG,
                 font=("Helvetica", 20, "bold"), anchor="w").pack(fill="x", pady=(0, 2))
        tk.Label(f, text="Detecta y resuelve problemas de sincronización y pérdida de datos de operativos",
                 fg=MUTED, bg=BG, font=("Helvetica", 12), anchor="w").pack(fill="x", pady=(0, 10))
        _separator(f).pack(fill="x", pady=(0, 12))

        # ── project selector ──────────────────────────────────────────────────
        sel_row = tk.Frame(f, bg=BG)
        sel_row.pack(fill="x", pady=(0, 10))
        tk.Label(sel_row, text="Proyecto:", fg=MUTED, bg=BG,
                 font=("Helvetica", 12)).pack(side="left", padx=(0, 8))
        self._proj_menu = tk.OptionMenu(sel_row, self._project_var, "(todos)")
        self._proj_menu.config(bg=CARD, fg=TEXT, activebackground=BORDER,
                               font=("Helvetica", 12), relief="flat", padx=8, pady=4)
        self._proj_menu["menu"].config(bg=CARD, fg=TEXT, activebackground=ACCENT)
        self._proj_menu.pack(side="left", padx=(0, 12))
        _outline_btn(sel_row, "↺ Cargar proyectos", self._load_projects, width=18).pack(side="left")
        self._spin = tk.Label(sel_row, text="", fg=YELLOW, bg=BG, font=("Helvetica", 12))
        self._spin.pack(side="right")

        # ── action buttons row 1 ──────────────────────────────────────────────
        r1 = tk.Frame(f, bg=BG)
        r1.pack(fill="x", pady=(6, 4))
        _btn(r1, "🔍  Auditoría Completa", self._full_audit, width=22).pack(side="left", padx=(0, 6))
        _outline_btn(r1, "🔄  Escanear Sync", self._scan_sync, color=ACCENT, width=18).pack(side="left", padx=(0, 6))
        _outline_btn(r1, "⏳  Pendientes Sync", self._pending_sync, color=YELLOW, width=18).pack(side="left")

        # ── action buttons row 2 ──────────────────────────────────────────────
        r2 = tk.Frame(f, bg=BG)
        r2.pack(fill="x", pady=(0, 12))
        _outline_btn(r2, "⚠  Fix COMPLETADA", self._fix_completada, color=YELLOW, width=18).pack(side="left", padx=(0, 6))
        _btn(r2, "🔧  Limpiar Errores Sync", self._clear_sync_errors, color=RED, fg=TEXT, width=22).pack(side="left", padx=(0, 6))
        _outline_btn(r2, "💾  Recuperar Borradas", self._recover_deleted, color=ACCENT, width=20).pack(side="left", padx=(0, 6))
        _outline_btn(r2, "↩  Undelete por ID", self._undelete_by_id, width=18).pack(side="left")

        _separator(f).pack(fill="x", pady=(0, 10))
        tk.Label(f, text="Resultados", fg=MUTED, bg=BG, font=("Helvetica", 11)).pack(anchor="w")
        self._log = _log_widget(f, height=24)
        self._log.pack(fill="both", expand=True)

    def show(self):
        self.frame.pack(fill="both", expand=True)
        if not self._projects:
            self._load_projects()

    def hide(self): self.frame.pack_forget()

    def _w(self, text): self.after(0, lambda: _log_append(self._log, text))
    def _clear(self): self.after(0, lambda: _log_clear(self._log))
    def _busy(self, v): self.after(0, lambda: self._spin.config(text="Procesando…" if v else ""))

    def _project_filter(self) -> str | None:
        v = self._project_var.get()
        return None if v == "(todos)" else v

    def _load_projects(self):
        self._busy(True)
        def _work():
            try:
                db = self._db_()
                pids = sorted(
                    (d.to_dict() or {}).get("project_id", "")
                    for d in db.collection("projects").stream()
                    if (d.to_dict() or {}).get("project_id")
                )
                self._projects = pids
                def _upd():
                    menu = self._proj_menu["menu"]  # type: ignore
                    menu.delete(0, "end")
                    menu.add_command(label="(todos)", command=lambda: self._project_var.set("(todos)"))
                    for p in pids:
                        menu.add_command(label=p, command=lambda v=p: self._project_var.set(v))
                    self._busy(False)
                self.after(0, _upd)
            except Exception as exc:
                self._w(f"Error cargando proyectos: {exc}\n")
                self._busy(False)
        threading.Thread(target=_work, daemon=True).start()

    def _get_active(self, db, project: str | None) -> list[dict]:
        q = db.collection("activities").where("project_id", "==", project) if project \
            else db.collection("activities")
        result = []
        for snap in q.stream():
            doc = snap.to_dict() or {}
            if doc.get("deleted_at"):
                continue
            doc["_id"] = snap.id
            result.append(doc)
        return result

    # ── AUDITORÍA COMPLETA ────────────────────────────────────────────────────
    def _full_audit(self):
        self._clear(); self._busy(True)
        proj = self._project_filter()
        def _run():
            try:
                from collections import Counter
                db = self._db_()
                q = db.collection("activities").where("project_id", "==", proj) if proj \
                    else db.collection("activities")
                all_docs = []
                for snap in q.stream():
                    doc = snap.to_dict() or {}
                    doc["_id"] = snap.id
                    all_docs.append(doc)

                active  = [d for d in all_docs if not d.get("deleted_at")]
                deleted = [d for d in all_docs if d.get("deleted_at")]

                exec_st  = Counter(str(d.get("execution_state", "—")).upper() for d in active)
                sync_st  = Counter(str(d.get("sync_status") or "OK").upper() for d in active)
                review_d = Counter(str(d.get("review_decision") or "—") for d in active)
                by_proj  = Counter(str(d.get("project_id", "—")) for d in active)

                self._w(f"{'='*55}\n")
                self._w(f"AUDITORÍA COMPLETA — {'PROYECTO: '+proj if proj else 'TODOS LOS PROYECTOS'}\n")
                self._w(f"Fecha: {datetime.now().strftime('%d/%m/%Y %H:%M:%S')}\n")
                self._w(f"{'='*55}\n\n")

                self._w(f"TOTALES:\n")
                self._w(f"  Total documentos:   {len(all_docs)}\n")
                self._w(f"  Activos:            {len(active)}\n")
                self._w(f"  Borrados (soft):    {len(deleted)}\n\n")

                self._w("ESTADOS DE EJECUCIÓN:\n")
                for st, cnt in sorted(exec_st.items(), key=lambda x: -x[1]):
                    bar = "█" * min(int(cnt / max(len(active), 1) * 30), 30)
                    self._w(f"  {st:<30} {cnt:>5}  {bar}\n")

                self._w("\nESTADOS DE SYNC:\n")
                for ss, cnt in sorted(sync_st.items(), key=lambda x: -x[1]):
                    icon = "✅" if ss in ("OK", "SYNCED", "") else ("⚠️ " if ss == "PENDING" else "❌")
                    self._w(f"  {icon} {ss:<26} {cnt:>5}\n")

                self._w("\nREVIEW DECISIONS:\n")
                for rv, cnt in sorted(review_d.items(), key=lambda x: -x[1]):
                    self._w(f"  {rv:<30} {cnt:>5}\n")

                if not proj:
                    self._w("\nPOR PROYECTO (top 20):\n")
                    for pid, cnt in by_proj.most_common(20):
                        self._w(f"  {pid:<28} {cnt:>5}\n")

                # issues summary
                sync_errs  = [d for d in active if str(d.get("sync_status") or "").upper() in ("ERROR", "CONFLICT", "FAILED")]
                stuck_comp = [d for d in active if str(d.get("execution_state") or "").upper() == "COMPLETADA"
                              and not str(d.get("review_decision") or "").strip()]
                pending_sync = [d for d in active if str(d.get("sync_status") or "").upper() in ("PENDING", "QUEUED")]
                no_gid     = [d for d in active if not str(d.get("activity_group_id") or "").strip()]

                self._w(f"\n{'='*55}\n")
                issues_found = False
                if sync_errs:
                    self._w(f"❌ {len(sync_errs)} actividades con sync_status=ERROR/CONFLICT/FAILED\n")
                    issues_found = True
                if stuck_comp:
                    self._w(f"⚠️  {len(stuck_comp)} COMPLETADA sin review_decision\n")
                    issues_found = True
                if pending_sync:
                    self._w(f"⏳ {len(pending_sync)} actividades pendientes de sync\n")
                    issues_found = True
                if deleted:
                    self._w(f"🗑  {len(deleted)} actividades borradas (recuperables)\n")
                    issues_found = True
                if len(no_gid) > 5:
                    self._w(f"ℹ  {len(no_gid)} sin activity_group_id\n")
                    issues_found = True
                if not issues_found:
                    self._w("✅ Sin problemas detectados.\n")
                else:
                    self._w("\n→ Usa los botones de acción para resolver cada problema.\n")
                self._w(f"{'='*55}\n")
            except Exception as exc:
                self._w(f"ERROR: {exc}\n")
            finally:
                self._busy(False)
        threading.Thread(target=_run, daemon=True).start()

    # ── ESCANEAR SYNC ─────────────────────────────────────────────────────────
    def _scan_sync(self):
        self._clear(); self._busy(True)
        proj = self._project_filter()
        def _run():
            try:
                from collections import Counter, defaultdict
                db = self._db_()
                docs = self._get_active(db, proj)

                sync_states: Counter = Counter()
                by_project: dict = defaultdict(lambda: defaultdict(list))
                for doc in docs:
                    ss = str(doc.get("sync_status") or "OK").upper()
                    sync_states[ss] += 1
                    if ss in ("ERROR", "CONFLICT", "PENDING", "FAILED", "QUEUED"):
                        by_project[doc.get("project_id", "—")][ss].append(doc)

                self._w(f"=== ESCANEO SYNC — {'PROYECTO: '+proj if proj else 'TODOS'} ===\n\n")
                self._w(f"Total actividades: {len(docs)}\n\n")
                self._w("Estado de sync:\n")
                for ss, cnt in sorted(sync_states.items(), key=lambda x: -x[1]):
                    icon = "✅" if ss in ("OK", "SYNCED", "") else ("⚠️ " if ss in ("PENDING","QUEUED") else "❌")
                    self._w(f"  {icon}  {ss:<24}  {cnt}\n")

                if not by_project:
                    self._w("\n✅ Sin problemas de sync detectados.\n")
                else:
                    self._w(f"\n⚠️  Proyectos con sync issues:\n")
                    for pid, states in sorted(by_project.items()):
                        total = sum(len(v) for v in states.values())
                        self._w(f"\n  📁 {pid}  ({total} issues)\n")
                        for ss, ddocs in states.items():
                            self._w(f"    [{ss}]  {len(ddocs)} actividades\n")
                            for d in ddocs[:5]:
                                self._w(f"      • {d['_id'][:28]}\n")
                                self._w(f"        front_id={d.get('front_id','—')}  user={d.get('created_by_user_id','—')}\n")
                                self._w(f"        estado={d.get('execution_state','—')}  error={str(d.get('sync_error','—'))[:60]}\n")
                            if len(ddocs) > 5:
                                self._w(f"      … y {len(ddocs)-5} más\n")
                    self._w("\n→ Usa 'Limpiar Errores Sync' para resetear los errores y permitir reintento.\n")
            except Exception as exc:
                self._w(f"ERROR: {exc}\n")
            finally:
                self._busy(False)
        threading.Thread(target=_run, daemon=True).start()

    # ── PENDIENTES SYNC ───────────────────────────────────────────────────────
    def _pending_sync(self):
        self._clear(); self._busy(True)
        proj = self._project_filter()
        def _run():
            try:
                db = self._db_()
                docs = self._get_active(db, proj)
                pending = [d for d in docs if str(d.get("sync_status") or "").upper() in ("PENDING", "QUEUED", "WAITING")]

                self._w(f"=== PENDIENTES DE SYNC — {'PROYECTO: '+proj if proj else 'TODOS'} ===\n\n")
                self._w(f"Total pendientes: {len(pending)}\n\n")

                if not pending:
                    self._w("✅ Sin actividades pendientes de sync.\n")
                    self._busy(False)
                    return

                # group by project
                from collections import defaultdict
                by_proj: dict = defaultdict(list)
                for d in pending:
                    by_proj[d.get("project_id", "—")].append(d)

                for pid, group in sorted(by_proj.items()):
                    self._w(f"📁 {pid}  ({len(group)} pendientes)\n")
                    for d in group[:10]:
                        self._w(f"  • {d['_id'][:28]}\n")
                        self._w(f"    front_id={d.get('front_id','—')}  estado={d.get('execution_state','—')}\n")
                        self._w(f"    sync_status={d.get('sync_status')}  user={d.get('created_by_user_id','—')}\n")
                        upd = d.get("updated_at") or d.get("created_at")
                        if upd:
                            self._w(f"    última actualización: {upd}\n")
                        self._w("\n")
                    if len(group) > 10:
                        self._w(f"  … y {len(group)-10} más\n\n")
            except Exception as exc:
                self._w(f"ERROR: {exc}\n")
            finally:
                self._busy(False)
        threading.Thread(target=_run, daemon=True).start()

    # ── FIX COMPLETADA ────────────────────────────────────────────────────────
    def _fix_completada(self):
        self._clear(); self._busy(True)
        proj = self._project_filter()
        def _run():
            try:
                db = self._db_()
                docs = self._get_active(db, proj)
                stuck = [d for d in docs
                         if str(d.get("execution_state") or "").upper() == "COMPLETADA"
                         and not str(d.get("review_decision") or "").strip()]

                self._w(f"=== COMPLETADA SIN REVIEW_DECISION — {'PROYECTO: '+proj if proj else 'TODOS'} ===\n\n")
                self._w(f"Actividades afectadas: {len(stuck)}\n\n")

                if not stuck:
                    self._w("✅ Todas las actividades COMPLETADA tienen review_decision.\n")
                    self._busy(False)
                    return

                from collections import defaultdict
                by_proj: dict = defaultdict(list)
                for d in stuck:
                    by_proj[d.get("project_id", "—")].append(d)

                for pid, group in sorted(by_proj.items()):
                    self._w(f"📁 {pid}  ({len(group)})\n")
                    for d in group[:8]:
                        self._w(f"  • {d['_id'][:28]}  tipo={d.get('activity_type_code','—')}\n")
                        self._w(f"    front_id={d.get('front_id','—')}  user={d.get('created_by_user_id','—')}\n")
                    if len(group) > 8:
                        self._w(f"  … y {len(group)-8} más\n")
                    self._w("\n")

                self._busy(False)

                def _ask():
                    resp = messagebox.askyesno(
                        "Confirmar reparación",
                        f"Se encontraron {len(stuck)} actividades COMPLETADA sin review_decision.\n\n"
                        "¿Asignar review_decision='APPROVED' a todas?\n\n"
                        "Esta acción escribe directamente en Firestore.",
                        icon="warning"
                    )
                    if resp:
                        self._busy(True)
                        def _apply():
                            from datetime import timezone
                            now_iso = datetime.now(timezone.utc).isoformat()
                            count = errs = 0
                            for d in stuck:
                                try:
                                    db.collection("activities").document(d["_id"]).update({
                                        "review_decision": "APPROVED",
                                        "review_at": now_iso,
                                        "updated_at": now_iso,
                                    })
                                    count += 1
                                    self._w(f"  ✅ {d['_id'][:28]} → APPROVED\n")
                                except Exception as ex:
                                    self._w(f"  ❌ {d['_id'][:28]}: {ex}\n")
                                    errs += 1
                            self._w(f"\n✅ Reparadas: {count}  |  ❌ Errores: {errs}\n")
                            self._busy(False)
                        threading.Thread(target=_apply, daemon=True).start()
                self.after(0, _ask)
            except Exception as exc:
                self._w(f"ERROR: {exc}\n")
                self._busy(False)
        threading.Thread(target=_run, daemon=True).start()

    # ── LIMPIAR ERRORES SYNC ──────────────────────────────────────────────────
    def _clear_sync_errors(self):
        self._clear(); self._busy(True)
        proj = self._project_filter()
        def _run():
            try:
                db = self._db_()
                docs = self._get_active(db, proj)
                errors = [d for d in docs
                          if str(d.get("sync_status") or "").upper() in ("ERROR", "FAILED", "CONFLICT")]

                self._w(f"=== ERRORES DE SYNC — {'PROYECTO: '+proj if proj else 'TODOS'} ===\n\n")
                self._w(f"Registros con error: {len(errors)}\n\n")

                if not errors:
                    self._w("✅ Sin errores de sync.\n")
                    self._busy(False)
                    return

                for d in errors[:25]:
                    self._w(f"  {d['_id'][:28]}  sync_status={d.get('sync_status')}\n")
                    self._w(f"    proyecto={d.get('project_id','—')}  user={d.get('created_by_user_id','—')}\n")
                    if d.get("sync_error"):
                        self._w(f"    error: {str(d['sync_error'])[:80]}\n")
                    self._w("\n")
                if len(errors) > 25:
                    self._w(f"… y {len(errors)-25} más\n")

                self._busy(False)

                def _ask():
                    resp = messagebox.askyesno(
                        "Limpiar errores de sync",
                        f"Se encontraron {len(errors)} actividades con sync_status=ERROR/CONFLICT/FAILED.\n\n"
                        "¿Limpiar sync_status y sync_error para permitir reintento?\n\n"
                        "Las actividades quedarán marcadas para ser resincronizadas.",
                        icon="warning"
                    )
                    if resp:
                        self._busy(True)
                        def _apply():
                            from datetime import timezone
                            now_iso = datetime.now(timezone.utc).isoformat()
                            count = errs = 0
                            for d in errors:
                                try:
                                    db.collection("activities").document(d["_id"]).update({
                                        "sync_status": None,
                                        "sync_error": None,
                                        "updated_at": now_iso,
                                    })
                                    count += 1
                                    self._w(f"  ✅ {d['_id'][:28]} → sync limpiado\n")
                                except Exception as ex:
                                    self._w(f"  ❌ {d['_id'][:28]}: {ex}\n")
                                    errs += 1
                            self._w(f"\n✅ Limpiados: {count}  |  ❌ Errores: {errs}\n")
                            self._busy(False)
                        threading.Thread(target=_apply, daemon=True).start()
                self.after(0, _ask)
            except Exception as exc:
                self._w(f"ERROR: {exc}\n")
                self._busy(False)
        threading.Thread(target=_run, daemon=True).start()

    # ── RECUPERAR BORRADAS ────────────────────────────────────────────────────
    def _recover_deleted(self):
        self._clear(); self._busy(True)
        proj = self._project_filter()
        def _run():
            try:
                db = self._db_()
                q = db.collection("activities").where("project_id", "==", proj) if proj \
                    else db.collection("activities")
                deleted = []
                for snap in q.stream():
                    doc = snap.to_dict() or {}
                    if doc.get("deleted_at"):
                        doc["_id"] = snap.id
                        deleted.append(doc)

                self._w(f"=== ACTIVIDADES BORRADAS — {'PROYECTO: '+proj if proj else 'TODOS'} ===\n\n")
                self._w(f"Total borradas: {len(deleted)}\n\n")

                if not deleted:
                    self._w("✅ Sin actividades borradas.\n")
                    self._busy(False)
                    return

                for d in deleted[:40]:
                    self._w(f"  ID: {d['_id']}\n")
                    self._w(f"    proyecto={d.get('project_id','—')}  tipo={d.get('activity_type_code','—')}\n")
                    self._w(f"    estado={d.get('execution_state','—')}  user={d.get('created_by_user_id','—')}\n")
                    self._w(f"    borrada={d.get('deleted_at')}  por={d.get('deleted_by','—')}\n\n")
                if len(deleted) > 40:
                    self._w(f"… y {len(deleted)-40} más\n\n")

                self._busy(False)
                self._w("→ Copia el ID y usa 'Undelete por ID' para recuperar una actividad específica.\n")
            except Exception as exc:
                self._w(f"ERROR: {exc}\n")
                self._busy(False)
        threading.Thread(target=_run, daemon=True).start()

    # ── UNDELETE POR ID ───────────────────────────────────────────────────────
    def _undelete_by_id(self):
        dlg = tk.Toplevel()
        dlg.title("Recuperar actividad por ID")
        dlg.configure(bg=CARD)
        dlg.geometry("480x200")
        dlg.resizable(False, False)

        tk.Label(dlg, text="ID del documento en Firestore:", fg=TEXT, bg=CARD,
                 font=("Helvetica", 13, "bold")).pack(pady=(18, 6), padx=20, anchor="w")
        tk.Label(dlg, text="(El ID se muestra en la lista de actividades borradas)",
                 fg=MUTED, bg=CARD, font=("Helvetica", 11)).pack(padx=20, anchor="w")

        entry_var = tk.StringVar()
        entry = tk.Entry(dlg, textvariable=entry_var, bg=SIDEBAR, fg=TEXT,
                         insertbackground=TEXT, font=("Courier New", 12),
                         relief="flat", width=40)
        entry.pack(padx=20, pady=10, fill="x")
        entry.focus()

        def _do():
            doc_id = entry_var.get().strip()
            if not doc_id:
                messagebox.showwarning("Campo vacío", "Ingresa un ID de actividad.", parent=dlg)
                return
            resp = messagebox.askyesno(
                "Confirmar undelete",
                f"¿Recuperar actividad:\n{doc_id}\n\n"
                "Se limpiará deleted_at y deleted_by en Firestore.",
                parent=dlg, icon="warning"
            )
            if not resp:
                return
            dlg.destroy()
            self._w(f"\n=== UNDELETE: {doc_id} ===\n")
            self._busy(True)
            def _apply():
                try:
                    from datetime import timezone
                    now_iso = datetime.now(timezone.utc).isoformat()
                    db = self._db_()
                    ref = db.collection("activities").document(doc_id)
                    snap = ref.get()
                    if not snap.exists:
                        self._w("❌ Documento no encontrado en Firestore.\n")
                        self._busy(False)
                        return
                    doc = snap.to_dict() or {}
                    if not doc.get("deleted_at"):
                        self._w("⚠️  La actividad no está borrada (deleted_at vacío).\n")
                        self._busy(False)
                        return
                    ref.update({"deleted_at": None, "deleted_by": None, "updated_at": now_iso})
                    self._w(f"✅ Actividad recuperada:\n")
                    self._w(f"  proyecto={doc.get('project_id','—')}  tipo={doc.get('activity_type_code','—')}\n")
                    self._w(f"  estado={doc.get('execution_state','—')}  user={doc.get('created_by_user_id','—')}\n")
                except Exception as exc:
                    self._w(f"❌ Error: {exc}\n")
                finally:
                    self._busy(False)
            threading.Thread(target=_apply, daemon=True).start()

        btn_row = tk.Frame(dlg, bg=CARD)
        btn_row.pack(pady=4)
        tk.Button(btn_row, text="Recuperar", command=_do,
                  bg=ACCENT, fg="#000", font=("Helvetica", 12),
                  relief="flat", padx=14, pady=6).pack(side="left", padx=6)
        tk.Button(btn_row, text="Cancelar", command=dlg.destroy,
                  bg=BORDER, fg=TEXT, font=("Helvetica", 12),
                  relief="flat", padx=14, pady=6).pack(side="left", padx=6)


# ─────────────────────────────────────────────────────────────────────────────
# MAIN WINDOW
# ─────────────────────────────────────────────────────────────────────────────

NAV_ITEMS = [
    ("  Dashboard",     "dashboard"),
    ("  Firestore",     "firestore"),
    ("  Operativos",    "operativos"),
    ("  Backend",       "backend"),
    ("  Diagnósticos",  "diagnostics"),
    ("  Flutter",       "flutter"),
]


class App:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("SAO Developer Console")
        self.root.geometry("1200x800")
        self.root.minsize(900, 580)
        self.root.configure(bg=BG)

        self._cur = 0
        self._panels: list[Any] = []
        self._nav_btns: list[tk.Button] = []

        self._build()

    def _build(self):
        # ── sidebar ───────────────────────────────────────────────────────────
        sidebar = tk.Frame(self.root, bg=SIDEBAR, width=210)
        sidebar.pack(side="left", fill="y")
        sidebar.pack_propagate(False)

        # logo
        logo_f = tk.Frame(sidebar, bg=SIDEBAR)
        logo_f.pack(fill="x", padx=16, pady=(20, 4))
        tk.Label(logo_f, text="⬡ SAO", fg=ACCENT, bg=SIDEBAR,
                 font=("Helvetica", 18, "bold"), anchor="w").pack(anchor="w")
        tk.Label(logo_f, text="Developer Console", fg=MUTED, bg=SIDEBAR,
                 font=("Helvetica", 10), anchor="w").pack(anchor="w")

        tk.Frame(sidebar, bg=BORDER, height=1).pack(fill="x", padx=12, pady=10)

        # nav buttons
        for i, (label, _key) in enumerate(NAV_ITEMS):
            btn = tk.Button(
                sidebar, text=label, anchor="w",
                bg=SIDEBAR, fg=TEXT,
                activebackground=NAV_HOV, activeforeground=ACCENT,
                relief="flat", padx=8, pady=10, cursor="hand2",
                font=("Helvetica", 13),
                command=lambda i=i: self._switch(i),
            )
            btn.pack(fill="x", padx=8, pady=1)
            self._nav_btns.append(btn)

            def _enter(e, b=btn): b.config(bg=NAV_HOV)
            def _leave(e, b=btn, i=i): b.config(bg=NAV_SEL if i==self._cur else SIDEBAR)
            btn.bind("<Enter>", _enter)
            btn.bind("<Leave>", _leave)

        tk.Frame(sidebar, bg=BORDER, height=1).pack(fill="x", padx=12, pady=10, side="bottom")
        tk.Label(sidebar, text=FS_PROJECT, fg=MUTED, bg=SIDEBAR,
                 font=("Helvetica", 9), anchor="w").pack(side="bottom", padx=16, pady=(0, 8), fill="x")

        # ── separator ─────────────────────────────────────────────────────────
        tk.Frame(self.root, bg=BORDER, width=1).pack(side="left", fill="y")

        # ── content area ──────────────────────────────────────────────────────
        content = tk.Frame(self.root, bg=BG)
        content.pack(side="left", fill="both", expand=True, padx=24, pady=20)

        # build all panels (order must match NAV_ITEMS)
        self._panels = [
            DashboardPanel(content,    self.root.after),
            FirestorePanel(content,    self.root.after),
            OperativosPanel(content,   self.root.after),
            BackendPanel(content,      self.root.after),
            DiagnosticsPanel(content,  self.root.after),
            FlutterPanel(content,      self.root.after),
        ]

        # show first panel
        self._switch(0)

    def _switch(self, idx: int):
        # hide current
        for p in self._panels:
            p.hide()
        # update nav highlight
        for i, btn in enumerate(self._nav_btns):
            btn.config(bg=NAV_SEL if i == idx else SIDEBAR,
                       fg=ACCENT if i == idx else TEXT)
        # show new
        self._cur = idx
        self._panels[idx].show()

    def run(self):
        self.root.mainloop()


if __name__ == "__main__":
    App().run()
