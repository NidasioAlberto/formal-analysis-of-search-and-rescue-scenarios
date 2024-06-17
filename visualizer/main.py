#!/usr/bin/python

import re
import numpy
import pygame
import sys, os
import shutil
import threading
import queue
import pygame_menu

MODEL_FILE_NAME = 'model.xml'
MODEL_PATH = '../' + MODEL_FILE_NAME

TRACE_PATH = 'test_trace.xtr'

EDITOR_STATE_PATH = 'editor_state.dat'

ASSETS_PATH = 'assets'

# Map size
N_COLS = 10
N_ROWS = 10

# Size of each cell in pixels
PIXELS_PER_CELL = 50

# Map cell status enumeration
CELL_FIRST = 0

CELL_EMPTY =      CELL_FIRST + 0
CELL_FIRE =       CELL_FIRST + 1
CELL_EXIT =       CELL_FIRST + 2
CELL_FIRST_RESP = CELL_FIRST + 3
CELL_SURVIVOR =   CELL_FIRST + 4
CELL_ZERO_RESP =  CELL_FIRST + 5
CELL_IN_NEED =    CELL_FIRST + 6
CELL_ASSISTED =   CELL_FIRST + 7 # Survivor in need busy being assisted
CELL_ASSISTING =  CELL_FIRST + 8 # First responder busy assisting

CELL_MAP = {
    CELL_EMPTY: "CELL_EMPTY",
    CELL_FIRE: "CELL_FIRE",
    CELL_EXIT: "CELL_EXIT",
    CELL_FIRST_RESP: "CELL_FIRST_RESP",
    CELL_SURVIVOR: "CELL_SURVIVOR",
    CELL_ZERO_RESP: "CELL_ZERO_RESP",
    CELL_IN_NEED: "CELL_IN_NEED",
    CELL_ASSISTED: "CELL_ASSISTED",
    CELL_ASSISTING: "CELL_ASSISTING"
}

FIRE_COLOR = pygame.Color(255, 139, 131)
EXIT_COLOR = pygame.Color(204, 251, 115)

pygame.font.init()
my_font = pygame.font.SysFont('monospace', int(PIXELS_PER_CELL / 3))

state_queue = queue.Queue()

def load_assets(pixels_per_cell):
    global first_responder_image, survivor_image, in_need_image, drone_image

    # Load best asset size
    if pixels_per_cell <= 50:
        first_responder_image = pygame.image.load(ASSETS_PATH + '/first_responder_50.png')
        survivor_image = pygame.image.load(ASSETS_PATH + '/survivor_50.png')
        in_need_image = pygame.image.load(ASSETS_PATH + '/in_need_50.png')
        drone_image = pygame.image.load(ASSETS_PATH + '/drone_50.png')
    else:
        first_responder_image = pygame.image.load(ASSETS_PATH + '/first_responder_100.png')
        survivor_image = pygame.image.load(ASSETS_PATH + '/survivor_100.png')
        in_need_image = pygame.image.load(ASSETS_PATH + '/in_need_100.png')
        drone_image = pygame.image.load(ASSETS_PATH + '/drone_100.png')

    # Resize assets to match target size
    first_responder_image = pygame.transform.scale(first_responder_image, (pixels_per_cell, pixels_per_cell))
    survivor_image = pygame.transform.scale(survivor_image, (pixels_per_cell, pixels_per_cell))
    in_need_image = pygame.transform.scale(in_need_image, (pixels_per_cell, pixels_per_cell))
    drone_image = pygame.transform.scale(drone_image, (pixels_per_cell, pixels_per_cell))

def parse_map_size():
    cols = 0
    rows = 0

    cols_pattern = re.compile(r'N_COLS = (\d+)')
    rows_pattern = re.compile(r'N_ROWS = (\d+)')

    model_text_lines = open(MODEL_PATH, 'r').readlines()

    for line in model_text_lines:
        cols_match = cols_pattern.search(line)
        rows_match = rows_pattern.search(line)

        if cols_match:
            cols = int(cols_match.groups()[0])
        if rows_match:
            rows = int(rows_match.groups()[0])

        if cols and rows:
            break

    return (cols, rows)

