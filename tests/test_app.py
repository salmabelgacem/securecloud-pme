import os
import sys

import pytest

# Rend app/app.py importable sous le nom "app"
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "app"))
import app as application  # noqa: E402


@pytest.fixture
def client():
    application.app.config["TESTING"] = True
    return application.app.test_client()


def test_accueil(client):
    r = client.get("/")
    assert r.status_code == 200
    assert b"SecureCloud PME" in r.data


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.get_json() == {"status": "ok"}


def test_entetes_securite(client):
    h = client.get("/").headers
    assert h["X-Content-Type-Options"] == "nosniff"
    assert h["X-Frame-Options"] == "DENY"
    assert "default-src 'none'" in h["Content-Security-Policy"]
    assert h["Referrer-Policy"] == "no-referrer"
    assert h["Cache-Control"] == "no-store"


def test_db_indisponible_sans_configuration(client, monkeypatch):
    monkeypatch.delenv("DB_HOST", raising=False)
    r = client.get("/db")
    assert r.status_code == 503
    # Aucun detail technique n'est expose a l'utilisateur
    assert r.get_json() == {"database": "indisponible"}


def test_db_ok_avec_base_simulee(client, monkeypatch):
    monkeypatch.setenv("DB_HOST", "base-de-test")
    monkeypatch.setenv("DB_USER", "utilisateur-test")
    monkeypatch.setenv("DB_PASSWORD", os.urandom(8).hex())

    class FausseConnexion:
        def __enter__(self):
            return self

        def __exit__(self, *args):
            return False

        def execute(self, requete):
            class Resultat:
                def fetchone(self):
                    return ("PostgreSQL 18.3 on x86_64-pc-linux-gnu",)
            return Resultat()

    monkeypatch.setattr(application.psycopg, "connect", lambda **kw: FausseConnexion())
    r = client.get("/db")
    assert r.status_code == 200
    assert r.get_json() == {"database": "ok", "postgresql": "PostgreSQL 18.3"}