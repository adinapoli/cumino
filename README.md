Cumino
======

Cumino is the vim way to prepare Haskell recipies:

* See the [website](http://adinapoli.github.com/cumino)
* Read the [Wiki](https://github.com/adinapoli/cumino/wiki/Getting-Started) to get started

# Prerequisites

* Vim with Python support enabled
* Tmux >= 1.5
* (Optional) [stylish-haskell](https://github.com/jaspervdj/stylish-haskell.git)
* A terminal emulator
  * Cumino was tested against *gnome-terminal*, *xterm*, *urxvt* and *mlterm*.

# Features

* Send to ghci your type, function and instances definitions
* Test in insolation snippet of code sending visual selection to ghci
* (Optionally) indent your code with stylish-haskell
* Possibility to set a list of ghci flags inside your .vimrc (e.g, *-XOverloadedString*)
* Test your code **environmentwise**: if an [Hsenv](https://github.com/Paczesiowa/hsenv)
  sandbox environment is activated, Cumino automatically starts
  the ghci associated with that environment.


# Installation

Like any other Pathogen bundle.

# Contribute

Yes, please. You can open an issue or fork fix and pull, like usual.
