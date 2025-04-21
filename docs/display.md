## Display

some things you may want to consider when programming for cx16os

#### Differences from a unix system

- `\r`, not `\n`, is used for newlines

#### Differences from the normal CBM screen editor

- `HOME` moves the cursor back to the start of the line only, not also to the first line of output
- the `PLOT` kernal routine is replaced by `PLOT_X` ($0B) and `PLOT_Y` ($0C) control characters. the value passed to `CHROUT` after PLOT_X/Y sets the terminal column or row

