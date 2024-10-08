[Back](./)

## neofetch

#### a utility to display system stats

Usage:
```
neofetch
```

Options:
- None

If `~/etc/neofetch.conf` exists, neofetch will use its contents to determine what info and art to display.

Valid commands:
`ascii`: set what ASCII art to display
- Valid options:
  - `default`: use the default ascii art
  - `alt`: use a larger butterfly image
  - `filename`: If neither these options are supplied, neofetch will open the argument to ascii, using it as the ASCII art image.

`info`: print info about different items
- Valid options:
  - `os`
  - `kernal`
  - `programs`
  - `shell`
  - `terminal`
  - `memory` 
  - `cpu`
  - `gpu`
  - `smc`

`blank`: print a blank line

#### ASCII art images

Valid ASCII art files for the `ascii` command consist of one or more lines seperated by carriage return ($D) characters. The length of the first line will be used as a minimum length for all subsequent lines.

