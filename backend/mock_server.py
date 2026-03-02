"""
SAO Backend Mock Server - For Load Testing
Simplified FastAPI server with in-memory mock data
No database required - perfect for load testing
"""

from fastapi import FastAPI, Depends, HTTPException, status, Header
from fastapi.responses import JSONResponse
from datetime import datetime, timedelta
from typing import Optional, List
import uuid
import jwt
from pydantic import BaseModel, EmailStr
import json
from functools import lru_cache

# ============================================================
# CONFIGURATION
# ============================================================

SECRET_KEY = "dev-secret-key-change-in-production"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

app = FastAPI(
    title="SAO API (Mock for Load Testing)",
    description="Offline-First Activity Management System - Mock Backend",
    version="1.0.0-mock"
)

# ============================================================
# MODELS
# ============================================================

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str

class ActivityCreate(BaseModel):
    id: Optional[str] = None
    title: str
    description: Optional[str] = None
    status: str = "DRAFT"
    location: Optional[str] = None
    pk: Optional[str] = None

class Activity(ActivityCreate):
    id: str
    created_at: str
    updated_at: str

class SyncPullResponse(BaseModel):
    activities: List[Activity]
    version: int
    timestamp: str

# ============================================================
# MOCK DATA
# ============================================================

MOCK_USERS = {
    "testuser@test.com": {
        "id": str(uuid.uuid4()),
        "email": "testuser@test.com",
        "password": "password123",  # In real system, this would be hashed
        "name": "Test User"
    }
}

MOCK_ACTIVITIES = [
    {
        "id": str(uuid.uuid4()),
        "title": f"Activity {i}",
        "description": f"Description for activity {i}",
        "status": "DRAFT",
        "location": "Bogotá",
        "pk": f"km+{i*10}",
        "created_at": datetime.utcnow().isoformat(),
        "updated_at": datetime.utcnow().isoformat()
    }
    for i in range(1, 101)  # 100 mock activities
]

# ============================================================
# UTILITY FUNCTIONS
# ============================================================

def create_access_token(user_id: str, expires_delta: Optional[timedelta] = None):
    """Create JWT access token"""
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode = {"sub": user_id, "exp": expire}
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def verify_token(token: str):
    """Verify JWT token"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")

def get_current_user(authorization: str = Header(None)):
    """Get current user from token"""
    if not authorization:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="No authorization")
    
    try:
        scheme, token = authorization.split()
        if scheme.lower() != "bearer":
            raise ValueError
    except (ValueError, AttributeError):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid header")
    
    payload = verify_token(token)
    return payload.get("sub")

# ============================================================
# ENDPOINTS: HEALTH
# ============================================================

@app.get("/health")
def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "version": "1.0.0-mock"
    }

# ============================================================
# ENDPOINTS: AUTH
# ============================================================

@app.post("/auth/login", response_model=TokenResponse)
async def login(request: UserLogin):
    """POST /auth/login - Authentication"""
    user = MOCK_USERS.get(request.email)
    if not user or user["password"] != request.password:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    
    access_token = create_access_token(user["id"])
    return {
        "access_token": access_token,
        "token_type": "bearer"
    }

# ============================================================
# ENDPOINTS: ACTIVITIES
# ============================================================

@app.get("/activities", response_model=List[Activity])
async def list_activities(
    current_user: str = Depends(get_current_user),
    skip: int = 0,
    limit: int = 50
):
    """GET /activities - List activities"""
    return MOCK_ACTIVITIES[skip:skip + limit]

@app.get("/activities/{activity_id}", response_model=Activity)
async def get_activity(
    activity_id: str,
    current_user: str = Depends(get_current_user)
):
    """GET /activities/{id} - Get single activity"""
    for activity in MOCK_ACTIVITIES:
        if activity["id"] == activity_id:
            return activity
    raise HTTPException(status_code=404, detail="Activity not found")

@app.get("/activities/search", response_model=List[Activity])
async def search_activities(
    current_user: str = Depends(get_current_user),
    q: str = "",
    skip: int = 0,
    limit: int = 50
):
    """GET /activities/search - Search activities"""
    results = [
        a for a in MOCK_ACTIVITIES
        if q.lower() in a.get("title", "").lower() or 
           q.lower() in a.get("description", "").lower()
    ]
    return results[skip:skip + limit]

@app.post("/activities", response_model=Activity)
async def create_activity(
    activity: ActivityCreate,
    current_user: str = Depends(get_current_user)
):
    """POST /activities - Create activity"""
    new_activity = {
        "id": activity.id or str(uuid.uuid4()),
        "title": activity.title,
        "description": activity.description,
        "status": activity.status,
        "location": activity.location,
        "pk": activity.pk,
        "created_at": datetime.utcnow().isoformat(),
        "updated_at": datetime.utcnow().isoformat()
    }
    MOCK_ACTIVITIES.append(new_activity)
    return new_activity

@app.put("/activities/{activity_id}", response_model=Activity)
async def update_activity(
    activity_id: str,
    activity: ActivityCreate,
    current_user: str = Depends(get_current_user)
):
    """PUT /activities/{id} - Update activity"""
    for i, a in enumerate(MOCK_ACTIVITIES):
        if a["id"] == activity_id:
            MOCK_ACTIVITIES[i].update({
                "title": activity.title,
                "description": activity.description,
                "status": activity.status,
                "location": activity.location,
                "pk": activity.pk,
                "updated_at": datetime.utcnow().isoformat()
            })
            return MOCK_ACTIVITIES[i]
    raise HTTPException(status_code=404, detail="Activity not found")

# ============================================================
# ENDPOINTS: SYNC
# ============================================================

@app.post("/sync/pull", response_model=SyncPullResponse)
async def sync_pull(
    current_user: str = Depends(get_current_user),
    since_version: int = 0,
    limit: int = 100
):
    """POST /sync/pull - Pull activities"""
    return {
        "activities": MOCK_ACTIVITIES[:limit],
        "version": len(MOCK_ACTIVITIES),
        "timestamp": datetime.utcnow().isoformat()
    }

# ============================================================
# ENDPOINTS: EVIDENCES (Mock Upload)
# ============================================================

@app.post("/evidences/upload-init")
async def evidence_upload_init(
    current_user: str = Depends(get_current_user),
    activity_id: str = None
):
    """POST /evidences/upload-init - Initialize upload"""
    return {
        "upload_id": str(uuid.uuid4()),
        "signed_url": "https://mock-gcs-url.example.com/signed-upload-url",
        "expires_in": 3600
    }

@app.post("/evidences/upload-complete")
async def evidence_upload_complete(
    current_user: str = Depends(get_current_user),
    upload_id: str = None,
    activity_id: str = None
):
    """POST /evidences/upload-complete - Complete upload"""
    return {
        "evidence_id": str(uuid.uuid4()),
        "status": "uploaded",
        "download_url": "https://mock-gcs-url.example.com/evidence"
    }

# ============================================================
# STARTUP/SHUTDOWN
# ============================================================

@app.on_event("startup")
async def startup_event():
    """Startup event"""
    print("🚀 Mock backend started successfully!")
    print(f"📊 Mock data: {len(MOCK_ACTIVITIES)} activities loaded")
    print("🔐 Test user: testuser@test.com / password123")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
