#include <stdio.h>
#include <unistd.h>
#include <string.h>

#include "cx16os.h"

//char hello_str[] = "Hello, World!";
char pwd_buff[128];

unsigned char stp_rts[] = {0xDB, 0x60};

unsigned char bank;

char *extmem_ptr = (char *)0xA000;
unsigned short offset;

int main() {
	unsigned char c;
	getcwd(pwd_buff, 128);

	bank = res_extmem_bank();
	memmove_extmem(bank, extmem_ptr, 0, pwd_buff, 128);
	offset = 0;
	set_extmem_rbank(bank);
	while (c = read_byte_extmem(extmem_ptr, offset)) {
		putchar(c);
		++offset;
	}
	putchar('\r');
	return 0;
}
