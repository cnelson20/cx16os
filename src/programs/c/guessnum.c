#include <stdio.h>
#include <stdlib.h>

char buffer[128];

#define GET_TIME 0x9D9F
#define R2H (unsigned char *)0x07
#define R3L (unsigned char *)0x08

int main() {
    __asm__ ("jsr %w", GET_TIME);
    srand(((*R2H) << 8) | *R3L);

    while (1) {
        unsigned short target, guess, guess_count;
        
        target = (rand() % 100) + 1;
        guess = 101;
        guess_count = 1;
        while (guess != target) {
            printf("Guess #%d: ", guess_count);
            fgets(buffer, sizeof(buffer), stdin);
            if (buffer[0] == '\0') { exit(1); }
            guess = atoi(buffer);
            if (guess < target) {
                puts("Too low!");
            } else if (guess > target) {
                puts("Too high!");
            } else {
                printf("Correct! Number of guesses: %u\n", guess_count);
            }
            ++guess_count;
        }
        printf("Play again (y/n)? ");
        fgets(buffer, sizeof(buffer), stdin);
        if (buffer[0] != 'y' && buffer[0] != 'Y') break;
    }
    return 0;
}