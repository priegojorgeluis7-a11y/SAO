"""
Realistic Mixed Workload Test - Locust
Tests 1000 mixed users with realistic traffic patterns

Run: locust -f load_tests/locust_realistic.py --host=http://localhost:8000 --users=1000 --spawn-rate=50 --run-time=30m --headless --csv=load_tests/results/realistic_1000users
"""

from locust import HttpUser, task, between, events
import random

TEST_EMAIL = "testuser@test.com"
TEST_PASSWORD = "password123"

class RealisticSaoUser(HttpUser):
    """Realistic traffic: 70% read, 20% moderate write, 10% heavy operations"""
    
    wait_time = between(0.5, 2)
    token = None
    activity_ids = []
    
    def on_start(self):
        """Login"""
        try:
            response = self.client.post(
                "/auth/login",
                json={"email": TEST_EMAIL, "password": TEST_PASSWORD},
                timeout=10
            )
            if response.status_code == 200:
                data = response.json()
                self.token = data.get("access_token")
                self.client.headers.update({"Authorization": f"Bearer {self.token}"})
                
                # Cache some activity IDs
                resp = self.client.get("/activities?limit=50", timeout=10)
                if resp.status_code == 200:
                    self.activity_ids = [a.get("id", i) for i, a in enumerate(resp.json().get("items", []))]
                    if not self.activity_ids:
                        self.activity_ids = list(range(1, 11))  # Default IDs
        except Exception as e:
            print(f"Error during setup: {e}")
    
    @task(50)  # 50% - lightweight read operations
    def read_activities(self):
        """Lightweight read: get activities list"""
        try:
            page = random.randint(1, 5)
            self.client.get(
                f"/activities?page={page}&limit=10",
                name="/activities (read)",
                timeout=10
            )
        except Exception as e:
            pass
    
    @task(15)  # 15% - read single activity
    def get_single_activity(self):
        """Read specific activity"""
        try:
            activity_id = random.choice(self.activity_ids) if self.activity_ids else random.randint(1, 100)
            self.client.get(
                f"/activities/{activity_id}",
                name="/activities/[id]",
                timeout=10
            )
        except Exception as e:
            pass
    
    @task(5)  # 5% - update activity status (moderate write)
    def update_activity_status(self):
        """Update activity status"""
        try:
            if self.activity_ids:
                activity_id = random.choice(self.activity_ids)
                self.client.patch(
                    f"/activities/{activity_id}",
                    json={"status": random.choice(["PENDIENTE", "EN_CURSO", "COMPLETADA"])},
                    name="/activities/[id] (PATCH)",
                    timeout=10
                )
        except Exception as e:
            pass
    
    @task(5)  # 5% - create activity (heavy write)
    def create_activity(self):
        """Create new activity"""
        try:
            self.client.post(
                "/activities",
                json={
                    "project_id": random.randint(1, 20),
                    "activity_type": random.choice(["INSPECCIÓN", "SUPERVISIÓN", "MANTENIMIENTO"]),
                    "description": f"Automated test activity #{random.randint(1, 1000)}",
                    "status": "PENDIENTE"
                },
                name="/activities (POST)",
                timeout=10
            )
        except Exception as e:
            pass
    
    @task(20)  # 20% - sync operations
    def sync_operations(self):
        """Sync: pull + push"""
        try:
            # Pull
            self.client.get(
                "/sync/pull?limit=50&since=2024-01-01",
                name="/sync/pull",
                timeout=10
            )
            
            # Push (empty operations for now)
            self.client.post(
                "/sync/push",
                json={"operations": []},
                name="/sync/push",
                timeout=10
            )
        except Exception as e:
            pass


@events.request.add_listener
def on_request(request_type, name, response_time, response_length, exception, **kw):
    if exception:
        print(f"❌ {name}: {exception}")


@events.test_stop.add_listener
def on_test_stop(environment, **kw):
    print("\n" + "="*50)
    print("✅ Realistic Mixed Workload Test Completed")
    print("="*50)
