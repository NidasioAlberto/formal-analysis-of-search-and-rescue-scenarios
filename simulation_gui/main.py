#!/usr/bin/python3

import argparse
import json
import sys
from PySide6.QtWidgets import QApplication

from components.Map import MapWidget, MapEditorWidget

parser = argparse.ArgumentParser(description='Optional app description')
parser.add_argument("mode", choices=["visualizer", "editor"], default="editor")
parser.add_argument("--map_file", type=argparse.FileType("r"),
                    default="examples/simple_map.json", help="Map file to visualize")


if __name__ == "__main__":
    args = parser.parse_args()
    app = QApplication([])

    if args.mode == "visualizer":
        map = MapWidget(10, 10)
        map.clear()
        map.draw_map(json.load(args.map_file))
    elif args.mode == "editor":
        map = MapEditorWidget(10, 10)
        map.clear()

    map.show()

    sys.exit(app.exec())
