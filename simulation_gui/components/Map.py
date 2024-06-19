from PySide6.QtWidgets import QLabel
from PySide6.QtGui import QPainter, QPixmap, QColorConstants, QGuiApplication
from PySide6.QtCore import QRect, QSize, Qt

from components.Enums import CellType, CellColor


class MapWidget(QLabel):
    assets = {}

    def __init__(self, N_COLS, N_ROWS, PIXELS_PER_CELL=50):
        super().__init__()

        # Initialize variables
        self.N_COLS = N_COLS
        self.N_ROWS = N_ROWS
        self.PIXELS_PER_CELL = PIXELS_PER_CELL

        # Set proper widget size
        window_size = QSize(N_COLS * PIXELS_PER_CELL + 1,
                            N_ROWS * PIXELS_PER_CELL + 1)
        self.setFixedSize(window_size)
        canvas = QPixmap(window_size)
        canvas.fill(QColorConstants.White)
        self.setPixmap(canvas)

        self.load_assets()

    def load_assets(self):
        asset = QPixmap(self.PIXELS_PER_CELL, self.PIXELS_PER_CELL)
        asset.fill(CellColor.FIRE.value)
        self.assets[CellType.FIRE] = asset

        asset = QPixmap(self.PIXELS_PER_CELL, self.PIXELS_PER_CELL)
        asset.fill(CellColor.EXIT.value)
        self.assets[CellType.EXIT] = asset

        asset = QPixmap("assets/first_responder_50.png")
        self.assets[CellType.FIRST_RESP] = asset
        self.assets[CellType.ASSISTING] = asset

        asset = QPixmap("assets/survivor_50.png")
        self.assets[CellType.SURVIVOR] = asset
        self.assets[CellType.ZERO_RESP] = asset

        asset = QPixmap("assets/in_need_50.png")
        self.assets[CellType.IN_NEED] = asset
        self.assets[CellType.ASSISTED] = asset

        asset = QPixmap("assets/drone_50.png")
        self.assets[CellType.DRONE] = asset

    def draw_grid(self):
        canvas = self.pixmap()
        painter = QPainter(canvas)

        for x in range(0, self.N_COLS+1):
            for y in range(0, self.N_ROWS+1):
                painter.drawLine(x * self.PIXELS_PER_CELL, 0, x *
                                 self.PIXELS_PER_CELL, self.N_ROWS * self.PIXELS_PER_CELL - 1)
                painter.drawLine(0, y * self.PIXELS_PER_CELL, self.N_COLS *
                                 self.PIXELS_PER_CELL - 1, y * self.PIXELS_PER_CELL)

        painter.end()
        self.setPixmap(canvas)

    def clear(self):
        canvas = QPixmap(self.size())
        canvas.fill(QColorConstants.White)
        self.setPixmap(canvas)
        self.draw_grid()

    def draw_cell(self, cell_type, x, y):
        canvas = self.pixmap()
        painter = QPainter(canvas)

        target_rect = QRect(x * self.PIXELS_PER_CELL + 1, y * self.PIXELS_PER_CELL + 1,
                            self.PIXELS_PER_CELL - 1, self.PIXELS_PER_CELL - 1)
        # painter.setRenderHint(QPainter.SmoothPixmapTransform)
        painter.drawPixmap(target_rect, self.assets[cell_type].copy())

        painter.end()
        self.setPixmap(canvas)

    def draw_cells(self, cells):
        for x in range(self.N_COLS):
            for y in range(self.N_ROWS):
                if cells[x][y] != CellType.EMPTY.value:
                    self.draw_cell(CellType(cells[x][y]), x, y)

    def draw_drones(self, drones):
        for x in range(self.N_COLS):
            for y in range(self.N_ROWS):
                if drones[x][y]:
                    self.draw_cell(CellType.DRONE, x, y)

    def draw_map(self, map):
        self.clear()
        self.draw_cells(map["cells"])
        self.draw_drones(map["drones"])


