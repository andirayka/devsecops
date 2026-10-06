from flask import Flask, jsonify, request

app = Flask(__name__)


@app.get("/")
def index():
    return jsonify(
        status="ok",
        service="flask-app",
        message="API Bab 4 diakses melalui Nginx reverse proxy",
        forwarded_proto=request.headers.get("X-Forwarded-Proto"),
    )


@app.get("/health")
def health():
    return jsonify(status="healthy"), 200
