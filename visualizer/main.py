#!/usr/bin/python

import pyuppaal
import re
import numpy
import pygame
import sys
import shutil

# Set Uppaal verifyta path
pyuppaal.set_verifyta_path('~/uppaal-5.0.0-linux64/bin/verifyta')

MODEL_FILE_NAME = 'model.xml'
MODEL_PATH = '../' + MODEL_FILE_NAME

TRACE_PATH = 'test_trace.xtr'

ASSETS_PATH = 'assets'

# Map size
N_COLS = 0
N_ROWS = 0

# Size of each cell in pixels
PIXELS_PER_CELL = 100

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

FIRE_COLOR = pygame.Color(255, 139, 131)
EXIT_COLOR = pygame.Color(204, 251, 115)

pygame.font.init()
my_font = pygame.font.SysFont('monospace', int(PIXELS_PER_CELL / 3))

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

def load_trace():
    # For some reason pyuppaal modifies the model file, so we just copy it locally

    shutil.copy(MODEL_PATH, 'model.xml')
    umodel = pyuppaal.UModel('model.xml')
    return umodel.load_xtr_trace(TRACE_PATH)

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
    for x in range(1, N_COLS):
        for y in range(1, N_ROWS):
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

def draw_drones(positions):
    for position in positions:
        screen.blit(drone_image, (position[0] * PIXELS_PER_CELL + 1, position[1] * PIXELS_PER_CELL + 1, PIXELS_PER_CELL - 1, PIXELS_PER_CELL - 1))

def wait_for_key(key):
    print(f'Waiting for {pygame.key.name(key)}')
    while True:
        for event in pygame.event.get():
            if event.type == pygame.KEYDOWN and event.key == key:
                print('Key pressed')
                return
            elif event.type == pygame.QUIT:
                sys.exit(0)

def main():
    global screen, N_COLS, N_ROWS

    # Parse the simulation trace and load map values
    trace = load_trace()
    (N_COLS, N_ROWS) = parse_map_size()
    maps = [parse_map_state(vars) for vars in trace.global_variables]
    drone_positions = [parse_drone_positions(vars) for vars in trace.global_variables]

    # Create the window
    screen = pygame.display.set_mode((N_COLS * PIXELS_PER_CELL, N_ROWS * PIXELS_PER_CELL))
    load_assets(PIXELS_PER_CELL)

    # Start after the user press enter
    wait_for_key(pygame.K_s)

    for i in range(len(maps)):
        # Clear map
        screen.fill((255, 255, 255))

        print(f'Drawing step {i}/{len(maps)}')

        print(maps[i].transpose())

        # Draw grid and content
        draw_grid()
        draw_map_content(maps[i])
        draw_drones(drone_positions[i])
        pygame.display.flip()

        # Wait for user
        wait_for_key(pygame.K_n)

    # Interaction loop
    wait_for_key(pygame.K_q)

# Run visualizer
main()
