"""
Light Load Test - Locust
Tests 100 concurrent users performing typical activities

Run: locust -f load_tests/locust_light_load.py --host=http://localhost:8000 --users=100 --spawn-rate=10 --run-time=5m --headless --csv=load_tests/results/light_load
"""

from locust import HttpUser, task, between, events
import random
import json
import os

# Test data
TEST_EMAIL = os.getenv("SAO_LOADTEST_EMAIL", "testuser@test.com")
TEST_PASSWORD = os.getenv("SAO_LOADTEST_PASSWORD")
TEST_ACTIVITY_ID = int(os.getenv("SAO_LOADTEST_ACTIVITY_ID", "1"))

if not TEST_PASSWORD:
    raise RuntimeError(
        "Missing SAO_LOADTEST_PASSWORD environment variable for load tests"
    )

class SaoLightUser(HttpUser):
    """Simulates typical user: login -> view activities -> logout"""
    
    wait_time = between(1, 3)  # Think time: 1-3 seconds
    token = None
    
    def on_start(self):
        """Login at start of test"""
        try:
            response = self.client.post(
                "/auth/login",
                json={
                    "email": TEST_EMAIL,
                    "password": TEST_PASSWORD
                },
                headers={"Content-Type": "application/json"},
                timeout=10
            )
            if response.status_code == 200:
                data = response.json()
                self.token = data.get("access_token")
                self.client.headers.update({"Authorization": f"Bearer {self.token}"})
                print(f"✅ Login successful for user {TEST_EMAIL}")
            else:
                print(f"❌ Login failed: {response.status_code}")
        except Exception as e:
            print(f"❌ Login error: {e}")
    
    @task(50)  # 50% of requests
    def get_activities(self):
        """GET /activities - Most frequent operation"""
        try:
            self.client.get(
                "/activities?page=1&limit=20",
                name="/activities",
                timeout=10
            )
        except Exception as e:
            print(f"Error getting activities: {e}")
    
    @task(20)  # 20% of requests
    def get_single_activity(self):
        """GET /activities/{id} - Get specific activity"""
        try:
            activity_id = random.randint(1, 100)
            self.client.get(
                f"/activities/{activity_id}",
                name="/activities/[id]",
                timeout=10
            )
        except Exception as e:
            print(f"Error getting single activity: {e}")
    
    @task(15)  # 15% of requests
    def search_activities(self):
        """GET /activities?search=... - Search operation"""
        try:
            keywords = ["urgent", "completed", "pending", "updated", "test"]
            self.client.get(
                f"/activities?search={random.choice(keywords)}&limit=20",
                name="/activities?search",
                timeout=10
            )
        except Exception as e:
            print(f"Error searching activities: {e}")
    
    @task(15)  # 15% of requests
    def sync_data(self):
        """GET /sync/pull - Sync operation"""
        try:
            self.client.get(
                "/sync/pull?limit=50&since=2024-01-01",
                name="/sync/pull",
                timeout=10
            )
        except Exception as e:
            print(f"Error syncing: {e}")
    
    def on_stop(self):
        """Logout"""
        try:
            if self.token:
                self.client.post("/auth/logout", timeout=10)
                print(f"✅ Logout successful")
        except Exception as e:
            print(f"Error during logout: {e}")


# Event listeners
@events.request.add_listener
def on_request(request_type, name, response_time, response_length, exception, **kw):
    """Log failures"""
    if exception:
        print(f"❌ {name}: {exception}")


@events.test_stop.add_listener
def on_test_stop(environment, **kw):
    """Print summary"""
    print("\n" + "="*50)
    print("✅ Light Load Test Completed")
    print("="*50)
