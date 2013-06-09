Cumino
======

Cumino is the vim way to prepare Haskell recipies:

* See the [website](http://adinapoli.github.com/cumino)
* Read the [Wiki](https://github.com/adinapoli/cumino/wiki/Getting-Started) to get started

# Prerequisites

* Vim with Python support enabled
* Tmux >= 1.5
* A terminal emulator
  * Cumino was tested against *gnome-terminal*, *xterm*, *urxvt* and *mlterm*.

# Features

* Send to ghci your type, function and instances definitions
* Type your function invokation in Vim an watch them be evaluated in Ghci
* Test in insolation snippet of code sending visual selection to ghci
* Show the type of the function under the cursor
* Possibility to set a list of ghci flags inside your .vimrc (e.g, *-XOverloadedString*)
* Test your code **environmentwise**: if an [Hsenv](https://github.com/Paczesiowa/hsenv)
  sandbox environment is activated, Cumino automatically starts
  the ghci associated with that environment.


# Installation

Like any other Pathogen bundle.

# Customise
In case some other plugin is using the same shortcuts Cumino uses, it's easy to
bind Cumino functions to arbitrary keystrokes. The default keystrokes are
defined at the end of the Cumino
[source code](https://github.com/adinapoli/cumino/blob/master/ftplugin/haskell.vim#L260).
Suppose you want to override the connect function, is as simple as:

```
map MyKeyBindingHere :call CuminoConnect()<RETURN>
```

Put this inside your ``.vimrc`` and you are in business.

# Contribute

Yes, please. You can open an issue or fork fix and pull, like usual.
