import sys; sys.path.append("..")
from fireplace import cards
from fireplace.exceptions import GameOver
from fireplace.utils import play_full_game


def test_full_game():
    try:
        game = play_full_game()
    except GameOver:
        print("Game completed normally.")


def main(numgames):
    cards.db.initialize()
    for i in range(int(numgames)):
        test_full_game()

if __name__ == "__main__":
    main(1)
