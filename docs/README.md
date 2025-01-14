
## cx16os

### Synopsis

- Multitasking OS for the Commander X16

 - terminal-based
 - Aiming to recreate *nix userland features
 - Trying to take advantage of the X16's features

### Features

- Shell
- Preemptive multitasking
- Redirection

*Note:* cx16os only runs on X16's with 65c816 processors installed. Older versions ran on the 65c02, but the 16-bit features of the 65c816 make both programs and the kernal run at faster speeds. 

### [Programs documentation](programs/)

### [Build/Install Guide](install_guide.md)

### [Internals Writeup](internals.md)

## Guides:

[I/O, Processes, Other Routines Table](routines.md)

[extmem routines](extmem.md)

[system hooks](system_hooks.md)

[display](display.md)
