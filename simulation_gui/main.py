#!/usr/bin/python3

import argparse
import sys
from PySide6.QtWidgets import QApplication
from PySide6.QtCore import QJsonDocument

from components.Map import MapWidget, MapEditorWidget
from components.HttpServer import HttpServer

parser = argparse.ArgumentParser(description='Optional app description')
parser.add_argument(
    "--mode", choices=["file_visualizer", "live_visualizer", "editor"], default="visualizer")
parser.add_argument("--map_file", type=argparse.FileType("rb"),
                    default="examples/simple_map.json", help="Map file to visualize")
parser.add_argument("--cols", type=int, default=10, help="Number of columns")
parser.add_argument("--rows", type=int, default=10, help="Number of rows")
parser.add_argument("--cell_size", type=int, default=50,
                    help="Size, in pixels, of each cell")

if __name__ == "__main__":
    args = parser.parse_args()
    app = QApplication([])

    if args.mode == "file_visualizer":
        map = MapWidget(args.cols, args.rows, args.cell_size)
        map.clear()
        map.draw_map(QJsonDocument.fromJson(args.map_file.read()).object())
    if args.mode == "live_visualizer":
        map = MapWidget(args.cols, args.rows, args.cell_size)
        map.clear()
        server = HttpServer(map.draw_map)
        server.start()
    elif args.mode == "editor":
        map = MapEditorWidget(args.cols, args.rows, args.cell_size)
        map.clear()

    map.show()

    sys.exit(app.exec())
