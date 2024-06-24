from PySide6.QtWidgets import QWidget, QPushButton, QHBoxLayout
from PySide6.QtGui import QKeySequence
from PySide6.QtCore import Slot, QJsonArray, Qt

from components.Enums import CellType
from pyuppaal import set_verifyta_path, UModel
from io import TextIOWrapper
import re

set_verifyta_path('~/opt/uppaal-5.1.0-beta5-linux64/bin/verifyta')


class TraceWidget(QWidget):
    current_step = 0

    def __init__(self, N_COLS: int, N_ROWS: int, model_file: TextIOWrapper, trace_file: TextIOWrapper, draw_map: Slot):
        super().__init__()

        # Initialize variables
        self.N_COLS = N_COLS
        self.N_ROWS = N_ROWS
        self.draw_map = draw_map

        self.prev_button = QPushButton("Previous")
        self.prev_button.clicked.connect(self.show_previous_step)
        self.prev_button.setShortcut(Qt.Key.Key_Left)
        self.next_button = QPushButton("Next")
        self.next_button.clicked.connect(self.show_next_step)
        self.next_button.setShortcut(Qt.Key.Key_Right)

        layout = QHBoxLayout()
        layout.addWidget(self.prev_button)
        layout.addWidget(self.next_button)
        self.setLayout(layout)

        umodel = UModel(model_file.name)
        self.trace = umodel.load_xtr_trace(trace_file.name)
        self.maps = [self.parse_map(vars)
                     for vars in self.trace.global_variables]

    def parse_map(self, trace):
        map: dict[str, QJsonArray] = {}
        map["cells"] = [[0 for _ in range(self.N_ROWS)]
                        for _ in range(self.N_COLS)]
        map["drones"] = [[0 for _ in range(10)] for _ in range(10)]

        cell_pattern = re.compile(r'map\[(\d)\]\[(\d)\]')
        drone_pattern = re.compile(r'drone_map\[(\d)\]\[(\d)\]')

        for var, value in zip(trace.variables_name, trace.variables_value):
            cell_result = cell_pattern.match(var)
            if cell_result:
                (x, y) = cell_result.groups()
                (x, y) = (int(x), int(y))
                map["cells"][x][y] = int(value)
            drone_result = drone_pattern.match(var)
            if drone_result:
                (x, y) = drone_result.groups()
                (x, y) = (int(x), int(y))
                map["drones"][x][y] = int(value)

        first_responders = TraceWidget.count_entity(
            map["cells"], CellType.FIRST_RESP)
        survivors = TraceWidget.count_entity(map["cells"], CellType.SURVIVOR)

        first_resp_pos = []
        map["first_responders"] = [(0, 0) for _ in range(first_responders)]
        for i in range(first_responders):
            pattern_x = re.compile(r'FirstResponder\({}\).pos.x'.format(i))
            pattern_y = re.compile(r'FirstResponder\({}\).pos.y'.format(i))

            for var, value in zip(trace.variables_name, trace.variables_value):
                x_result = pattern_x.match(var)
                if x_result:
                    x = int(value)
                y_result = pattern_y.match(var)
                if y_result:
                    y = int(value)

            map["first_responders"][i] = (x, y)

        survivors_pos = []
        map["survivors"] = [(0, 0) for _ in range(survivors)]
        for i in range(survivors):
            pattern_x = re.compile(r'Survivor\({}\).pos.x'.format(i))
            pattern_y = re.compile(r'Survivor\({}\).pos.y'.format(i))

            for var, value in zip(trace.variables_name, trace.variables_value):
                x_result = pattern_x.match(var)
                if x_result:
                    x = int(value)
                y_result = pattern_y.match(var)
                if y_result:
                    y = int(value)

            map["survivors"][i] = (x, y)

        return map

    def count_entity(map: QJsonArray, entity: CellType) -> int:
        count = 0
        for row in map:
            for cell in row:
                if ((entity == CellType.FIRST_RESP and (cell == CellType.FIRST_RESP.value or cell == CellType.ASSISTING.value)) or
                        (entity == CellType.SURVIVOR and (cell == CellType.SURVIVOR.value or cell ==
                         CellType.IN_NEED.value or cell == CellType.ASSISTED.value))
                        or cell == entity.value):
                    count += 1
        return count

    @Slot()
    def show_previous_step(self):
        if self.current_step > 0:
            self.current_step -= 1
            self.draw_map(self.maps[self.current_step])

    @Slot()
    def show_next_step(self):
        if self.current_step < len(self.maps) - 1:
            self.current_step += 1
            self.draw_map(self.maps[self.current_step])
