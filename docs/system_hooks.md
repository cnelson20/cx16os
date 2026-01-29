## System Hooks

### Rationale

The purpose of the various system hooks is to provide access to key system aspects that should not be shared between processes, and to enable inter-process communication.

### Special hooks 

The chrout hook is a special hook that intercepts all putc/CHROUT calls that would be written to the terminal and sends them to a buffer where another program can process it and perform an action.
It is setup / released with different calls than the general hooks, and can be sent data by [`send_byte_chrout_hook`](#send_byte_chrout_hook)

The VERA hook is a way for a process to gain exclusive access to VERA registers. the address and addrsel registers will be preserved when context-switching. It has no associated buffer.

### General hooks

The general hooks are FIFO buffers used for program-defined communications

### hook ringbuffers
- $1000 bytes, either or process memory or extmem

### buffer information pointers:

Buffer information pointers hold 4 bytes of information about a hook's FIFO ringbuffer:

| Bytes 0-1 | Bytes 2-3 |
|-|-|
| start_offset | end_offset |

- First 2 bytes (start_offset) is the offset of the first character that is part of a message not yet indicated as received
- Last 2 bytes (end_offset) is the offset of the first non-message byte in the ringbuffer (the last byte of a message is at offset - 1)

### CHROUT hook message format

###

| Byte 0 | Byte 1 |
|---------|---------------|
| char printed | printer PID |

### general hook message format

###

| Byte 0 | Byte 1 | Bytes 2-255 |
|---------|--------|-------|
| sender pid | message body length | message body |

---

## Function Reference

### setup_chrout_hook
Call Address: $9D75  

Sets up chrout hook for calling process

Arguments:

- .A holds 0 for the program bank or an extmem bank to hold the ringbuffer ($1000 bytes)
- r0 holds a pointer where to write the ringbuffer
- r1 holds a pointer in a program's RAM where to write info about the ringbuffer

Return values:
- .AX = size of buffer, 0 on failure (hook already in use)

---

### release_chrout_hook
Call Address: $9D78  

Releases the calling program's hook on CHROUT calls, if it has one  

Arguments:
- None

Return values:
- 0 on success to release the hook in .A
- On failure to release the hook, returns the pid of the process with the chrout hook (non-zero) in .A. If the hook is not being used, returns $FF.

---

### setup_general_hook
Call Address: $9D7B  

Sets up general hook # .A based on the provided arguments  

Arguments:

- .A holds the hook # to setup
- .X holds the bank to hold the hook's data ringbuffer
- r0 holds the address of the same data ringbuffer
- r1 holds the address where to hold the hook's buffer information in the calling process' bank (see [above](#buffer-information-pointers))

Return values:
- .AX = size of buffer, 0 on failure (hook already in use)

---

### release_general_hook
Call Address: $9D7E  

Releases the calling process' lock on hook # .A, if it has one

Arguments:
- .A holds the hook # to release

Return values:
- .A = 0 on success, non-zero on failure

---

### get_general_hook_info
Call Address: $9D81  

Retrieve info on whether a hook is active, and what process has a lock on it  

Arguments:
- .A holds the hook # to get information about

Return values:
- .A = the pid of the process with the lock, or 0 if no process has one

---

### send_message_general_hook
Call Address: $9D84  

Sends a message through one of the general hooks

Arguments:
- .X holds the hook # to send a message to
- .A holds the message length
- r0 holds a pointer to the message
- r1.L holds the bank of the message (0 means the message is in the caller's own bank)

Return values:
- .A = 0 on success, non-zero on failure

---

### send_byte_chrout_hook
Call Address: $9D87  

Send a byte directly to the chrout hook. Fails if hook is not in use.

Arguments:
- .A holds the byte to send

Return values:
- .A is preserved
- .X = 0 on success, non-zero on failure

---

### mark_last_hook_message_received
Call Address: $9D90  

If the calling process has a lock on hook .A, increment that hook's start_offset to point to the next message

Arguments:
- .A holds the bank number to affect

Return values:  
- .A = 0 on success, non-zero on failure

--- 

### lock_vera_regs
Call Address: $9D93

If there is no existing lock on VERA registers, the calling process gets the trust-based lock on VERA's register set. The OS will preserve VERA's address registers when context switching.

Arguments:
- None

Return values:
- .A = 0 on success, non-zero on failure

---

### unlock_vera_regs
Call Address: $9D96

Releases the calling process' lock on VERA, if it has the lock

Arguments:
- None

Return values:
- .A = 0 on success (if the process had the lock), non-zero on failure


