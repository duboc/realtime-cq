import json
import os
import time
from collections import deque
from datetime import datetime, timezone
from typing import Optional

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

app = FastAPI(title="RealTime CQ Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Mode selection ---
USE_MEMORY = os.environ.get("USE_MEMORY", "").strip() == "1"

# --- Firestore client (lazy init) ---
db = None
if not USE_MEMORY:
    from google.cloud import firestore
    db = firestore.AsyncClient()

# --- In-memory fallback ---
memory_buffer: deque = deque(maxlen=3600)

# --- Session management ---
SESSION_TIMEOUT_SECONDS = 300  # 5 min of no data = new session
_active_session_id: Optional[str] = None
_last_data_time: float = 0.0


class WatchPayload(BaseModel):
    ts: Optional[float] = None
    hr: Optional[float] = None
    spd: Optional[float] = None
    gspd: Optional[float] = None
    cad: Optional[float] = None
    alt: Optional[float] = None
    lat: Optional[float] = None
    lon: Optional[float] = None
    dist: Optional[float] = None
    cal: Optional[float] = None
    et: Optional[float] = None
    ax: Optional[float] = None
    ay: Optional[float] = None
    az: Optional[float] = None
    hrv: Optional[float] = None
    hri: Optional[float] = None
    mhr: Optional[float] = None
    rhr: Optional[float] = None
    fat: Optional[float] = None


async def _get_or_create_session() -> str:
    global _active_session_id, _last_data_time
    from google.cloud import firestore as fs

    now = time.time()
    if _active_session_id and (now - _last_data_time) < SESSION_TIMEOUT_SECONDS:
        _last_data_time = now
        return _active_session_id

    # Create new session
    session_ref = db.collection("sessions").document()
    await session_ref.set({
        "created_at": fs.SERVER_TIMESTAMP,
        "status": "active",
    })
    _active_session_id = session_ref.id
    _last_data_time = now
    return _active_session_id


async def _find_active_session() -> Optional[str]:
    global _active_session_id
    from google.cloud import firestore as fs

    if _active_session_id:
        return _active_session_id

    sessions = (
        db.collection("sessions")
        .where("status", "==", "active")
        .order_by("created_at", direction=fs.Query.DESCENDING)
        .limit(1)
    )
    docs = []
    async for doc in sessions.stream():
        docs.append(doc)

    if docs:
        _active_session_id = docs[0].id
        return _active_session_id
    return None


@app.post("/api/data")
async def receive_data(payload: WatchPayload):
    record = payload.model_dump()

    if USE_MEMORY or db is None:
        memory_buffer.append(record)
        return {"status": "ok", "buffered": len(memory_buffer)}

    from google.cloud import firestore as fs

    session_id = await _get_or_create_session()

    doc_data = {k: v for k, v in record.items() if v is not None}
    doc_data["ingested_at"] = fs.SERVER_TIMESTAMP

    await (
        db.collection("sessions")
        .document(session_id)
        .collection("data_points")
        .add(doc_data)
    )

    return {"status": "ok", "session": session_id}


@app.get("/api/history")
async def get_history(limit: int = 200, after: Optional[str] = None):
    if USE_MEMORY or db is None:
        data = list(memory_buffer)
        return {"data": data, "session": None, "cursor": None}

    from google.cloud import firestore as fs

    session_id = await _find_active_session()
    if not session_id:
        return {"data": [], "session": None, "cursor": None}

    query = (
        db.collection("sessions")
        .document(session_id)
        .collection("data_points")
    )

    if after:
        cursor_time = datetime.fromisoformat(after)
        query = (
            query.where("ingested_at", ">", cursor_time)
            .order_by("ingested_at", direction=fs.Query.ASCENDING)
            .limit(limit)
        )
    else:
        query = (
            query.order_by("ingested_at", direction=fs.Query.DESCENDING)
            .limit(limit)
        )

    docs = []
    async for doc in query.stream():
        docs.append(doc.to_dict())

    last_ingested = None
    data = []
    for d in docs:
        if "ingested_at" in d and d["ingested_at"]:
            last_ingested = d["ingested_at"].isoformat()
            del d["ingested_at"]
        data.append(d)

    # Reverse if initial load (fetched descending)
    if not after:
        data.reverse()

    return {"data": data, "session": session_id, "cursor": last_ingested}


@app.get("/")
async def serve_dashboard():
    return FileResponse("static/index.html")


app.mount("/static", StaticFiles(directory="static"), name="static")