def parse_map_state(global_variables):
    map = numpy.zeros((10, 10))

    map_pattern = re.compile(r'map\[(\d+)\]\[(\d+)\]')

    for name, value in zip(global_variables.variables_name, global_variables.variables_value):
        result = map_pattern.match(name)
        if result:
            (x, y) = result.groups()
            (x, y) = (int(x), int(y))
            map[x][y] = value

    return map

def parse_drone_positions(global_variables):
    x_pattern = re.compile(r'drone_(\d+)\.x$')
    y_pattern = re.compile(r'drone_(\d+)\.y$')

    # First count the number of drones
    drones_count = len([1 for name in global_variables.variables_name if x_pattern.match(name)])

    # Initialize positions
    positions = [(0, 0) for i in range(drones_count)]

    for name, value in zip(global_variables.variables_name, global_variables.variables_value):
        # Parse x coordinate
        x_match = x_pattern.match(name)
        if x_match:
            # Assuming drone ids start from 1
            drone_id = int(x_match.groups()[0]) - 1
            if positions[drone_id]:
                positions[drone_id] = (int(value), positions[drone_id][1])
            else:
                positions[drone_id] = (int(value), 0)

        # Parse y coordinate
        y_match = y_pattern.match(name)
        if y_match:
            # Assuming drone ids start from 1
            drone_id = int(y_match.groups()[0]) - 1
            if positions[drone_id]:
                positions[drone_id] = (positions[drone_id][0], int(value))
            else:
                positions[drone_id] = (0, int(value))

    return positions

def draw_grid():
    for x in range(0, N_COLS+1):
        for y in range(0, N_ROWS+1):
            pygame.draw.line(screen, (0, 0, 0), (x * PIXELS_PER_CELL, 0), (x * PIXELS_PER_CELL, N_ROWS * PIXELS_PER_CELL - 1))
            pygame.draw.line(screen, (0, 0, 0), (0, y * PIXELS_PER_CELL), (N_COLS * PIXELS_PER_CELL - 1, y * PIXELS_PER_CELL))

def draw_map_content(map):
    for x in range(N_COLS):
        for y in range(N_ROWS):
            cell = map[x][y]

            if cell == CELL_FIRE:
                pygame.draw.rect(screen, FIRE_COLOR, (x * PIXELS_PER_CELL + 1, y * PIXELS_PER_CELL + 1, PIXELS_PER_CELL - 1, PIXELS_PER_CELL - 1))
            elif cell == CELL_EXIT:
                pygame.draw.rect(screen, EXIT_COLOR, (x * PIXELS_PER_CELL + 1, y * PIXELS_PER_CELL + 1, PIXELS_PER_CELL - 1, PIXELS_PER_CELL - 1))
            elif cell == CELL_FIRST_RESP:
                screen.blit(first_responder_image, (x * PIXELS_PER_CELL + 1, y * PIXELS_PER_CELL + 1, PIXELS_PER_CELL - 1, PIXELS_PER_CELL - 1))
            elif cell == CELL_SURVIVOR:
                screen.blit(survivor_image, (x * PIXELS_PER_CELL + 1, y * PIXELS_PER_CELL + 1, PIXELS_PER_CELL - 1, PIXELS_PER_CELL - 1))
            elif cell == CELL_ZERO_RESP:
                screen.blit(survivor_image, (x * PIXELS_PER_CELL + 1, y * PIXELS_PER_CELL + 1, PIXELS_PER_CELL - 1, PIXELS_PER_CELL - 1))
                state = my_font.render('Z', False, (0, 0, 0))
                screen.blit(state, (x * PIXELS_PER_CELL + 1 + PIXELS_PER_CELL * 2/3, y * PIXELS_PER_CELL + 1 + PIXELS_PER_CELL * 2/3))
            elif cell == CELL_IN_NEED:
                screen.blit(in_need_image, (x * PIXELS_PER_CELL + 1, y * PIXELS_PER_CELL + 1, PIXELS_PER_CELL - 1, PIXELS_PER_CELL - 1))
            elif cell == CELL_ASSISTED:
                screen.blit(in_need_image, (x * PIXELS_PER_CELL + 1, y * PIXELS_PER_CELL + 1, PIXELS_PER_CELL - 1, PIXELS_PER_CELL - 1))
                state = my_font.render('A', False, (0, 0, 0))
                screen.blit(state, (x * PIXELS_PER_CELL + 1 + PIXELS_PER_CELL * 2/3, y * PIXELS_PER_CELL + 1 + PIXELS_PER_CELL * 2/3))
            elif cell == CELL_ASSISTING:
                screen.blit(first_responder_image, (x * PIXELS_PER_CELL + 1, y * PIXELS_PER_CELL + 1, PIXELS_PER_CELL - 1, PIXELS_PER_CELL - 1))
                state = my_font.render('A', False, (0, 0, 0))
                screen.blit(state, (x * PIXELS_PER_CELL + 1 + PIXELS_PER_CELL * 2/3, y * PIXELS_PER_CELL + 1 + PIXELS_PER_CELL * 2/3))

