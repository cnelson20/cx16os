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

#### Non-bonk programs (`cx16os.lib`)

| Region | Range | Size |
|--------|-------|------|
| Code / data / heap | `$A300` - `$BEFD` | ~7KB |
| cc65 software stack | `$BF00` - `$BFFF` | 256 bytes |

#### Bonk programs (`cx16os_bonk.lib`)

Bonk programs are loaded into a bank that has RAM in both the RAM slot (`$A000`-`$BFFF`) and the ROM slot (`$C000`-`$FFFF`) via the RAM expansion cartridge. This nearly triples the available program space.

| Region | Range | Size |
|--------|-------|------|
| Code / data / heap | `$A300` - `$FDFF` | ~23KB |
| cc65 software stack | `$FE00` - `$FEFF` | 256 bytes |

A bonk program signals its support for this mode by having a two-byte `$EA $EA` header at `$A300`, which the kernel checks when `res_extmem_bank` is called with argument 1 (requesting a bonk-style large bank).

Use bonk when your program needs significant heap space (e.g., buffering lines for `sort`, `diff`, `column`). Programs that only do streaming I/O generally do not need it.

---

## Extmem Banks

Programs can reserve extended memory banks (8KB each) via `res_extmem_bank`. Each bank is owned by the reserving process and freed automatically on exit. See [extmem.md](extmem.md) for the full API.

Extmem is the right choice when data exceeds what fits in the program heap — for example, storing raw file contents while keeping index structures (offset tables, hash arrays) in the bonk heap.
