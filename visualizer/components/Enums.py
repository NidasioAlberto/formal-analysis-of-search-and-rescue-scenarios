from enum import Enum
from PySide6.QtGui import QColor


class CellType(Enum):
    EMPTY = 0
    FIRE = 1
    EXIT = 2
    FIRST_RESP = 3
    SURVIVOR = 4
    ZERO_RESP = 5
    IN_NEED = 6
    ASSISTED = 7
    ASSISTING = 8
    DRONE = 9


class CellColor(Enum):
    FIRE = QColor(255, 139, 131)
    EXIT = QColor(204, 251, 115)
