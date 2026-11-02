FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Install dependencies first so this layer is cached between builds.
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY src/ .

# Run as an unprivileged user (Trivy misconfig scan flags root images).
RUN useradd --system --uid 10001 --no-create-home appuser
USER appuser

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:5000/health', timeout=2)"]

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
