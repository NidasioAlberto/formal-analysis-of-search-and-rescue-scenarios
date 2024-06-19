#!/usr/bin/python3

import argparse
import json
import sys
from PySide6.QtWidgets import QApplication

from components.Map import MapWidget, MapEditorWidget

parser = argparse.ArgumentParser(description='Optional app description')
parser.add_argument(
    "--mode", choices=["visualizer", "editor"], default="visualizer")
parser.add_argument("--map_file", type=argparse.FileType("r"),
                    default="examples/simple_map.json", help="Map file to visualize")
parser.add_argument("--cols", type=int, default=10, help="Number of columns")
parser.add_argument("--rows", type=int, default=10, help="Number of rows")
parser.add_argument("--cell_size", type=int, default=50,
                    help="Size, in pixels, of each cell")

if __name__ == "__main__":
    args = parser.parse_args()
    app = QApplication([])

    if args.mode == "visualizer":
        map = MapWidget(args.cols, args.rows, args.cell_size)
        map.clear()
        map.draw_map(json.load(args.map_file))
    elif args.mode == "editor":
        map = MapEditorWidget(args.cols, args.rows, args.cell_size)
        map.clear()

    map.show()

    sys.exit(app.exec())
