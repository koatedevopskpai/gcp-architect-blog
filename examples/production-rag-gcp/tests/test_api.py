from fastapi.testclient import TestClient

from app.main import app


def test_health():
    with TestClient(app) as client:
        r = client.get("/health")
        assert r.status_code == 200
        assert r.json()["status"] == "ok"


def test_ingest_and_query_end_to_end():
    with TestClient(app) as client:
        ingest = client.post(
            "/ingest",
            json={"documents": ["Cloud Run scales to zero.", "BigQuery stores analytics data."]},
        )
        assert ingest.status_code == 200
        assert ingest.json()["chunks"] >= 2

        query = client.post("/query", json={"question": "Does Cloud Run scale to zero?", "top_k": 1})
        assert query.status_code == 200
        body = query.json()
        assert body["grounded"] is True
        assert body["passages"]


def test_query_validation_rejects_empty_question():
    with TestClient(app) as client:
        r = client.post("/query", json={"question": ""})
        assert r.status_code == 422
