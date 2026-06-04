/* line-rewrite — copy stdin to stdout, replacing whole 1-based lines named on
 * the command line with given replacement strings.
 *
 * Usage: line-rewrite <lineno> <replacement> [<lineno> <replacement> ...] < in
 *
 * Replaces the host awk that rebuilt the per-link Mach-O load-command template
 * from MACHO-amd64-lowdata.hex2:
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
