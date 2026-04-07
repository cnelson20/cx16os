# Program Considerations

## Zero Page Usage

Programs running under cx16os have access to specific regions of zero page (`$00`-`$FF`) that are saved and restored on context switches. Any zero page locations **not** listed below are shared/kernel-owned and must not be used by programs.

### Saved/Restored Regions

| Region | Address Range | Size | Notes |
|--------|--------------|------|-------|
| ZP Set 1 | `$02` - `$21` | 32 bytes | General-purpose program use |
| ZP Set 2 | `$30` - `$4F` | 32 bytes | General-purpose program use |
| KZE (Kernal/Zero Extended) | `$50` - `$5F` | 16 bytes | Shared with kernel scratch vars (see below) |

**Total: 80 bytes** of per-process zero page.

### KZE Region Detail (`$50` - `$5F`)

These are saved/restored per process but are also used as kernel-entry scratch space (e.g., during syscalls). Programs can use them freely between syscalls, but values may be clobbered by kernel calls.

| Label | Address | Size |
|-------|---------|------|
| `KZE0` | `$50` | 2 bytes |
| `KZE1` | `$52` | 2 bytes |
| `KZE2` | `$54` | 2 bytes |
| `KZE3` | `$56` | 2 bytes |
| `KZES4` | `$58` | 2 bytes |
| `KZES5` | `$5A` | 2 bytes |
| `KZES6` | `$5C` | 2 bytes |
| `KZES7` | `$5E` | 2 bytes |

### Off-Limits Regions

| Region | Address Range | Purpose |
|--------|--------------|---------|
| `$00` - `$01` | `$00` - `$01` | 6502 I/O port |
| KZP (Kernal Zero Page) | `$22` - `$2F` | Kernel scratch variables (not saved per process) |
| `$60` - `$6F` | `$60` - `$6F` | Unused / reserved |
| Kernel state | `$70` - `$7F`+ | `current_program_id`, `atomic_action_st`, etc. |

---

## Program Memory Layout

Each process runs in its own banked RAM (`$A000`-`$BFFF`, 8KB). The lower portion of this bank is reserved by the OS for saved process state; program code and heap begin at `$A300`.

### OS-Reserved Area (`$A000`-`$A2FF`)

This area is managed entirely by the kernel and must not be written to by programs. It holds:

| What | Location |
|------|----------|
| Saved registers (A, X, Y, status) | `$A000`-`$A009` |
| Saved ZP Set 1 | `$A010`-`$A02F` |
| Saved ZP Set 2 | `$A030`-`$A04F` |
| Saved KZE region | `$A050`-`$A05F` |
| Saved RAM/ROM bank | `$A060`-`$A061` |
| Saved extmem r/w banks and pointers | `$A062`-`$A067` |
| Saved hardware stack (`$0180`-`$01FF`) | `$A070`-`$A16F` |
| stdin/stdout config, args, I/O scratch | `$A17E`-`$A2FF` |

The hardware stack (`$0180`-`$01FF`, 128 bytes) is saved and restored here on every context switch, so programs do not need to account for it in their own memory layout.

### Program Area (`$A300` onward)

Program code, read-only data, BSS, and heap all occupy this region. The top of the region is reserved for the cc65 software stack (used for C function call frames).

#### Non-bonk C programs (`cx16os.lib`)

| Region | Range | Size |
|--------|-------|------|
| Code / data / heap | `$A300` - `$BEFD` | ~7KB |
| cc65 software stack | `$BF00` - `$BFFF` | 256 bytes |

#### Bonk C programs (`cx16os_bonk.lib`)

Bonk programs are loaded into a bank that has RAM in both the RAM slot (`$A000`-`$BFFF`) and the ROM slot (`$C000`-`$FFFF`) via the RAM expansion cartridge. This nearly triples the available program space.

| Region | Range | Size |
|--------|-------|------|
| Code / data / heap | `$A300` - `$FDFF` | ~23KB |
| cc65 software stack | `$FE00` - `$FEFF` | 256 bytes |

A bonk program signals its support for this mode by having a two-byte `$EA $EA` header at `$A300`, which the kernel checks when `res_extmem_bank` is called with argument 1 (requesting a bonk-style large bank).

---

## CPU Mode

cx16os runs the 65C816 in **native mode** throughout — not emulation mode. Programs inherit this state.

- Accumulator and index registers start in **8-bit mode** (M=1, X=1).
- Several extmem routines (`readf_byte_extmem_y`, `writef_byte_extmem_y`, `vread_byte_extmem_y`, `pread_extmem_xy`, `pwrite_extmem_xy`) operate correctly in either 8-bit or 16-bit mode. Using 16-bit index registers (`REP #$10`) is **strongly recommended** with `pread_extmem_xy` and `pwrite_extmem_xy`; 8-bit X/Y will likely produce wrong addresses or crash.
- **Never use `TXS` in 8-bit with .X=1.** It will zero the high byte of the stack pointer, pointing the stack into page 0 and almost certainly crashing the OS. The hardware stack lives at `$0100`–`$01FF` and the high byte must stay `$01`.

---

## Program Entry and Exit

### Assembly

