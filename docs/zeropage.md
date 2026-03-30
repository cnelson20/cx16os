# Zero Page Usage for Programs

Programs running under cx16os have access to specific regions of zero page (`$00`-`$FF`) that are saved and restored on context switches. Any zero page locations **not** listed below are shared/kernel-owned and must not be used by programs.

## Saved/Restored Regions

| Region | Address Range | Size | Notes |
|--------|--------------|------|-------|
| ZP Set 1 | `$02` - `$21` | 32 bytes | General-purpose program use |
| ZP Set 2 | `$30` - `$4F` | 32 bytes | General-purpose program use |
| KZE (Kernal/Zero Extended) | `$50` - `$5F` | 16 bytes | Shared with kernel scratch vars (see below) |

**Total: 80 bytes** of per-process zero page.

## KZE Region Detail (`$50` - `$5F`)

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

## Off-Limits Regions

| Region | Address Range | Purpose |
|--------|--------------|---------|
| `$00` - `$01` | `$00` - `$01` | 6502 I/O port |
| KZP (Kernal Zero Page) | `$22` - `$2F` | Kernel scratch variables (not saved per process) |
| `$60` - `$6F` | `$60` - `$6F` | Unused / reserved |
| Kernel state | `$70` - `$7F`+ | `current_program_id`, `atomic_action_st`, etc. |

## Stack

The upper half of the hardware stack (`$0180` - `$01FF`, 128 bytes) is saved and restored per process.
