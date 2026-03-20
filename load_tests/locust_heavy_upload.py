"""
Heavy Upload Test - Locust
Tests 500 concurrent users uploading evidence files

Run: locust -f load_tests/locust_heavy_upload.py --host=http://localhost:8000 --users=500 --spawn-rate=25 --run-time=10m --headless --csv=load_tests/results/heavy_upload
"""

from locust import HttpUser, task, between, events
import random
import io
import os

TEST_EMAIL = os.getenv("SAO_LOADTEST_EMAIL", "testuser@test.com")
TEST_PASSWORD = os.getenv("SAO_LOADTEST_PASSWORD")

if not TEST_PASSWORD:
    raise RuntimeError(
        "Missing SAO_LOADTEST_PASSWORD environment variable for load tests"
    )

class SaoHeavyUploadUser(HttpUser):
    """Simulates peak load: multiple concurrent uploads"""
    
    wait_time = between(2, 5)
    token = None
    activity_id = None
    upload_id = None
    signed_url = None
    
    def on_start(self):
        """Login and get activity"""
        try:
            # Login
            response = self.client.post(
                "/auth/login",
                json={"email": TEST_EMAIL, "password": TEST_PASSWORD},
                timeout=10
            )
            if response.status_code == 200:
                data = response.json()
                self.token = data.get("access_token")
                self.client.headers.update({"Authorization": f"Bearer {self.token}"})
                
                # Get activity ID
                resp = self.client.get("/activities?limit=1", timeout=10)
                if resp.status_code == 200:
                    items = resp.json().get("items", [])
                    self.activity_id = items[0]["id"] if items else 1
        except Exception as e:
            print(f"Error during setup: {e}")
    
    @task(3)
    def upload_init(self):
        """Step 1: Initialize upload"""
        try:
            response = self.client.post(
                "/evidences/upload-init",
                json={
                    "activity_id": self.activity_id or 1,
                    "file_name": f"photo_{random.randint(1, 10000)}.jpg",
                    "mime_type": "image/jpeg",
                    "size_bytes": random.randint(1000000, 5000000)  # 1-5 MB
                },
                name="/evidences/upload-init",
                timeout=10
            )
            
            if response.status_code == 200:
                data = response.json()
                self.upload_id = data.get("upload_id")
                self.signed_url = data.get("signed_url")
        except Exception as e:
            print(f"Error in upload_init: {e}")
    
    @task(3)
    def upload_to_gcs(self):
        """Step 2: Upload to GCS signed URL"""
        try:
            if self.signed_url:
                # Simulate file upload with realistic data size
                fake_data = b"x" * random.randint(1000000, 3000000)
                
                # Upload to signed URL (note: this is direct to GCS, not through our API)
                self.client.put(
                    self.signed_url,
                    data=fake_data,
                    name="/gcs/signed-url",
                    timeout=30
                )
        except Exception as e:
            print(f"Error in upload_to_gcs: {e}")
    
    @task(1)
    def upload_complete(self):
        """Step 3: Complete upload"""
        try:
            if self.upload_id:
                self.client.post(
                    f"/evidences/{self.upload_id}/upload-complete",
                    json={"description": f"Evidence from load test #{random.randint(1, 1000)}"},
                    name="/evidences/[id]/upload-complete",
                    timeout=10
                )
        except Exception as e:
            print(f"Error in upload_complete: {e}")


@events.request.add_listener
def on_request(request_type, name, response_time, response_length, exception, **kw):
    if exception:
        print(f"❌ {name}: {exception}")


@events.test_stop.add_listener
def on_test_stop(environment, **kw):
    print("\n" + "="*50)
    print("✅ Heavy Upload Test Completed")
    print("="*50)
