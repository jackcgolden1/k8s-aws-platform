import os
import socket

from flask import Flask, jsonify

app = Flask(__name__)


@app.get("/")
def index():
    return jsonify(
        message="Hello from Kubernetes!",
        host=socket.gethostname(),
        version=os.getenv("APP_VERSION", "v1"),
    )


@app.get("/health")
def health():
    return jsonify(status="ok")

@app.get("/cpu")
def cpu():
    total = 0
    for i in range(2_000_000):
        total += i * i
    return jsonify(result=total)