class MapEditorWidget(MapWidget):
    map = {}

    press_position = None
    last_cell_tool = CellType.FIRE

    def __init__(self, N_COLS, N_ROWS, PIXELS_PER_CELL=50):
        super().__init__(N_COLS, N_ROWS, PIXELS_PER_CELL)

        self.map = {
            "cells": [[0 for _ in range(N_COLS)] for _ in range(N_ROWS)],
            "drones": [[0 for _ in range(N_COLS)] for _ in range(N_ROWS)]
        }

        self.draw_map(self.map)

    def set_cell(self, cell_type, pos):
        self.map["cells"][pos[0]][pos[1]] = cell_type.value

    def set_cell_rect(self, cell_type, pos1, pos2):
        (x1, y1) = pos1
        (x2, y2) = pos2

        for x in range(x1, x2 + 1):
            for y in range(y1, y2 + 1):
                self.set_cell(cell_type, (x, y))

    def set_drone(self, cell_type, pos):
        if cell_type == CellType.EMPTY:
            self.map["drones"][pos[0]][pos[1]] = 0
        elif cell_type == CellType.DRONE:
            self.map["drones"][pos[0]][pos[1]] = 1

    def set_map_drone_rect(self, cell_type, pos1, pos2):
        (x1, y1) = pos1
        (x2, y2) = pos2

        for x in range(x1, x2 + 1):
            for y in range(y1, y2 + 1):
                self.set_drone(cell_type, (x, y))

    def map_position_from_pixel(self, x, y):
        return int(x // self.PIXELS_PER_CELL), int(y // self.PIXELS_PER_CELL)

    def choose_tools(self, press_pos, release_pos, button):
        # Use the press position as source
        (x, y) = press_pos

        # In all cases, if the middle button is pressed we clear everything
        if button == Qt.MouseButton.MiddleButton:
            return CellType.EMPTY

        # If shift is pressed, draw drones
        if QGuiApplication.keyboardModifiers() == Qt.KeyboardModifier.ShiftModifier:
            if self.map["drones"][x][y] == CellType.EMPTY.value:
                return CellType.DRONE
            else:
                return CellType.EMPTY

        # In other cases we change the cells
        # If this is a drag operation, we do not change the tool
        if self.press_position != release_pos:
            return self.last_cell_tool
        else:
            if button == Qt.MouseButton.LeftButton:
                # Next tool
                return CellType((self.map["cells"][x][y] + 1) % (len(CellType) - 1))
            elif button == Qt.MouseButton.RightButton:
                # Previous tool
                return CellType((self.map["cells"][x][y] - 1) % (len(CellType) - 1))
            else:
                print("Unrecognized mouse button, using last tool")
                return self.last_cell_tool

    def mousePressEvent(self, event):
        # Capture the press coordinates
        self.press_position = self.map_position_from_pixel(
            event.position().x(), event.position().y())

    def mouseReleaseEvent(self, event):
        release_pos = self.map_position_from_pixel(
            event.position().x(), event.position().y())

        # Determine what to put in the cell
        next_cell_tool = self.choose_tools(
            self.press_position, release_pos, event.button())

        # Update the target area
        if next_cell_tool == CellType.EMPTY:
            # If the tool is EMPTY, we clear out both cells and drones
            self.set_cell_rect(
                next_cell_tool, self.press_position, release_pos)
            self.set_map_drone_rect(
                next_cell_tool, self.press_position, release_pos)

            # In this case we reset the last tool used to FIRE
            self.last_cell_tool = CellType.FIRE
        if next_cell_tool == CellType.DRONE:
            self.set_map_drone_rect(
                next_cell_tool, self.press_position, release_pos)
        else:
            self.set_cell_rect(
                next_cell_tool, self.press_position, release_pos)

            # Update the last cell tool
            self.last_cell_tool = next_cell_tool

        # Redraw the map
        self.draw_map(self.map)