def draw_drones(map):
    for x in range(N_COLS):
        for y in range(N_ROWS):
            if map[x][y]:
                screen.blit(drone_image, (x * PIXELS_PER_CELL + 1, y * PIXELS_PER_CELL + 1, PIXELS_PER_CELL - 1, PIXELS_PER_CELL - 1))

def draw_state(state):
    # Clear map
    screen.fill((255, 255, 255))

    # Draw grid and content
    draw_grid()

    if state != None:
        draw_map_content(state['map'])
        draw_drones(state['drone_map'])

    # Commit
    pygame.display.flip()

def save_state(state):
    # save state to file for later reloading
    with open(EDITOR_STATE_PATH, 'w') as f:
        f.write(f"{N_COLS} {N_ROWS}\n")
        for x in range(N_COLS):
            for y in range(N_ROWS):
                f.write(f"{int(state["map"][x][y])} ")
            f.write("\n")
    
def load_state():
    global N_COLS, N_ROWS

    # load state from file
    with open(EDITOR_STATE_PATH, 'r') as f:
        N_COLS, N_ROWS = [int(x) for x in f.readline().split()]
        map = numpy.zeros((N_COLS, N_ROWS))
        for x in range(N_COLS):
            map[x] = [int(x) for x in f.readline().split()]

    state = {}
    state["map"] = map
    state["drone_map"] = numpy.zeros((N_COLS, N_ROWS))
    return state

def print_editor_state(map):
    print(f"\n=> Map size: {N_COLS}x{N_ROWS}")

    print("=> Survivors:")
    count = 0
    pos_list = ""
    tzr_list = ""
    tv_list = ""
    policy_list = ""

    for x in range(N_COLS):
        for y in range(N_ROWS):
            if map[x][y] == CELL_SURVIVOR or map[x][y] == CELL_IN_NEED:
                count += 1
                pos_list += f"{{{x}, {y}}}, "
                tzr_list += "8, "
                tv_list += "15, "
                policy_list += "POLICY_DIRECT, "

    print(f"""\
const int N_SURVIVORS = {count};
typedef int[0, N_SURVIVORS-1] survivor_id_t;
const pos_t survivors_starting_pos[N_SURVIVORS] = {{{pos_list[:-2]}}};
const int T_zr[N_SURVIVORS] = {{{tzr_list[:-2]}}};
const int T_v[N_SURVIVORS] = {{{tv_list[:-2]}}};
const policy_t survivors_policies[N_SURVIVORS] = {{{policy_list[:-2]}}};""")

    print("=> First responders:")
    count = 0
    pos_list = ""
    tfr_list = ""
    policy_list = ""

    for x in range(N_COLS):
        for y in range(N_ROWS):
            if map[x][y] == CELL_FIRST_RESP:
                count += 1
                pos_list += f"{{{x}, {y}}}, "
                tfr_list += "5, "
                policy_list += "POLICY_DIRECT, "

    print(f"""\
const int N_FIRST_RESPONDERS = {count};
typedef int[0, N_FIRST_RESPONDERS-1] first_resp_id_t;
const pos_t first_responders_starting_pos[N_FIRST_RESPONDERS] = {{{pos_list[:-2]}}};
const int T_fr[N_FIRST_RESPONDERS] = {{{tfr_list[:-2]}}};
const policy_t first_resp_policies[N_FIRST_RESPONDERS] = {{{policy_list[:-2]}}};""")

    print("=> Map: ")
    for x in range(N_COLS):
        for y in range(N_ROWS):
            if map[x][y] == CELL_FIRE or map[x][y] == CELL_EXIT:
                print(f"map[{x}][{y}] = {CELL_MAP[map[x][y]]}")

