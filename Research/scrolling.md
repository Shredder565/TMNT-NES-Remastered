# How the screen scrolls in a room

Read from the original's code (bank 4, $9851 to $98C1 and $9B6B to $9BE3)
and checked against the emulator frame by frame. The remake's copy is
`Turtle.move_across`.

## The rule

The turtle has a place on the screen (0 to 255 across) and the screen has
a place in the room. Each keeps its own fraction of a pixel.

Every update, with his sideways speed:

- Moving **left**, the screen scrolls if he is left of 96 on the screen
  and the screen is not already at the room's left end.
- Moving **right**, the screen scrolls if he is at 160 or beyond and the
  room goes on to the right.
- Never while a fight holds the screen (RAM $5E not 0).

When the screen scrolls it takes his speed and he stays where he is on
the screen. Otherwise he moves and the screen stays. The scroll is at
most 4 pixels an update. Either way he is then kept between 20 and 236 on
the screen.

So between 96 and 160 he walks freely without the screen moving, and the
band is not the middle of the screen for both directions: walking right he
sits at 160, walking left at 95.

## Two things that show up as fractions of a pixel

- Because the fractions are kept apart, his place in the room moves in
  steps of 2, 2, 2, 3 while the screen scrolls (the screen's fraction
  carries) but 2.25 each time while he moves himself.
- The scroll is only *asked for* at this point; the screen is moved later
  in the frame. The map tests that follow in the same update still use
  the old screen place, so while scrolling they look one step behind
  where he is drawn. This decides, for instance, which update a ceiling
  stops him on.

## Dropped frames

While it scrolls the original sometimes takes three frames over an update
instead of two (seen 33 times in a 1000-frame run through area 3; about
once every 32 pixels scrolled, so most likely the work of loading the
next strip of map). The remake does not copy this.

## Up and down (12 November 2026)

Read from 4:$9906 to $9966 and measured: see "Follow-up" in
`live_play.md`. The screen shows one row of screens at a time and
changes row only at its top (climbing, Up held, his middle less than 11
down) or bottom (his middle 172 or more down), 4 pixels an update. The
remake's copy is `RoomScene._check_row` and `_step_row_change`.
