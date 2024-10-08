[Back](./)

## swapterm

#### switch between up to 4 terminal windows

Usage:
```
swapterm &
```
(swapterm is recommended to be started in the background)

When swapterm starts, all alive processes are put in terminal 0.

Programs can switch terminals by sending a command through hook 1 in the format `pid terminal`, where `pid` and `terminal` are each one byte each.

To change the terminal of the shell you are using, you could use `sendmsg -h 1 -c $$ -c [termino]`.

Limitations:
- PLOT_X and PLOT_Y control characters are not supported
