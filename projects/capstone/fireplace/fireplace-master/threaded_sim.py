#!/usr/bin/env python
import sys; sys.path.append("..")
from fireplace import cards
from fireplace.exceptions import GameOver
from fireplace.utils import play_full_game
import threading
from multiprocessing import Queue
import os

os.system("taskset -p 0xff %d" % os.getpid())

def test_full_game():
    try:
        game = play_full_game()
    except GameOver:
        print("Game completed normally.")

def main(numgames):
    cards.db.initialize()
    for i in range(int(numgames)):
        test_full_game()

def run_sim(numgames):
    cards.db.initialize()
    for i in range(int(numgames)):
        test_full_game()


def worker():
    """thread worker function"""
    print('Spawning worker...')
    run_sim(2)
    return

threads = []
for i in range(40):
    t = threading.Thread(target=worker)
    threads.append(t)
    t.start()

# if __name__ == "__main__":
#     main(1)
