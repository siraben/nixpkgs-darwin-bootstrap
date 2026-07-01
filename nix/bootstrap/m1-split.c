/* m1-split — split a combined M1 stream into its code or data section.
 *
 * M2-Planet-dialect port of sources/tools/m1-split.c, built through
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
 * Optional `--split-label LABEL` (used by the mescc-libc M1 reassembly):
 * the split ALSO triggers when a line equals LABEL, and in --data mode
 * the LABEL line is PRINTED (not dropped, unlike :ELF_data).  This
 * mirrors the awk variant
 *   awk 'split_re!="" && $0~split_re { data=1; [print;] next }
 *        /^:ELF_data$/ { data=1; next } /^:HEX2_data$/ { next }
 *        data{!=,==}1 { print }'
 * where split_re was an anchored ^:LABEL$ (an exact whole-line match).
 *
 * Reads the M1 on stdin (`m1-split --code [--split-label :foo] < file`).
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv) {
	char *buf;
	char *label_nl;
	int label_len;
	int label_match;
	int prefix;
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
		fputs("usage: m1-split --code|--data [--split-label :foo] < file\n", stderr);
		return 2;
	}
	code_mode = 0;
	data_mode = 0;
	if (strcmp(argv[1], "--code") == 0) code_mode = 1;
	if (strcmp(argv[1], "--data") == 0) data_mode = 1;
	if (code_mode == 0) {
		if (data_mode == 0) {
			fputs("usage: m1-split --code|--data [--split-label :foo] < file\n", stderr);
			return 2;
		}
	}

	/* optional --split-label LABEL: build LABEL+"\n" for whole-line match */
	label_nl = 0;
	label_len = 0;
	if (argc >= 4) {
		if (strcmp(argv[2], "--split-label") == 0) {
			int ll;
			ll = strlen(argv[3]);
			label_nl = calloc(ll + 2, sizeof(char));
			memcpy(label_nl, argv[3], ll);
			label_nl[ll] = '\n';
			label_nl[ll + 1] = 0;
			label_len = ll + 1;
		}
	}

	/* prefix read must be long enough to recognise the longest marker:
	 * ":HEX2_data\n" is 11; the optional label may be longer. */
	prefix = 11;
	if (label_len > prefix) prefix = label_len;

	buf = calloc(prefix + 2, sizeof(char));

	while (done == 0) {
		n = 0;
		eol = 0;
		eof = 0;
		/* read the line prefix (enough to recognise the longest marker) */
		while (n < prefix) {
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
		/* split-label is checked FIRST (mirrors awk's split_re rule order);
		 * in --data the label line is PRINTED, unlike :ELF_data. */
		label_match = 0;
		if (eol == 1) {
			if (label_nl != 0) {
				if (strcmp(buf, label_nl) == 0) label_match = 1;
			}
		}
		if (label_match == 1) {
			data = 1;
			if (data_mode == 1) {
				int i;
				i = 0;
				while (i < n) {
					fputc(buf[i], stdout);
					i = i + 1;
				}
				wrote = 1;
				last = buf[n - 1];
			}
			continue;
		}
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
