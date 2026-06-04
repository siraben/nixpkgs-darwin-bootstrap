/* m1-split — split a combined M1 stream into its code or data section.
 *
 * Replaces the host awk:
 *   awk '/^:ELF_data$/{data=1;next} /^:HEX2_data$/{next} data!=1{print}'  (--code)
 *   awk '/^:ELF_data$/{data=1;next} /^:HEX2_data$/{next} data==1{print}'  (--data)
 *
 * elf64-to-m1 emits a member's code section, then a ':ELF_data' marker, then the
 * data section; ':HEX2_data' markers may appear in either.  --code prints the
 * lines before ':ELF_data'; --data prints the lines after it; the ':ELF_data'
 * and ':HEX2_data' marker lines themselves are dropped from both.
 *
 * Streams char-by-char so the giant (~100 MB) single .bss/.data line never has
 * to be buffered — only a line's short prefix is examined for the markers.
 * Output is byte-identical to the awk for M1 input that ends in a newline
 * (M1 files always do).
 *
 * Reads the M1 on stdin (`m1-split --code < file`); the caller redirects.  We
 * deliberately do NOT take a file argument — freopen() hangs in the chain libc.
 */
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
	int code_mode, data_mode, data = 0, wrote = 0, last = '\n';
	if (argc < 2) { fprintf(stderr, "usage: m1-split --code|--data < file\n"); return 2; }
	code_mode = strcmp(argv[1], "--code") == 0;
	data_mode = strcmp(argv[1], "--data") == 0;
	if (!code_mode && !data_mode) { fprintf(stderr, "usage: m1-split --code|--data < file\n"); return 2; }

	for (;;) {
		char buf[16];
		int n = 0, c, eol = 0, eof = 0, out;
		/* read the line prefix (enough to recognise the longest marker) */
		while (n < 12) {
			c = getchar();
			if (c == EOF) { eof = 1; break; }
			buf[n++] = (char) c;
			if (c == '\n') { eol = 1; break; }
		}
		if (n == 0 && eof) break;
		buf[n] = '\0';
		if (eol && strcmp(buf, ":ELF_data\n") == 0) { data = 1; continue; }
		if (eol && strcmp(buf, ":HEX2_data\n") == 0) continue;
		out = code_mode ? (data == 0) : (data == 1);
		if (out && n > 0) { fwrite(buf, 1, n, stdout); wrote = 1; last = buf[n - 1]; }
		if (!eol && !eof) {                 /* stream the rest of a long line */
			while ((c = getchar()) != EOF) {
				if (out) { putchar(c); wrote = 1; last = c; }
				if (c == '\n') break;
			}
		}
		if (eof) break;
	}
	/* awk's `print` terminates every record with ORS; M1 input may lack a final
	 * newline, so add one to match awk byte-for-byte when output is non-empty. */
	if (wrote && last != '\n') putchar('\n');
	return 0;
}
