
## cx16os

### Abstract

- Multitasking OS for the Commander X16

 - Linux-esque, terminal-based
 - Trying to take advantage of the X16's features

### Features

- Shell
- Cooperative multitasking
- Redirection

*Note:* cx16os only runs on X16's with 65c816 processors installed. Older versions ran on the 65c02, but the 16-bit features of the 65c816 make both programs and the kernal run at faster speeds. 

### Internals Discussion

The kernal is still largely 8-bit, but certain routines (notably some of the extmem routines) have added functionality when the accumulator and index registers are 16-bit. 16-bit index registers are also used internally to speed up some helper routines (strlen, strcpy, etc.)

## API guides:

[I/O, Processes, Other Routines Table](routines.md)

[extmem routines](extmem.md)

[system hooks](system_hooks.md)

