/* m1-split — split a combined M1 stream into its code or data section.
 *
 * M2-Planet-dialect port of bake/sources/tools/m1-split.c, built through
 * the m2 → m1 → hex2 → macho-patcher pipeline so the tcc-darwin-cc
 * wrapper never needs an awk fallback: the binary exists before the
 * wrapper's first link.
 *
 * elf64-to-m1 emits a member's code section, then a ':ELF_data' marker,
 * then the data section; ':HEX2_data' markers may appear in either.
 * --code prints the lines before ':ELF_data'; --data prints the lines
 * after it; both marker lines are dropped.  Streams char-by-char so the
 * giant single .bss/.data line is never buffered.  Output is
 * byte-identical to the original tool (and the awk it replaced).
 *
 * Reads the M1 on stdin (`m1-split --code < file`).
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv) {
	char *buf;
	int code_mode;
	int data_mode;
	int data;
	int wrote;
	int last;
	int n;
	int c;
	int eol;
	int eof;
	int out;
	int done;

	data = 0;
	wrote = 0;
	last = '\n';
	done = 0;

	if (argc < 2) {
		fputs("usage: m1-split --code|--data < file\n", stderr);
		return 2;
	}
	code_mode = 0;
	data_mode = 0;
	if (strcmp(argv[1], "--code") == 0) code_mode = 1;
	if (strcmp(argv[1], "--data") == 0) data_mode = 1;
	if (code_mode == 0) {
		if (data_mode == 0) {
			fputs("usage: m1-split --code|--data < file\n", stderr);
			return 2;
		}
	}

	buf = calloc(17, sizeof(char));

	while (done == 0) {
		n = 0;
		eol = 0;
		eof = 0;
		/* read the line prefix (enough to recognise the longest marker) */
		while (n < 12) {
			c = fgetc(stdin);
			if (c == EOF) {
				eof = 1;
				break;
			}
			buf[n] = c;
			n = n + 1;
			if (c == '\n') {
				eol = 1;
				break;
			}
		}
		if (n == 0) {
			if (eof == 1) break;
		}
		buf[n] = 0;
		if (eol == 1) {
			if (strcmp(buf, ":ELF_data\n") == 0) {
				data = 1;
				continue;
			}
			if (strcmp(buf, ":HEX2_data\n") == 0) continue;
		}
		out = 0;
		if (code_mode == 1) {
			if (data == 0) out = 1;
		} else {
			if (data == 1) out = 1;
		}
		if (out == 1) {
			if (n > 0) {
				int i;
				i = 0;
				while (i < n) {
					fputc(buf[i], stdout);
					i = i + 1;
				}
				wrote = 1;
				last = buf[n - 1];
			}
		}
		if (eol == 0) {
			if (eof == 0) {
				/* stream the rest of a long line */
				c = fgetc(stdin);
				while (c != EOF) {
					if (out == 1) {
						fputc(c, stdout);
						wrote = 1;
						last = c;
					}
					if (c == '\n') break;
					c = fgetc(stdin);
				}
			}
		}
		if (eof == 1) done = 1;
	}
	/* every awk record ends in ORS; M1 input may lack a final newline, so
	 * add one when output is non-empty to stay byte-identical. */
	if (wrote == 1) {
		if (last != '\n') fputc('\n', stdout);
	}
	return 0;
}