- There is no set assembler entry point, but most existing programs use the label `main:`. Execution begins there with A, X, Y, and the stack in a defined state (see Calling Conventions below).
- Exit by executing `RTS` with the return code in `.A`. Return code `0` conventionally means success; non-zero is an error.
- The program bank is still mapped when `main` returns; the OS reclaims it after `rts`.

```asm
main:
    ; ... do work ...
    lda #0      ; exit code 0 = success
    rts
```
OR...
```asm
exit: ; pass exit code through .A
    tax
    lda #>$01FD
	xba
	lda #<$01FD
	tcs
    txa
	rts
```

### C (cc65)

- Entry is the standard `int main(int argc, char *argv[])`. The cc65 runtime populates `argc` and `argv` before calling `main`.
- Return an `int` from `main`, or call `exit(code)`. The value is forwarded to the OS as the process exit code.
- Standard `printf`, `scanf`, `open`/`read`/`write`/`close`, and most of the C89 standard library are available.

---

## Calling Conventions (Assembly)

System routines live at fixed addresses in the `$9D00`–`$9DCF` range (see [routines.md](routines.md) for the complete table).

### Register roles

| Register | Typical role |
|----------|-------------|
| `.A` | Low byte of a pointer or small integer argument; also the primary return register |
| `.X` | High byte of a pointer (paired with `.A` for 16-bit addresses) |
| `.Y` | Secondary argument (e.g., `argc`, flags, fd) |
| `r0`–`r5` (`$02`–`$0D`) | Additional arguments and return values too wide for registers |

A 16-bit pointer is always passed **low byte in `.A`, high byte in `.X`** (`jsr print_str` with `.AX = address`, for example).

The pseudo-registers `r0`–`r5` are simply zero-page word pairs:

```
r0 := $02   r1 := $04   r2 := $06
r3 := $08   r4 := $0A   r5 := $0C
```

These are defined in `routines.inc` and fall within ZP Set 1 (`$02`–`$21`), so they are saved/restored across context switches.

### Register preservation

Each routine's documentation lists which registers it **tramples** (clobbers). As a rule of thumb:

- `putc / CHROUT` preserves `.A`, `.X`, `.Y`.
- Most routines trample at least `.Y`; many trample `r0`–`r2`.
- Save anything you care about before a syscall if it is listed as trampled.

---

## Program Arguments

### Assembly

Call `get_args` with no arguments:

```asm
jsr get_args
; .AX = pointer to argument block (null-separated strings)
; .Y  = argc (includes the program name as argv[0])
```

The argument block is a contiguous sequence of null-terminated strings. The first string is the program name; subsequent strings are the arguments.

### C

`argc` and `argv` are set up by the cc65 runtime before `main` is called — no extra work required.

---

## Standard I/O

Programs start with three implicit file descriptors:

| fd | Meaning |
|----|---------|
| 0 | stdin — keyboard by default, can be redirected via pipe |
| 1 | stdout — terminal by default, can be redirected via pipe |
| 2 | stderr — terminal by default, typically not redirected by pipe |

`getc` / `GETIN` reads from fd 0. `putc` / `CHROUT` writes to fd 1.

### Keyboard input modes

By default `getc` is **line-buffered**: it blocks until the user presses Enter, then returns characters one at a time. Call `set_stdin_read_mode` with a non-zero value to switch to **raw mode**, where `getc` returns immediately with `0` if no key is pending. Restore line-buffered mode by passing `0`.

### Cursor positioning via CHROUT

`putc` intercepts two control bytes that the stock X16 CHROUT does not:

| Byte sent | Effect |
|-----------|--------|
| `$0B` (`PLOT_X`) | The **next** byte sent sets the cursor's X (column) position |
| `$0C` (`PLOT_Y`) | The **next** byte sent sets the cursor's Y (row) position |

These must be sent as a pair — the control byte immediately followed by the coordinate byte. They are defined in `routines.inc` as `PLOT_X` and `PLOT_Y`.

---

## Concurrency and Scheduling

cx16os runs multiple processes cooperatively/preemptively via a jiffy-based scheduler. Each process gets a slice of time determined by its priority (default 10 jiffies). A few routines help programs interact with the scheduler:

- **`surrender_process_time`** — voluntarily yields the rest of the current time slice. Use this in tight polling loops to avoid starving other processes. Preserves all registers.
- **`set_own_priority`** — adjusts how many jiffies the calling process receives per scheduling round. Pass `0` to restore the default (10). Useful for background daemons (low priority) or time-sensitive programs (high priority).
- **`wait_process`** — blocks until a specific process exits, automatically lowering the caller's priority while waiting.

The hardware stack, zero page, and all saved register state are preserved across context switches; you do not need to do anything special to be preemption-safe as long as you stay within your own memory regions.

---

## Extmem Banks

Programs can reserve extended memory banks (8KB each) via `res_extmem_bank`. Each bank is owned by the reserving process and freed automatically on exit. See [extmem.md](extmem.md) for the full API.

Extmem is the right choice when data exceeds what fits in the program heap — for example, storing raw file contents while keeping index structures (offset tables, hash arrays) in the bonk heap.