def run_gui():
    global screen, N_COLS, N_ROWS

    # Parse the simulation trace and load map values
    (N_COLS, N_ROWS) = parse_map_size()

    # Create the window
    screen = pygame.display.set_mode((N_COLS * PIXELS_PER_CELL + 1, N_ROWS * PIXELS_PER_CELL + 1))
    load_assets(PIXELS_PER_CELL)
    draw_state(None)

    while True:
        for event in pygame.event.get():
            if event.type == pygame.KEYDOWN and event.key == pygame.K_SPACE:
                pygame.image.save(screen, "screenshot.jpg")
                print("Screenshot saved")
            elif event.type == pygame.QUIT:
                pygame.quit()
                os._exit(0)
        
        while state_queue.qsize() > 0:
            state = state_queue.get()
            draw_state(state)

        pygame.time.wait(100)

def launch_visualizer():
    from flask import Flask
    from flask import request

    def state():
        global screen, N_COLS, N_ROWS
        state_queue.put(request.get_json())
        return "Ok"

    app = Flask(__name__)
    app.add_url_rule('/state', 'state', state, methods=['POST']) 

    # Run Flask server in separate thread
    threading.Thread(target=lambda: app.run(debug=False, use_reloader=False)).start()

    # Start GUI
    run_gui()

def launch_last_editor():
    try:
        state = load_state()
    except:
        print("Failed to load last editor state, starting new session")
        launch_new_editor()
        return
    
    launch_editor(state)

def launch_new_editor():
    global N_COLS, N_ROWS

    N_COLS = int(map_cols.get_value())
    N_ROWS = int(map_rows.get_value())

    state = {}
    state["map"] = numpy.zeros((N_COLS, N_ROWS))
    state["drone_map"] = numpy.zeros((N_COLS, N_ROWS))

    launch_editor(state)

def launch_editor(state):
    global screen, N_COLS, N_ROWS
    
    screen = pygame.display.set_mode((N_COLS * PIXELS_PER_CELL + 1, N_ROWS * PIXELS_PER_CELL + 1))
    load_assets(PIXELS_PER_CELL)

    changed = False
    while True:
        for event in pygame.event.get():
            if event.type == pygame.KEYDOWN and event.key == pygame.K_SPACE:
                pygame.image.save(screen, "screenshot.jpg")
                print("Screenshot saved")
            elif event.type == pygame.MOUSEBUTTONDOWN:
                x, y = pygame.mouse.get_pos()
                x = x // PIXELS_PER_CELL
                y = y // PIXELS_PER_CELL

                if event.button == 1: # left click
                    state["map"][x][y] = (state["map"][x][y] + 1) % (CELL_ASSISTING + 1)
                elif event.button == 2: # middle click
                    state["map"][x][y] = 0
                elif event.button == 3: # right click
                    state["map"][x][y] = (state["map"][x][y] - 1) % (CELL_ASSISTING + 1)
                
                changed = True
            elif event.type == pygame.KEYDOWN and event.key == pygame.K_RETURN:
                print_editor_state(state["map"])
            elif event.type == pygame.QUIT:
                print_editor_state(state["map"])
                pygame.quit()
                os._exit(0)

        draw_state(state)
        if changed:
            changed = False
            save_state(state)

        pygame.time.wait(100)

pygame.init()

# Show the initial menu
surface = pygame.display.set_mode((1280, 720))
menu = pygame_menu.Menu("Welcome", 1280, 720, theme=pygame_menu.themes.THEME_BLUE)

editor_menu = pygame_menu.Menu('Editor Settings', 1280, 720, onclose=pygame_menu.events.BACK)

map_rows = editor_menu.add.range_slider('Map Rows', default=10, range_values=(1, 100), increment=1, 
                                        value_format=lambda x: str(int(x)))
map_cols = editor_menu.add.range_slider('Map Cols', default=10, range_values=(1, 100), increment=1,
                                        value_format=lambda x: str(int(x)))
editor_menu.add.button("New", launch_new_editor)
if os.path.exists(EDITOR_STATE_PATH):
    editor_menu.add.button("Resume Last Session", launch_last_editor)

menu.add.button("Visualizer", launch_visualizer)
menu.add.button("Editor", editor_menu)

menu.mainloop(surface)
