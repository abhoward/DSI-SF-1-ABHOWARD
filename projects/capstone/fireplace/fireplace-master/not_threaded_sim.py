#!/usr/bin/env python
import sys; sys.path.append("..")
from fireplace import cards
from fireplace.exceptions import GameOver
from fireplace.utils import play_full_game
import threading
from multiprocessing import Queue
import os
from fireplace.http_logger import http_logger, df_logger
import time

# os.system("taskset -p 0xff %d" % os.getpid())

if __name__ == '__main__':
    args = sys.argv
    iters = args[1]

    print("Iterations:", iters)


    for i in range(int(iters)):
        print("Iter:", i)
        cards.db.initialize()
        try:
            game = play_full_game()
        except GameOver:
            print("Game completed normally.")
