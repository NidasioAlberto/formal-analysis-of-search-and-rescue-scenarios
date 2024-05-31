#!/usr/bin/python

import pyuppaal
import re
import numpy
import pygame
import sys

# Set Uppaal verifyta path
pyuppaal.set_verifyta_path('~/uppaal-5.0.0-linux64/bin/verifyta')

# Map size
COLS = 10
ROWS = 10

# Size of each cell in pixels
PIXELS_PER_CELL = 100

# Set window size
WIDTH = COLS * PIXELS_PER_CELL
HEIGHT = ROWS * PIXELS_PER_CELL

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

def load_assets(pixels_per_cell):
    global first_responder_image, survivor_image, in_need_image

    # Load best asset size
    if pixels_per_cell <= 50:
        first_responder_image = pygame.image.load('assets/first_responder_50.png')
        survivor_image = pygame.image.load('assets/survivor_50.png')
        in_need_image = pygame.image.load('assets/in_need_50.png')
    else:
        first_responder_image = pygame.image.load('assets/first_responder_100.png')
        survivor_image = pygame.image.load('assets/survivor_100.png')
        in_need_image = pygame.image.load('assets/in_need_100.png')

    # Resize assets to match target size
    first_responder_image = pygame.transform.scale(first_responder_image, (pixels_per_cell, pixels_per_cell))
    survivor_image = pygame.transform.scale(survivor_image, (pixels_per_cell, pixels_per_cell))
    in_need_image = pygame.transform.scale(in_need_image, (pixels_per_cell, pixels_per_cell))

def load_trace():
    umodel = pyuppaal.UModel('../model.xml')
    return umodel.load_xtr_trace('test_trace.xtr')

def parse_map(global_variables):
    map = numpy.zeros((10, 10))

    map_pattern = re.compile(r'map\[(\d)\]\[(\d)\]')

    for var, value in zip(global_variables.variables_name, global_variables.variables_value):
        result = map_pattern.match(var)
        if result:
            (x, y) = result.groups()
            (x, y) = (int(x), int(y))
            map[x][y] = value

    return map

def draw_grid():
    for x in range(1, COLS):
        for y in range(1, ROWS):
            pygame.draw.line(screen, (0, 0, 0), (x * PIXELS_PER_CELL, 0), (x * PIXELS_PER_CELL, HEIGHT - 1))
            pygame.draw.line(screen, (0, 0, 0), (0, y * PIXELS_PER_CELL), (WIDTH - 1, y * PIXELS_PER_CELL))

def draw_map_content(map):
    for x in range(1, COLS):
        for y in range(1, ROWS):
            cell = map[x][y]

            if cell == CELL_FIRE:
                pygame.draw.rect(screen, FIRE_COLOR, (x * PIXELS_PER_CELL + 1, y * PIXELS_PER_CELL + 1, PIXELS_PER_CELL - 1, PIXELS_PER_CELL - 1))
            elif cell == CELL_EXIT:
                pygame.draw.rect(screen, EXIT_COLOR, (x * PIXELS_PER_CELL + 1, y * PIXELS_PER_CELL + 1, PIXELS_PER_CELL - 1, PIXELS_PER_CELL - 1))
            elif cell == CELL_FIRST_RESP:
                screen.blit(first_responder_image, (x * PIXELS_PER_CELL + 1, y * PIXELS_PER_CELL + 1, PIXELS_PER_CELL - 1, PIXELS_PER_CELL - 1))
            elif cell == CELL_SURVIVOR or cell == CELL_ZERO_RESP or cell == CELL_ASSISTED or cell == CELL_ASSISTING:
                screen.blit(survivor_image, (x * PIXELS_PER_CELL + 1, y * PIXELS_PER_CELL + 1, PIXELS_PER_CELL - 1, PIXELS_PER_CELL - 1)) 
            elif cell == CELL_IN_NEED:
                screen.blit(in_need_image, (x * PIXELS_PER_CELL + 1, y * PIXELS_PER_CELL + 1, PIXELS_PER_CELL - 1, PIXELS_PER_CELL - 1))

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
    global screen

    # Create the window
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    load_assets(PIXELS_PER_CELL)

    # Parse the simulation trace and load map values
    trace = load_trace()
    maps = [parse_map(vars) for vars in trace.global_variables]

    # Start after the user press enter
    wait_for_key(pygame.K_s)

    for i in range(len(maps)):
        # Clear map
        screen.fill((255, 255, 255))

        print(f'Drawing step {i}/{len(maps)}')

        # Draw grid and content
        draw_grid()
        draw_map_content(maps[i])
        pygame.display.flip()

        # Wait for user
        wait_for_key(pygame.K_n)

    # Interaction loop
    wait_for_key(pygame.K_q)

# Run visualizer
main()
