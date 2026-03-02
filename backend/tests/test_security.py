from app.core.security import (
    get_password_hash,
    verify_password,
    create_access_token,
    create_refresh_token,
    verify_token
)


def test_password_hashing():
    """Test password hash and verify"""
    password = "mysecretpassword"
    hashed = get_password_hash(password)
    
    assert hashed != password
    assert verify_password(password, hashed) is True
    assert verify_password("wrongpassword", hashed) is False


def test_create_and_verify_access_token():
    """Test JWT access token creation and verification"""
    data = {"sub": "user-123"}
    token = create_access_token(data)
    
    assert token is not None
    
    decoded = verify_token(token, expected_type="access")
    assert decoded["sub"] == "user-123"
    assert decoded["type"] == "access"


def test_create_and_verify_refresh_token():
    """Test JWT refresh token creation and verification"""
    data = {"sub": "user-456"}
    token = create_refresh_token(data)
    
    assert token is not None
    
    decoded = verify_token(token, expected_type="refresh")
    assert decoded["sub"] == "user-456"
    assert decoded["type"] == "refresh"


def test_verify_invalid_token():
    """Test verification of invalid token"""
    try:
        verify_token("invalid.token.here")
        assert False, "Should have raised ValueError"
    except ValueError as e:
        assert "Invalid token" in str(e)
