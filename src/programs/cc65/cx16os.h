
unsigned char __fastcall__ getin();
void __fastcall__ putc(unsigned char ch);
void __fastcall__ print_str(char *str);

unsigned short __fastcall__ parse_num(char *num_str);
unsigned short __fastcall__ hex_num_to_string(unsigned char b);

unsigned char __fastcall__ kill_process(unsigned char pid);

int __fastcall__ wait_process(unsigned char pid);

unsigned char __fastcall__ res_extmem_bank(void);
unsigned char __fastcall__ set_extmem_rbank(unsigned char bank);
unsigned char __fastcall__ set_extmem_wbank(unsigned char bank);

unsigned char __fastcall__ memmove_extmem(void *dest, unsigned char dest_bank, void *src, unsigned char src_bank, size_t count);