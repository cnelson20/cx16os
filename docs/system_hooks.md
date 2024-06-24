## System Hooks

### Rationale

The purpose of the various system hooks is to provide access to key system aspects that should not be shared between processes, and to enable inter-process communication.

The chrout hook is a special hook that intercepts all putc/CHROUT calls that would be written to the terminal and sends them to a buffer where another program can process it and perform an action.
It is setup / released with different calls than the general hooks, and can be sent data by [`send_byte_chrout_hook`](#send_byte_chrout_hook)

The VERA hook is a way for a process to gain exclusive access to VERA registers. the address and addrsel registers will be preserved when context-switching.

---

#### buffer information pointers:

- 4 bytes
- First 2 bytes (start_offset) are an offset into the ringbuffer where the first characters to work with are
- Last 2 bytes (end_offset) are an offset into the ringbuffer where the last character is at (offset - 1)

---

## Functions

### setup_chrout_hook
Call Address: $9D75  
Arguments:

- .A holds 0 for the program bank or an extmem bank to hold the ringbuffer ($1000 bytes)
- r0 holds a pointer where to write the ringbuffer
- r1 holds a pointer in a program's RAM where to write info about the ringbuffer

Returns size of buffer in .AX, 0 on failure (hook already in use)

---

### release_chrout_hook
Call Address: $9D78  
Arguments:

- None

Releases the calling program's hook on CHROUT calls, if it has one  
Returns 0 on success, non-zero on failure in .A

---

### setup_general_hook
Call Address: $9D7B  
Arguments:

- .A holds the hook # to setup
- .X holds the bank to hold the hook's data ringbuffer
- r0 holds the address of the same data ringbuffer
- r1 holds the address where to hold the hook's buffer information in the calling process' bank (see [above](#buffer-information-pointers)

Sets up general hook # .A based on the provided arguments  
Returns size of buffer in .AX, 0 on failure (hook already in use)

---

### release_general_hook
Call Address: $9D7E  
Arguments:

- .A holds the hook # to release

Releases the calling process' lock on hook # .A, if it has one  
Returns 0 on success, non-zero on failure in .A

---

### get_general_hook_info
Call Address: $9D81  
Arguments:

- .A holds the hook # to get information about

Returns whether a hook is active, and what process has a lock on it  
.A contains the pid of the process with the lock, or 0 if no process has one

---

### send_message_general_hook
Call Address: $9D84  
Arguments:

- .X holds the hook # to send a message to
- .A holds the message length
- r0 holds a pointer to the message
- r1.L holds the bank of the message (0 means the message is in the caller's own bank)

Returns 0 on success, non-zero on failure in .A

---

### send_byte_chrout_hook
Call Address: $9D87  
Arguments:

- .A holds the byte to send

Preserves .A, returns 0 on success, non-zero on failure in .X

---

### mark_last_hook_message_received
Call Address: $9D90  
Arguments:

- .A holds the bank number to affect

If the calling process has a lock on hook .A, increment that hook's start_offset to point to the next message  
Returns 0 on success, non-zero on failure in .A

--- 

### lock_vera_regs
Call Address: $9D93
Arguments:

- None

If there is no existing lock on VERA registers, the calling process gets the hook to VERA's register set. The OS will preserve VERA's address registers when context switching.
Returns 0 on success, non-zero on failure to obtain the hook in .A

---

### unlock_vera_regs
Call Address: $9D96
Arguments:

- None

Releases the calling process' hook on VERA, if it has the hook
Returns 0 on success (if the process had the hook), non-zero on failure in .A


