#include <stdio.h>
#include <stdlib.h>
#include <magic.h>

int main(int argc, char *argv[]) {
    // Check if filename is provided
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <filename>\n", argv[0]);
        return 1;
    }

    // Initialize magic handle
    magic_t magic = magic_open(MAGIC_MIME_TYPE);
    if (magic == NULL) {
        fprintf(stderr, "Failed to initialize libmagic\n");
        return 1;
    }

    // Load magic database
    if (magic_load(magic, NULL) != 0) {
        fprintf(stderr, "Cannot load magic database: %s\n", magic_error(magic));
        magic_close(magic);
        return 1;
    }

    // Get MIME type
    const char *mime_type = magic_file(magic, argv[1]);
    if (mime_type == NULL) {
        fprintf(stderr, "Error determining MIME type: %s\n", magic_error(magic));
        magic_close(magic);
        return 1;
    }

    // Print result
    printf("MIME type: %s\n", mime_type);

    // Cleanup
    magic_close(magic);
    return 0;
}