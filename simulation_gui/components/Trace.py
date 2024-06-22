from PySide6.QtWidgets import QWidget, QPushButton, QHBoxLayout
from PySide6.QtGui import QKeySequence
from PySide6.QtCore import Slot, QJsonArray, Qt

from pyuppaal import set_verifyta_path, UModel
from io import TextIOWrapper
import re

set_verifyta_path('~/opt/uppaal-5.1.0-beta5-linux64/bin/verifyta')


class TraceWidget(QWidget):
    current_step = 0

    def __init__(self, model_file: TextIOWrapper, trace_file: TextIOWrapper, draw_map: Slot):
        super().__init__()
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
        self.maps = [TraceWidget.parse_map(vars)
                     for vars in self.trace.global_variables]

    def parse_map(trace):
        map: dict[str, QJsonArray] = {}
        map["cells"] = [[0 for _ in range(10)] for _ in range(10)]
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

        return map

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
