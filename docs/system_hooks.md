## System Hooks

chrout: Writes all chrout calls into a ringbuffer.

#### setup_chrout_hook

Arguments:

- .A holds 0 for the program bank or an extmem bank to hold the ringbuffer ($1000 bytes)
- r0 holds a pointer where to write the ringbuffer
- r1 holds a pointer in a program's RAM where to write info about the ringbuffer

buffer information:

- 4 bytes
- First 2 bytes are an offset into the ringbuffer where the first characters to work with are
- Last 2 bytes are an offset into the ringbuffer where the last character is at (offset - 1)


