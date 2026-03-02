from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

# Test login
response = client.post('/api/v1/auth/login', json={
    'email': 'admin@sao.mx',
    'password': 'admin123'
})

print(f"Status: {response.status_code}")
if response.status_code == 200:
    data = response.json()
    print(f"[OK] Login successful!")
    print(f"Has access_token: {'access_token' in data}")
    print(f"Has refresh_token: {'refresh_token' in data}")
    
    # Test /me endpoint
    token = data['access_token']
    me_response = client.get('/api/v1/auth/me', headers={'Authorization': f'Bearer {token}'})
    print(f"\n/me Status: {me_response.status_code}")
    if me_response.status_code == 200:
        user_data = me_response.json()
        print(f"[OK] User: {user_data['email']}")
    else:
        print(f"[ERROR] /me failed: {me_response.text}")
else:
    print(f"[ERROR] Login failed: {response.text}")
