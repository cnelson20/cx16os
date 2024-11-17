## Display

### Differences from the normal CBM screen editor

- `HOME` moves the cursor back to the start of the line only, not also to the first line of output
- the `PLOT` kernal routine is replaced by `PLOT_X` and `PLOT_Y` control characters. the value passed to `CHROUT` after PLOT_X/Y sets the terminal column or row

