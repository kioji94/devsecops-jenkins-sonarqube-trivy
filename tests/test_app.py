import pytest

from app import create_app


@pytest.fixture()
def client():
    flask_app = create_app()
    flask_app.config.update(TESTING=True)
    return flask_app.test_client()


def test_index(client):
    response = client.get("/")
    assert response.status_code == 200
    assert response.get_json() == {"service": "devsecops-demo", "status": "ok"}


def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json() == {"status": "healthy"}


@pytest.mark.parametrize(("a", "b", "expected"), [(2, 3, 5), (0, 0, 0), (10, 32, 42)])
def test_add(client, a, b, expected):
    response = client.get(f"/add/{a}/{b}")
    assert response.status_code == 200
    assert response.get_json() == {"result": expected}


def test_add_rejects_non_integers(client):
    assert client.get("/add/two/three").status_code == 404


def test_unknown_route_returns_404(client):
    assert client.get("/nope").status_code == 404
