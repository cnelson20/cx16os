[Back to main page](/docs/)

## cx16os programs documentation

The following programs each have their own documentation page:

- [asm](asm.md) - a 6502 assembler

- [sendmsg](sendmsg.md) - sends messages through the 8 general hooks to other programs

- [swapterm](swapterm.md) - switch between up to 4 terminal windows

- [neofetch](neofetch.md) - display system info

<br />

The following programs are mostly similar in function to the POSIX utilities, with more detail listed under each program:
- basename
  - no options

- cat
  - does not read from stdin if no arguments are given
  - no options

- clear
  - no options

- cp
  - no options
  - the target filename must be specifed fully, i.e. `cp filename dir/` does not work, `cp filename dir/filename` is required instead

- cron
  - no options
  - instead of looking for crontab files, cron uses its arguments as files to read from

- date
  - no options

- dirname
  - no options

- echo
  - no options (they are echo'd to stdout)

- ed
  - no options (first argument is a file to open)
  - no regex support
  - no `j` command to join lines 

- kill
  - no options

- ls
  - only options are `-a` and `-b` (disable color)

- mkdir
  - no options

- mv
  - no options

- ps
  - no options

- pwd
  - no options

- rm
  - no options

- rmdir
  - no options

- strings
  - does not read from stdin if no file arguments are provided
  - only options are `-f`, `-t`, `-n`, and `-h`

- xxd
  - does not read from stdin if no file arguments are provided
  - no options
