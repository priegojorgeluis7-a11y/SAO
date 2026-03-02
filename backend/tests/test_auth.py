"""Authentication endpoint tests."""


def _login(client, email: str, password: str):
    """Execute login request and return the HTTP response."""
    return client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": password},
    )


def test_login_success(client, test_user):
    """Test successful login"""
    response = _login(client, test_user.email, "testpass123")
    
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["token_type"] == "bearer"


def test_login_invalid_credentials(client, test_user):
    """Test login with wrong password"""
    response = _login(client, test_user.email, "wrongpassword")
    
    assert response.status_code == 401
    assert "Incorrect email or password" in response.json()["detail"]


def test_login_nonexistent_user(client):
    """Test login with non-existent email"""
    response = _login(client, "nonexistent@example.com", "anypassword")
    
    assert response.status_code == 401


def test_get_me_with_valid_token(client, test_user):
    """Test /auth/me endpoint with valid token"""
    login_response = _login(client, test_user.email, "testpass123")
    tokens = login_response.json()
    
    # Get me
    response = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {tokens['access_token']}"}
    )
    
    assert response.status_code == 200
    data = response.json()
    assert data["email"] == test_user.email
    assert data["full_name"] == test_user.full_name


def test_get_me_without_token(client):
    """Test /auth/me without authentication"""
    response = client.get("/api/v1/auth/me")
    assert response.status_code == 401


def test_refresh_token(client, test_user):
    """Test token refresh endpoint"""
    login_response = _login(client, test_user.email, "testpass123")
    tokens = login_response.json()
    
    # Refresh
    response = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": tokens["refresh_token"]}
    )
    
    assert response.status_code == 200
    new_tokens = response.json()
    assert "access_token" in new_tokens
    assert "refresh_token" in new_tokens
    assert new_tokens["token_type"] == "bearer"
    assert isinstance(new_tokens["access_token"], str) and len(new_tokens["access_token"]) > 0
