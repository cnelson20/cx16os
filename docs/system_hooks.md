## System Hooks

The chrout hook is a special hook that intercepts all putc/CHROUT calls that would be written to the terminal and sends them to a buffer where another program can process it and perform an action.
It is setup / released with different calls than the general hooks, and can be sent data by [`send_byte_chrout_hook`](#send_byte_chrout_hook)

---

### setup_chrout_hook
Call Address: $9D75  
Arguments:

- .A holds 0 for the program bank or an extmem bank to hold the ringbuffer ($1000 bytes)
- r0 holds a pointer where to write the ringbuffer
- r1 holds a pointer in a program's RAM where to write info about the ringbuffer

Returns size of buffer in .AX, 0 on failure (hook already in use)

#### buffer information pointers:

- 4 bytes
- First 2 bytes are an offset into the ringbuffer where the first characters to work with are
- Last 2 bytes are an offset into the ringbuffer where the last character is at (offset - 1)

---

### release_chrout_hook
Call Address: $9D78  
Arguments:

- None

Releases the calling program's hook on CHROUT calls, if it has one
Returns 0 on success, non-zero on failure

---

### setup_general_hook
Call Address: $9D7B  
Arguments:

- .A holds the hook # to setup
- .X holds the bank to hold the hook's data ringbuffer
- r0 holds the address of the same data ringbuffer
- r1 holds the address where to hold the hook's buffer information in the calling process' bank (see [above](#buffer-information-pointers)

---

### release_general_hook

---

### get_general_hook_info

---

### send_message_general_hook

---

### send_byte_chrout_hook
