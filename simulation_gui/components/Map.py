from PySide6.QtWidgets import QLabel
from PySide6.QtGui import QPainter, QPixmap, QColorConstants, QGuiApplication, QMouseEvent
from PySide6.QtCore import QRect, QSize, Qt, Slot, QJsonArray, QJsonDocument, QFile, QIODeviceBase, QDir

from components.Enums import CellType, CellColor
from copy import deepcopy

from os import path


class MapWidget(QLabel):
    assets = {}

    def __init__(self, N_COLS: int, N_ROWS: int, PIXELS_PER_CELL: int = 50):
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
        self.clear()

    def load_assets(self) -> None:
        asset = QPixmap(self.PIXELS_PER_CELL, self.PIXELS_PER_CELL)
        asset.fill(CellColor.FIRE.value)
        self.assets[CellType.FIRE] = asset

        asset = QPixmap(self.PIXELS_PER_CELL, self.PIXELS_PER_CELL)
        asset.fill(CellColor.EXIT.value)
        self.assets[CellType.EXIT] = asset

        asset = QPixmap("assets/first_responder_50.png")
        self.assets[CellType.FIRST_RESP] = asset

        asset = QPixmap("assets/first_responder_50.png")
        painter = QPainter(asset)
        text_rect = QRect(self.PIXELS_PER_CELL * 3/4, self.PIXELS_PER_CELL *
                          2/3, self.PIXELS_PER_CELL * 1/4, self.PIXELS_PER_CELL * 1/3)
        painter.drawText(text_rect, "A")
        painter.end()
        self.assets[CellType.ASSISTING] = asset

        asset = QPixmap("assets/survivor_50.png")
        self.assets[CellType.SURVIVOR] = asset

        asset = QPixmap("assets/survivor_50.png")
        painter = QPainter(asset)
        text_rect = QRect(self.PIXELS_PER_CELL * 3/4, self.PIXELS_PER_CELL *
                          2/3, self.PIXELS_PER_CELL * 1/4, self.PIXELS_PER_CELL * 1/3)
        painter.drawText(text_rect, "Z")
        painter.end()
        self.assets[CellType.ZERO_RESP] = asset

        asset = QPixmap("assets/in_need_50.png")
        self.assets[CellType.IN_NEED] = asset

        asset = QPixmap("assets/in_need_50.png")
        painter = QPainter(asset)
        text_rect = QRect(self.PIXELS_PER_CELL * 3/4, self.PIXELS_PER_CELL *
                          2/3, self.PIXELS_PER_CELL * 1/4, self.PIXELS_PER_CELL * 1/3)
        painter.drawText(text_rect, "A")
        painter.end()
        self.assets[CellType.ASSISTED] = asset

        asset = QPixmap("assets/drone_50.png")
        self.assets[CellType.DRONE] = asset

    def draw_grid(self) -> None:
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

    def clear(self) -> None:
        canvas = QPixmap(self.size())
        canvas.fill(QColorConstants.White)
        self.setPixmap(canvas)
        self.draw_grid()

    def draw_cell(self, cell_type: CellType, x: int, y: int) -> None:
        canvas = self.pixmap()
        painter = QPainter(canvas)

        target_rect = QRect(x * self.PIXELS_PER_CELL + 1, y * self.PIXELS_PER_CELL + 1,
                            self.PIXELS_PER_CELL - 1, self.PIXELS_PER_CELL - 1)
        painter.drawPixmap(target_rect, self.assets[cell_type].copy())

        painter.end()
        self.setPixmap(canvas)

    def draw_cells(self, cells: QJsonArray) -> None:
        for x in range(self.N_COLS):
            for y in range(self.N_ROWS):
                if cells[x][y] != CellType.EMPTY.value:
                    self.draw_cell(CellType(cells[x][y]), x, y)

    def draw_drones(self, drones: QJsonArray) -> None:
        for x in range(self.N_COLS):
            for y in range(self.N_ROWS):
                if drones[x][y]:
                    self.draw_cell(CellType.DRONE, x, y)

    def draw_indexes(self, indexes: QJsonArray) -> None:
        for idx, (x, y) in enumerate(indexes):
            canvas = self.pixmap()
            painter = QPainter(canvas)

            target_rect = QRect(x * self.PIXELS_PER_CELL + 1 + self.PIXELS_PER_CELL * 3/4, y * self.PIXELS_PER_CELL + 1,
                                self.PIXELS_PER_CELL * 1/4, self.PIXELS_PER_CELL * 1/3)
            painter.drawText(target_rect, f"{idx}")

            painter.end()
            self.setPixmap(canvas)

    @Slot()
    def draw_map(self, map: dict[str, QJsonArray]) -> None:
        self.clear()
        self.draw_cells(map["cells"])
        self.draw_drones(map["drones"])

        if map["first_responders"]:
            self.draw_indexes(map["first_responders"])
        if map["survivors"]:
            self.draw_indexes(map["survivors"])


