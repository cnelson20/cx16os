unsigned char __fastcall__ getin();
void __fastcall__ chrout(unsigned char ch);
void __fastcall__ print_str(char *str);

unsigned short __fastcall__ parse_num(char *num_str);
unsigned short __fastcall__ hex_num_to_string(unsigned char b);

unsigned char __fastcall__ kill_process(unsigned char pid);

int __fastcall__ wait_process(unsigned char pid);

unsigned char __fastcall__ res_extmem_bank(void);
unsigned char __fastcall__ free_extmem_bank(unsigned char bank);

unsigned char __fastcall__ set_extmem_rbank(unsigned char bank);
unsigned char __fastcall__ set_extmem_wbank(unsigned char bank);

unsigned char __fastcall__ share_extmem_bank(unsigned char bank, unsigned char pid);

char __fastcall__ read_byte_extmem(char *ptr, unsigned offset);
int __fastcall__ read_word_extmem(char *ptr, unsigned offset);

void __fastcall__ write_byte_extmem(char c, char *ptr, unsigned offset);
void __fastcall__ write_word_extmem(unsigned int i, char *ptr, unsigned offset);

unsigned char __fastcall__ memmove_extmem(unsigned char dest_bank, void *dest, unsigned char src_bank, void *src, size_t count);
void __fastcall__ fill_extmem(unsigned char bank, void *s, size_t count);
