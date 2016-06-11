import random
import os.path
import numpy as np
from bisect import bisect
from importlib import import_module
from pkgutil import iter_modules
from typing import List
from xml.etree import ElementTree
from hearthstone.enums import CardClass, CardType
from .logging import log
from .sql_logger import sql_logger, df_logger

# Autogenerate the list of cardset modules
_cards_module = os.path.join(os.path.dirname(__file__), "cards")
CARD_SETS = [cs for _, cs, ispkg in iter_modules([_cards_module]) if ispkg]

card_mana = []
spells = []
minions = []
weapons = []

class CardList(list):
	def __contains__(self, x):
		for item in self:
			if x is item:
				return True
		return False

	def __getitem__(self, key):
		ret = super().__getitem__(key)
		if isinstance(key, slice):
			return self.__class__(ret)
		return ret

	def __int__(self):
		# Used in Kettle to easily serialize CardList to json
		return len(self)

	def contains(self, x):
		"True if list contains any instance of x"
		for item in self:
			if x == item:
				return True
		return False

	def index(self, x):
		for i, item in enumerate(self):
			if x is item:
				return i
		raise ValueError

	def remove(self, x):
		for i, item in enumerate(self):
			if x is item:
				del self[i]
				return
		raise ValueError

	def exclude(self, *args, **kwargs):
		if args:
			return self.__class__(e for e in self for arg in args if e is not arg)
		else:
			return self.__class__(e for k, v in kwargs.items() for e in self if getattr(e, k) != v)

	def filter(self, **kwargs):
		return self.__class__(e for k, v in kwargs.items() for e in self if getattr(e, k, 0) == v)


def random_draft(card_class: CardClass, exclude=[]):
	"""
	Return a deck of 30 random cards for the \a card_class
	"""
	from . import cards
	from .deck import Deck

	deck = []
	collection = []
	hero = card_class.default_hero

	for card in cards.db.keys():
		if card in exclude:
			continue
		cls = cards.db[card]
		if not cls.collectible:
			continue
		if cls.type == CardType.HERO:
			# Heroes are collectible...
			continue
		if cls.card_class and cls.card_class != card_class:
			continue
		collection.append(cls)

	while len(deck) < Deck.MAX_CARDS:
		card = random.choice(collection)
		if deck.count(card.id) < card.max_count_in_deck:
			deck.append(card.id)
			card_mana.append(card.cost)
			if card.type == CardType.SPELL:
				spells.append(card.id)
			elif card.type == CardType.MINION:
				minions.append(card.id)
			elif card.type == CardType.WEAPON:
				weapons.append(card.id)

	return deck

def random_class():
	return CardClass(random.randint(2, 10))


def get_script_definition(id):
	"""
	Find and return the script definition for card \a id
	"""
	for cardset in CARD_SETS:
		module = import_module("fireplace.cards.%s" % (cardset))
		if hasattr(module, id):
			return getattr(module, id)


def entity_to_xml(entity):
	e = ElementTree.Element("Entity")
	for tag, value in entity.tags.items():
		if value and not isinstance(value, str):
			te = ElementTree.Element("Tag")
			te.attrib["enumID"] = str(int(tag))
			te.attrib["value"] = str(int(value))
			e.append(te)
	return e


def game_state_to_xml(game):
	tree = ElementTree.Element("HSGameState")
	tree.append(entity_to_xml(game))
	for player in game.players:
		tree.append(entity_to_xml(player))
	for entity in game:
		if entity.type in (CardType.GAME, CardType.PLAYER):
			# Serialized those above
			continue
		e = entity_to_xml(entity)
		e.attrib["CardID"] = entity.id
		tree.append(e)

	return ElementTree.tostring(tree)


def weighted_card_choice(source, weights: List[int], card_sets: List[str], count: int):
	"""
	Take a list of weights and a list of card pools and produce
	a random weighted sample without replacement.
	len(weights) == len(card_sets) (one weight per card set)
	"""

	chosen_cards = []

	# sum all the weights
	cum_weights = []
	totalweight = 0
	for i, w in enumerate(weights):
		totalweight += w * len(card_sets[i])
		cum_weights.append(totalweight)

	# for each card
	for i in range(count):
		# choose a set according to weighting
		chosen_set = bisect(cum_weights, random.random() * totalweight)

		# choose a random card from that set
		chosen_card_index = random.randint(0, len(card_sets[chosen_set]) - 1)

		chosen_cards.append(card_sets[chosen_set].pop(chosen_card_index))
		totalweight -= weights[chosen_set]
		cum_weights[chosen_set:] = [x - weights[chosen_set] for x in cum_weights[chosen_set:]]

	return [source.controller.card(card, source=source) for card in chosen_cards]


