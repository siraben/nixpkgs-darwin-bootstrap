/* tsv-col — print column 2 of a tab-separated symbol table where column 1
 * equals the requested tag (D = defined, U = undefined), skipping empty col2.
 *
 * Replaces the host awk in tcc-darwin-cc's symbol-set machinery:
 *   awk -F'\t' '$1 == "D" && $2 != "" { print $2 }'   (tsv-col D)
 *   awk -F'\t' '$1 == "U" && $2 != "" { print $2 }'   (tsv-col U)
 * The output is piped to `sort -u`, so only the SET of col2 values matters; we
 * emit each match on its own line.  Reads stdin (freopen hangs in the chain
 * libc), caller redirects.
 */
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
	const char *want;
	int wlen, c;
	if (argc < 2) { fprintf(stderr, "usage: tsv-col D|U < tsv\n"); return 2; }
	want = argv[1];
	wlen = (int) strlen(want);

	c = getchar();
	while (c != EOF) {
		int i = 0, mismatch = 0, delim = 0;
		/* read column 1 up to the first tab / newline / EOF */
		for (;;) {
			if (c == '\t') { delim = '\t'; break; }
			if (c == '\n' || c == EOF) { delim = c; break; }
			if (!mismatch) {
				if (i < wlen && (char) c == want[i]) i++;
				else mismatch = 1;
			}
			c = getchar();
		}
		if (!mismatch && i == wlen && delim == '\t') {
			/* column 1 matched exactly: print column 2 until newline/EOF,
			 * but (like awk's $2 != "") only if it is non-empty. */
			int any = 0;
			while ((c = getchar()) != EOF && c != '\n') { putchar(c); any = 1; }
			if (any) putchar('\n');
		} else if (delim == '\t') {
			/* skip the rest of this line */
			while ((c = getchar()) != EOF && c != '\n') ;
		}
		if (c == EOF) break;
		c = getchar();   /* consume the newline; start next line */
	}
	return 0;
}
