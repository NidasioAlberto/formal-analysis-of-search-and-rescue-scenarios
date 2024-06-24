#!/usr/bin/python3

import argparse
import sys
from PySide6.QtWidgets import QApplication, QWidget, QVBoxLayout, QPushButton
from PySide6.QtCore import QJsonDocument, Qt
from PySide6.QtGui import QKeySequence

from components.Map import MapWidget, MapEditorWidget
from components.HttpServer import HttpServer
from components.Trace import TraceWidget

parser = argparse.ArgumentParser(description='Optional app description')
parser.add_argument(
    "--mode", choices=["json_visualizer", "live_visualizer", "trace_visualizer", "editor"], default="visualizer")
parser.add_argument("--map_file", type=argparse.FileType("rb"),
                    help="Map file to visualize")
parser.add_argument("--cols", type=int, default=10, help="Number of columns")
parser.add_argument("--rows", type=int, default=10, help="Number of rows")
parser.add_argument("--cell_size", type=int, default=50,
                    help="Size, in pixels, of each cell")
parser.add_argument("--model_file", type=argparse.FileType("r"),
                    default="../model.xml", help="Model file")
parser.add_argument("--trace_file", type=argparse.FileType("r"),
                    default="examples/random_trace.xtr", help="Trace file to visualize")

if __name__ == "__main__":
    args = parser.parse_args()
    app = QApplication([])

    if args.mode == "json_visualizer":
        map = MapWidget(args.cols, args.rows, args.cell_size)
        map.draw_map(QJsonDocument.fromJson(args.map_file.read()).object())
        map.show()
    elif args.mode == "live_visualizer":
        map = MapWidget(args.cols, args.rows, args.cell_size)
        server = HttpServer(map.draw_map)
        server.start()
        map.show()
    elif args.mode == "trace_visualizer":
        map = MapWidget(args.cols, args.rows, args.cell_size)
        trace = TraceWidget(args.cols, args.rows,
                            args.model_file, args.trace_file, map.draw_map)

        layout = QVBoxLayout()
        layout.setSizeConstraint(QVBoxLayout.SizeConstraint.SetFixedSize)
        layout.addWidget(map)
        layout.addWidget(trace)

        window = QWidget()
        window.setLayout(layout)
        window.show()
    elif args.mode == "editor":
        map = MapEditorWidget(args.cols, args.rows, args.cell_size)
        if (args.map_file):
            map.draw_map(QJsonDocument.fromJson(args.map_file.read()).object())
        save_button = QPushButton("Save")
        save_button.clicked.connect(map.save_map)
        save_button.setShortcut(QKeySequence.Save)

        layout = QVBoxLayout()
        layout.setSizeConstraint(QVBoxLayout.SizeConstraint.SetFixedSize)
        layout.addWidget(map)
        layout.addWidget(save_button)

        window = QWidget()
        window.setLayout(layout)
        window.show()

    sys.exit(app.exec())
