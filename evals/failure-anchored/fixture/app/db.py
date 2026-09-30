import socket

from app import settings


def connect():
    return socket.create_connection((settings.DB_HOST, settings.DB_PORT), timeout=5)