def setup_game() -> ".game.Game":
	from .game import Game
	from .player import Player

	random_num1 = random.randint(2, 10)
	random_num2 = random.randint(2, 10)

	deck1 = random_draft(CardClass(random_num1))
	df_logger.log_event("deck", str(deck1), "player1")
	df_logger.log_event("deck_cost", str(np.mean(card_mana)), "player1")
	df_logger.log_event("num_minions", str(len(minions)), "player1")
	df_logger.log_event("num_spells", str(len(spells)), "player1")
	df_logger.log_event("num_weapons", str(len(weapons)), "player1")
	del card_mana[:] # Resetting list of cards' mana cost
	del minions[:] # Resetting list of minions
	del spells[:] # Resetting list of spells
	del weapons[:] # Resetting list of weapons
	deck2 = random_draft(CardClass(random_num2))
	df_logger.log_event("deck", str(deck2), "player2")
	df_logger.log_event("deck_cost", str(np.mean(card_mana)), "player2")
	df_logger.log_event("num_minions", str(len(minions)), "player2")
	df_logger.log_event("num_spells", str(len(spells)), "player2")
	df_logger.log_event("num_weapons", str(len(weapons)), "player2")
	del card_mana[:] # Resetting list of cards' mana cost
	del minions[:] # Resetting list of minions
	del spells[:] # Resetting list of spells
	del weapons[:] # Resetting list of weapons
	player1 = Player("Player1", deck1, CardClass(random_num1).default_hero)
	player2 = Player("Player2", deck2, CardClass(random_num2).default_hero)
	df_logger.log_event("player1_class", str(CardClass(random_num1)), "player1")
	df_logger.log_event("player2_class", str(CardClass(random_num2)), "player2")

	game = Game(players=(player1, player2))
	game.start()

	return game


def play_turn(game: ".game.Game") -> ".game.Game":
	player = game.current_player
	cards_cost = []
	while True:
		heropower = player.hero.power
		# alec: changed random factor from 0.1 to 0.3
		if heropower.is_usable() and random.random() < 0.3:
			if heropower.has_target():
				heropower.use(target=random.choice(heropower.targets))
			else:
				heropower.use()
			continue

		# iterate over our hand and play whatever is playable
		# alec: made simulation play a card (if it's playable) no matter what,
		# instead of having a random factor in as well.
		for card in player.hand:
			cards_cost.append(card.cost)
			if card.is_playable():
				target = None
				if card.must_choose_one:
					card = random.choice(card.choose_cards)
				if card.has_target():
					target = random.choice(card.targets)
				print("Playing %r on %r" % (card, target))
				log.info("Playing %r on %r" % (card, target))
				card.play(target=target)

				if player.choice:
					choice = random.choice(player.choice.cards)
					print("Choosing card %r" % (choice))
					log.info("Choosing card %r" % (choice))
					player.choice.choose(choice)

				continue
		df_logger.log_event("avg_hand_cost", str(np.mean(cards_cost)), str(player.name))
		# Randomly attack with whatever can attack
		for character in player.characters:
			if character.can_attack():
				character.attack(random.choice(character.targets))

		break
	game.end_turn()
	return game


def play_full_game() -> ".game.Game":
	game = setup_game()

	for player in game.players:
		print("Can mulligan %r" % (player.choice.cards))
		log.info("Can mulligan %r" % (player.choice.cards))
		mull_count = random.randint(0, len(player.choice.cards))
		cards_to_mulligan = random.sample(player.choice.cards.id, mull_count)
		cards_to_keep = [x for x in list(player.choice.cards.id) if x not in cards_to_mulligan]
		player.choice.choose(*cards_to_mulligan)
		df_logger.log_event("cards_mulliganed", str(cards_to_mulligan), str(player))
		df_logger.log_event("cards_kept", str(cards_to_keep), str(player))

	while True:
		play_turn(game)

	return game
