#include <stdio.h>
#include <stdlib.h>
#include "cx16os.h"

char buffer[128];

int main() {
    srand(get_random());

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