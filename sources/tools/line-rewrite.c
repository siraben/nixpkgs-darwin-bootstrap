/* line-rewrite — copy stdin to stdout, replacing whole 1-based lines named on
 * the command line with given replacement strings.
 *
 * Usage: line-rewrite <lineno> <replacement> [<lineno> <replacement> ...] < in
 *
 * Link-path role: the tcc-darwin-cc wrapper's @LINE_REWRITE@ hook — per
 * link it rewrites the 8 segment size/offset lines (10,11,15,19,20,21,
 * 24,25) of the MACHO-amd64-lowdata.hex2 template with the layout
 * m1-to-hex2 --auto-data-align reported, producing that binary's Mach-O
 * load-command block.  Built in step 44f by tcc-darwin-cc itself.
 * Replaces the host awk that did this template rewrite:
 *   awk -v n10=.. .. 'NR==10{print n10;next} .. NR==25{print n25;next} {print}'
 * Like awk's print, every emitted line is terminated with a newline (the
 * template's final line gets one even if the input lacked it).  Reads stdin —
 * freopen() hangs in the chain libc.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv) {
	int npairs, i, lineno = 1, c;
	long *nums;
	char **repls;
	if (argc < 3 || (argc - 1) % 2 != 0) {
		fprintf(stderr, "usage: line-rewrite <lineno> <replacement> ... < in\n");
		return 2;
	}
	npairs = (argc - 1) / 2;
	nums = malloc(npairs * sizeof(long));
	repls = malloc(npairs * sizeof(char *));
	if (!nums || !repls) { fprintf(stderr, "line-rewrite: oom\n"); return 1; }
	for (i = 0; i < npairs; i++) {
		nums[i] = atol(argv[1 + 2 * i]);
		repls[i] = argv[2 + 2 * i];
	}

	for (;;) {
		const char *repl = NULL;
		c = getchar();
		if (c == EOF) break;                 /* no more lines */
		for (i = 0; i < npairs; i++)
			if (nums[i] == lineno) { repl = repls[i]; break; }
		if (repl) {
			fputs(repl, stdout);
			putchar('\n');
			while (c != '\n' && c != EOF) c = getchar();   /* drop original */
		} else {
			while (c != '\n' && c != EOF) { putchar(c); c = getchar(); }
			putchar('\n');                   /* awk ORS terminates every record */
		}
		lineno++;
		if (c == EOF) break;
	}
	return 0;
}
