from typing import Any
from PySide6.QtWidgets import QApplication
from PySide6.QtHttpServer import QHttpServer, QHttpServerRequest, QHttpServerResponse, QHttpServerResponder
from PySide6.QtNetwork import QHostAddress
from PySide6.QtCore import Signal, Slot, QObject, QJsonDocument
from PySide6.QtWidgets import QMainWindow


class MapStateHandler():
    on_new_map_state: Slot = None

    def __init__(self, on_new_map_state: Slot):
        self.on_new_map_state = on_new_map_state

    def __call__(self, request: QHttpServerRequest) -> QHttpServerResponse:
        json = QJsonDocument.fromJson(request.body())
        self.on_new_map_state(json.object())
        return QHttpServerResponse(QHttpServerResponder.StatusCode.Ok)


class HttpServer(QObject):
    server = None

    on_map_request = None

    def __init__(self, on_new_map_state: Signal):
        self.server = QHttpServer()
        self.on_map_request = MapStateHandler(on_new_map_state)

    def start(self) -> None:
        self.server.listen(QHostAddress.SpecialAddress.Any, 5000)
        self.server.route("/state", self.on_map_request)