class MapEditorWidget(MapWidget):
    map = {}

    tools = [CellType.FIRE, CellType.EXIT,
             CellType.FIRST_RESP, CellType.SURVIVOR]

    press_position = None
    last_move_position = None
    last_cell_tool = tools[0]
    tool_active = False

    # The ownership of the action is not passed to the widget,
    # so the object must not be destroyed when the constructor ends
    save_action = None

    def __init__(self, N_COLS: int, N_ROWS: int, PIXELS_PER_CELL: int = 50):
        super().__init__(N_COLS, N_ROWS, PIXELS_PER_CELL)

        self.map = {
            "cells": [[0 for _ in range(N_COLS)] for _ in range(N_ROWS)],
            "drones": [[0 for _ in range(N_COLS)] for _ in range(N_ROWS)]
        }

        self.draw_map(self.map)
        self.setMouseTracking(True)

    @Slot()
    def save_map(self) -> None:
        i = 0

        # Find a suitable file name
        while path.exists(f"map_{i}"):
            i += 1

        # Create the directory
        if not QDir(f".").mkdir(f"map_{i}"):
            raise RuntimeError(f"Unable to create directory map_{i}")

        # Dump the map into a a json file
        json_map_file = QFile(f"map_{i}/map.json")
        if json_map_file.open(QIODeviceBase.OpenModeFlag.WriteOnly):
            json = QJsonDocument(self.map)
            json_map_file.write(json.toJson())
        else:
            raise RuntimeError(f"Unable to open map_{i}/map.json")

        # Count numbers and positions of entities
        (drones, drones_pos) = self.count_entity(CellType.DRONE)
        (survivors, survivors_pos) = self.count_entity(CellType.SURVIVOR)
        (first_responders, first_responders_pos) = self.count_entity(
            CellType.FIRST_RESP)

        # Generate the code for constants
        constants_template_file = QFile("templates/constants.txt")
        constants_template_file.open(QIODeviceBase.OpenModeFlag.ReadOnly)
        constants_template = constants_template_file.readAll().toStdString()

        constants_code = constants_template.format(
            self.N_COLS,
            self.N_ROWS,
            drones,
            ", ".join(drones_pos),
            ", ".join(["1" for _ in range(drones)]),
            ", ".join(["2" for _ in range(drones)]),
            survivors,
            ", ".join(survivors_pos),
            ", ".join(["8" for _ in range(survivors)]),
            ", ".join(["15" for _ in range(survivors)]),
            ", ".join(["POLICY_DIRECT" for _ in range(survivors)]),
            first_responders,
            ", ".join(first_responders_pos),
            ", ".join(["5" for _ in range(first_responders)]),
            ", ".join(["POLICY_DIRECT" for _ in range(first_responders)])
        )

        constants_code_file = QFile(f"map_{i}/constants.txt")
        if constants_code_file.open(QIODeviceBase.OpenModeFlag.WriteOnly):
            constants_code_file.write(constants_code.encode())
        else:
            raise RuntimeError(f"Unable to open map_{i}/constants.txt")

        # Generate the code for the map
        map_template_file = QFile("templates/map.txt")
        map_template_file.open(QIODeviceBase.OpenModeFlag.ReadOnly)
        map_template = map_template_file.readAll().toStdString()

        map_code = ""
        for x in range(self.N_COLS):
            for y in range(self.N_ROWS):
                if self.map["cells"][x][y] != CellType.EMPTY.value:
                    value = self.map["cells"][x][y]
                    map_code += map_template.format(
                        x, y, value, CellType(self.map["cells"][x][y]).name)

        map_code_file = QFile(f"map_{i}/map.txt")
        if map_code_file.open(QIODeviceBase.OpenModeFlag.WriteOnly):
            map_code_file.write(map_code.encode())
        else:
            raise RuntimeError(f"Unable to open map_{i}/map.txt")

        print(f"Current map seved in map_{i}/")

    def count_entity(self, entity: CellType) -> tuple[int, list[str]]:
        if entity == CellType.DRONE:
            map = self.map["drones"]
            value = 1
        else:
            map = self.map["cells"]
            value = entity.value

        count = 0
        positions = []
        for x in range(self.N_COLS):
            for y in range(self.N_ROWS):
                if map[x][y] == value:
                    count += 1
                    positions.append(f"{{{x}, {y}}}")

        return (count, positions)

    def set_cell(map, cell_type, pos) -> None:
        map["cells"][pos[0]][pos[1]] = cell_type.value

    def set_cell_rect(map, cell_type, pos1, pos2) -> None:
        (x1, y1) = pos1
        (x2, y2) = pos2

        for x in range(x1, x2 + 1):
            for y in range(y1, y2 + 1):
                MapEditorWidget.set_cell(map, cell_type, (x, y))

    def set_drone(map, cell_type, pos) -> None:
        if cell_type == CellType.EMPTY:
            map["drones"][pos[0]][pos[1]] = 0
        elif cell_type == CellType.DRONE:
            map["drones"][pos[0]][pos[1]] = 1

    def set_map_drone_rect(map, cell_type, pos1, pos2) -> None:
        (x1, y1) = pos1
        (x2, y2) = pos2

        for x in range(x1, x2 + 1):
            for y in range(y1, y2 + 1):
                MapEditorWidget.set_drone(map, cell_type, (x, y))

    def map_position_from_pixel(self, pos: tuple[int, int]) -> tuple[int, int]:
        x = int(pos.x() // self.PIXELS_PER_CELL)
        y = int(pos.y() // self.PIXELS_PER_CELL)

        # Clamp values
        if x < 0:
            x = 0
        elif x >= self.N_COLS:
            x = self.N_COLS - 1
        if y < 0:
            y = 0
        elif y >= self.N_ROWS:
            y = self.N_ROWS - 1

        return (x, y)

    def choose_next_tool(self, press_pos: tuple[int, int], release_pos: tuple[int, int], button: Qt.MouseButton) -> CellType:
        # Use the press position as source
        (x, y) = press_pos

        # In all cases, if the middle button is pressed we clear everything
        if button == Qt.MouseButton.MiddleButton or Qt.MouseButton.MiddleButton in QGuiApplication.mouseButtons():
            return CellType.EMPTY

        # If shift is pressed, draw drones
        if QGuiApplication.keyboardModifiers() == Qt.KeyboardModifier.ShiftModifier:
            if self.map["drones"][x][y] == CellType.EMPTY.value:
                return CellType.DRONE
            else:
                return CellType.EMPTY

        # In other cases we change the cells
        # If this is a drag operation, we do not change the tool
        if self.press_position != release_pos or CellType(self.map["cells"][x][y]) not in self.tools:
            return self.last_cell_tool
        else:
            idx = self.tools.index(CellType(self.map["cells"][x][y]))
            if button == Qt.MouseButton.LeftButton:
                # Next tool
                return self.tools[(idx + 1) % len(self.tools)]
            elif button == Qt.MouseButton.RightButton:
                # Previous tool
                return self.tools[(idx - 1) % len(self.tools)]
            else:
                return self.last_cell_tool

    def mousePressEvent(self, event: QMouseEvent) -> None:
        self.press_position = self.map_position_from_pixel(event.position())
        self.tool_active = True

    def mouseReleaseEvent(self, event: QMouseEvent) -> None:
        release_pos = self.map_position_from_pixel(event.position())
        (top_left, bottom_right) = self.fix_positions_order(
            self.press_position, release_pos)
        self.tool_active = False

        # Determine what to put in the cells
        next_cell_tool = self.choose_next_tool(
            self.press_position, release_pos, event.button())

        # Update the target area
        if next_cell_tool == CellType.EMPTY:
            # If the tool is EMPTY, we clear out both cells and drones
            MapEditorWidget.set_cell_rect(self.map, next_cell_tool,
                                          top_left, bottom_right)
            MapEditorWidget.set_map_drone_rect(self.map, next_cell_tool,
                                               top_left, bottom_right)

            # In this case we reset the last tool used to FIRE
            self.last_cell_tool = self.tools[0]
        elif next_cell_tool == CellType.DRONE:
            MapEditorWidget.set_map_drone_rect(self.map, CellType.DRONE,
                                               top_left, bottom_right)
        else:
            MapEditorWidget.set_cell_rect(self.map, next_cell_tool,
                                          top_left, bottom_right)

            # Update the last cell tool
            self.last_cell_tool = next_cell_tool

        # Redraw the map
        self.draw_map(self.map)

    def mouseMoveEvent(self, event: QMouseEvent) -> None:
        current_pos = self.map_position_from_pixel(event.position())

        if self.press_position != None and self.tool_active:
            (top_left, bottom_right) = self.fix_positions_order(
                self.press_position, current_pos)

            map_copy = deepcopy(self.map)

            # Determine what to put in the cells
            next_cell_tool = self.choose_next_tool(
                self.press_position, current_pos, event.button())

            # Update the target area
            if next_cell_tool == CellType.EMPTY:
                # If the tool is EMPTY, we clear out both cells and drones
                MapEditorWidget.set_cell_rect(
                    map_copy, next_cell_tool, top_left, bottom_right)
                MapEditorWidget.set_map_drone_rect(
                    map_copy, next_cell_tool, top_left, bottom_right)

                # In this case we reset the last tool used to FIRE
                self.last_cell_tool = self.tools[0]
            elif next_cell_tool == CellType.DRONE:
                MapEditorWidget.set_map_drone_rect(
                    map_copy, CellType.DRONE, top_left, bottom_right)
            else:
                MapEditorWidget.set_cell_rect(
                    map_copy, next_cell_tool, top_left, bottom_right)

                # Update the last cell tool
                self.last_cell_tool = next_cell_tool

            # Redraw the map
            self.draw_map(map_copy)

    # Fixes the positions in order to have the press_pos alwayb be on the top left and release_pos on the bottom right
    def fix_positions_order(self, press_pos: tuple[int, int], release_pos: tuple[int, int]):
        (x1, y1) = press_pos
        (x2, y2) = release_pos
        return ((min(x1, x2), min(y1, y2)), (max(x1, x2), max(y1, y2)))
