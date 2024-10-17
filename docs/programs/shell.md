[Back](./)

## shell

#### the default cx16os shell

Usage:
```
shell [options]
```

Options:
- `-p`: persist after stdin EOF. Useful when redirecting a file to stdin when running shell.
- `c "[command]"`: run `command`, then exit (unless the `-p` flag is provided)

Special commands:
- `cd directory`: Attempt to chdir to `directory`
- `setenv name value`: Set variable `name` to `value`. It can be accessed by `$name` going forward.
- `source filename`: Run each line in `filename` as a series of commands

Special shell variables:
- `$?`: the return value of the last command ran
- `$$`: the pid of the shell process
- `$@`: the pid of the last program put into the background with `&`, if it is still alive
