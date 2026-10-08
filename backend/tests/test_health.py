def test_health_returns_success(client):
    response = client.get("/api/health")

    assert response.status_code == 200
    payload = response.get_json()
    assert payload["status"] == "success"
    assert payload["message"] == "Server market, berita, dan analisis Mones terhubung."
    assert payload["serverTime"].endswith("Z")
