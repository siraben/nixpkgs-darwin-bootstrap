#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>

static int nybble(int c)
{
    if ('0' <= c && c <= '9') return c - '0';
    if ('a' <= c && c <= 'f') return c - 'a' + 10;
    if ('A' <= c && c <= 'F') return c - 'A' + 10;
    return -1;
}

static void skip_comment(FILE *input)
{
    int c;
    do {
        c = fgetc(input);
    } while (c != EOF && c != '\n' && c != '\r');
}

int main(int argc, char **argv)
{
    if (argc < 2 || argc > 3) {
        fprintf(stderr, "usage: hex0 INPUT [OUTPUT]\n");
        return 2;
    }

    FILE *input = fopen(argv[1], "r");
    if (input == NULL) {
        perror(argv[1]);
        return 1;
    }

    FILE *output = stdout;
    if (argc == 3) {
        output = fopen(argv[2], "wb");
        if (output == NULL) {
            perror(argv[2]);
            fclose(input);
            return 1;
        }
        chmod(argv[2], 0700);
    }

    int high = -1;
    int c;
    while ((c = fgetc(input)) != EOF) {
        if (c == '#' || c == ';') {
            skip_comment(input);
            continue;
        }
        int value = nybble(c);
        if (value < 0) {
            if (isspace(c)) continue;
            fprintf(stderr, "invalid hex0 character: 0x%02x\n", (unsigned char)c);
            return 1;
        }
        if (high < 0) {
            high = value;
        } else {
            fputc((high << 4) | value, output);
            high = -1;
        }
    }

    if (high >= 0) {
        fputs("odd number of hex digits\n", stderr);
        return 1;
    }

    if (fclose(input) != 0) return 1;
    if (output != stdout && fclose(output) != 0) return 1;
    return 0;
}
