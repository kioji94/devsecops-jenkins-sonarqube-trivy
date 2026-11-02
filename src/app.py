"""Minimal Flask service used as the target of the DevSecOps pipeline."""

from flask import Flask, jsonify


def create_app() -> Flask:
    """Application factory (keeps the app easy to test)."""
    flask_app = Flask(__name__)

    @flask_app.get("/")
    def index():
        return jsonify(service="devsecops-demo", status="ok")

    @flask_app.get("/health")
    def health():
        return jsonify(status="healthy"), 200

    @flask_app.get("/add/<int:a>/<int:b>")
    def add(a: int, b: int):
        return jsonify(result=a + b)

    return flask_app


app = create_app()

if __name__ == "__main__":
    # Local development only. In the container, gunicorn serves `app:app`.
    app.run(host="127.0.0.1", port=5000)
