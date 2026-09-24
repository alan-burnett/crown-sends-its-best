class_name Config
extends RefCounted

## Game-wide settings that are neither balance nor content: how the game states
## what the sim knows. One file at the top of the project, so a figure the
## Author sets is set once, and letters, cutscenes and the summary cannot
## disagree about it.


## 🔒 **How many souls one unit of population stands for**, wherever the player
## reads a head count — a letter, a cutscene, the run's summary.
##
## **One, since the sim counts people** (#426, `population.md` §1). It was a
## thousand while the sim counted in thousands and the display did the
## multiplying; the thousand moved into the sim and this stayed as the one place
## a display scale could be set again.
##
## Written out through `Figures.people`, never multiplied at the point of use,
## so there is exactly one place the two scales meet.
const PEOPLE_PER_POPULATION: int = 1
