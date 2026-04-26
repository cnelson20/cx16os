#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <cx16os.h>

#define SEED_FILENAME "~/tmp/RAND_SEED"

int main(int argc, char *argv[]) {
    int seed, new_seed;
    int seed_fd;
    
    unsigned output, slots;
    unsigned start = 0, end = 32767, step = 1;
    
    if (argc == 2) {
        // Set seed
        seed = atoi(argv[1]);
        seed_fd = open(SEED_FILENAME, O_WRONLY | O_CREAT);
        write(seed_fd, &seed, 4);
        close(seed_fd);
        return 0;
    } else if (argc >= 3) {
        start = atoi(argv[1]);
        end = atoi(argv[2]);
        if (argc >= 4) {
            step = atoi(argv[3]);
        }
    }

    seed_fd = open(SEED_FILENAME, O_RDONLY);
    if (seed_fd != -1) {
        // Read seed from file
        read(seed_fd, &seed, 4);
        close(seed_fd);
    } else {
        // Try file or get seed from get_random()
        seed = get_random();
    }
    srand(seed);
    new_seed = rand();
    output = (unsigned)rand();
    seed_fd = open(SEED_FILENAME, O_WRONLY | O_CREAT);
    write(seed_fd, &new_seed, 4);
    close(seed_fd);
    
    slots = (end + 1 - start) / step;
    printf("%d\n", (output % slots) * step + start);
    return 0;
}
