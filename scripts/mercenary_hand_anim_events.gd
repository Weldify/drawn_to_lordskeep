extends Node

# We can wield 2 of the same item in different hands.
# Some logic is based on animation events being called.
# If there weren't 2 separate nodes for this, we wouldn't be able to tell
# which is which!

signal swing_damaging
signal swing_over
