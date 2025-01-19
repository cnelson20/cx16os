.include "routines.inc"

.import _bzero

.export __bzero
__bzero := _bzero

.export _getin
_getin := GETIN

.export _chrout
_chrout := CHROUT

.export _print_str
_print_str := print_str

.export _parse_num
_parse_num := parse_num

.export _hex_num_to_string
_hex_num_to_string := hex_num_to_string

.export _res_extmem_bank
_res_extmem_bank := res_extmem_bank

.export _free_extmem_bank
_free_extmem_bank := free_extmem_bank

.export _set_extmem_rbank
_set_extmem_rbank := set_extmem_rbank

.export _set_extmem_wbank
_set_extmem_wbank := set_extmem_wbank

.export _get_general_hook_info
_get_general_hook_info := get_general_hook_info

.export _set_own_priority
_set_own_priority := set_own_priority

.export _surrender_process_time
_surrender_process_time := surrender_process_time

.export _set_stdin_read_mode
_set_stdin_read_mode := set_stdin_read_mode

.export _detach_self
_detach_self := detach_self

.export _get_args
_get_args = get_args

.export _lock_vera_regs
_lock_vera_regs = lock_vera_regs

.export _unlock_vera_regs
_unlock_vera_regs = unlock_vera_regs
