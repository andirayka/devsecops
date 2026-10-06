import os
from pathlib import Path

import psycopg
from flask import Flask, jsonify

app = Flask(__name__)


def database_connection():
    password_file = Path(os.environ["DB_PASSWORD_FILE"])
    password = password_file.read_text(encoding="utf-8").strip()
    return psycopg.connect(
        host=os.environ["DB_HOST"],
        port=int(os.environ.get("DB_PORT", "5432")),
        dbname=os.environ["DB_NAME"],
        user=os.environ["DB_USER"],
        password=password,
    )


@app.get("/")
def index():
    try:
        with database_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT version();")
                database_version = cursor.fetchone()[0]
        return jsonify(
            status="ok",
            message="Nginx, Flask, dan PostgreSQL berhasil terhubung",
            database=database_version,
        )
    except Exception:
        app.logger.exception("Request gagal karena database tidak tersedia")
        return jsonify(status="error", message="Koneksi database gagal"), 503


@app.get("/health")
def health():
    try:
        with database_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1;")
                cursor.fetchone()
        return jsonify(status="healthy"), 200
    except Exception:
        return jsonify(status="unhealthy"), 503
