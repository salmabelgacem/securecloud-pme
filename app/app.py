import logging
import os

import psycopg
from flask import Flask, jsonify
from flask_wtf.csrf import CSRFProtect

app = Flask(__name__)
# Clé secrète lue dans l'environnement (jamais écrite dans le code)
app.config["SECRET_KEY"] = os.environ.get("FLASK_SECRET_KEY") or os.urandom(32)
csrf = CSRFProtect(app)

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("securecloud")

MESSAGE = "SecureCloud PME - application en ligne (v2, deployee par le pipeline)"


@app.after_request
def entetes_securite(response):
    """Ajoute 7 en-têtes de sécurité à chaque réponse."""
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Content-Security-Policy"] = "default-src 'none'; frame-ancestors 'none'"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Permissions-Policy"] = "geolocation=(), camera=(), microphone=()"
    response.headers["Cross-Origin-Opener-Policy"] = "same-origin"
    response.headers["Cache-Control"] = "no-store"
    return response


@app.route("/")
def accueil():
    return MESSAGE


@app.route("/health")
def health():
    return jsonify(status="ok")


@app.route("/db")
def db():
    try:
        with psycopg.connect(
            host=os.environ["DB_HOST"],
            dbname=os.environ.get("DB_NAME", "securecloud"),
            user=os.environ["DB_USER"],
            password=os.environ["DB_PASSWORD"],
            sslmode="require",      # connexion chiffrée vers RDS
            connect_timeout=3,
        ) as conn:
            version = conn.execute("SELECT version()").fetchone()[0]
        return jsonify(database="ok", postgresql=version.split(" on ")[0])
    except Exception:
        # On écrit le détail dans les logs, mais on ne le montre pas à l'utilisateur
        log.exception("Connexion à la base impossible")
        return jsonify(database="indisponible"), 503