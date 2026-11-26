FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Correctifs de sécurité du système
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

# Utilisateur sans privilèges
RUN groupadd --system app && useradd --system --gid app --no-create-home app

WORKDIR /app

# Dépendances d'abord (meilleur cache Docker)
COPY app/requirements.txt .
RUN pip install --no-cache-dir --require-hashes --only-binary :all: -r requirements.txt

# Code de l'application
COPY app/app.py .

USER app
EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:5000/health')" || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]