/* ctor-table — emit the bake C++ global-constructor init table from the per-
 * object/member code M1 files passed as arguments.
 *
 * Replaces the host pipeline
 *   grep -hoE '^:[A-Za-z0-9_.$]*_GLOBAL__sub_I[A-Za-z0-9_.$]*' code_files \
 *     | sed 's/^://' | awk '!seen[$0]++' \
 *     | while read ctor; do printf '&%s\n!0x00 !0x00 !0x00 !0x00\n' "$ctor"; done
 *
 * For every line that starts with ':' and whose maximal [A-Za-z0-9_.$] run
 * contains "_GLOBAL__sub_I", it takes that run (the ctor label, sans ':') and,
 * keeping FIRST-occurrence order and dropping duplicates, prints:
 *   &<ctor>
 *   !0x00 !0x00 !0x00 !0x00
 * Missing files are skipped (matching grep -h ... 2>/dev/null).
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int label_char(int c) {
	return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
	       (c >= '0' && c <= '9') || c == '_' || c == '.' || c == '$';
}

static char **seen;
static int nseen, capseen;

static int already_seen(const char *s) {
	int i;
	for (i = 0; i < nseen; i++)
		if (strcmp(seen[i], s) == 0) return 1;
	if (nseen == capseen) {
		capseen = capseen ? capseen * 2 : 64;
		seen = realloc(seen, capseen * sizeof(char *));
		if (!seen) { fprintf(stderr, "ctor-table: out of memory\n"); exit(1); }
	}
	seen[nseen] = strdup(s);
	nseen++;
	return 0;
}

int main(int argc, char **argv) {
	int a;
	char buf[16384];
	for (a = 1; a < argc; a++) {
		FILE *f = fopen(argv[a], "rb");
		int c;
		if (!f) continue;                 /* grep -h ... 2>/dev/null skips it */
		c = fgetc(f);
		while (c != EOF) {
			int n = 0, is_label = (c == ':'), saw_marker;
			if (is_label) {
				/* collect the maximal label-char run after ':' */
				while ((c = fgetc(f)) != EOF && c != '\n' && label_char(c))
					if (n < (int) sizeof(buf) - 1) buf[n++] = (char) c;
			}
			/* consume the rest of the line */
			while (c != EOF && c != '\n') c = fgetc(f);
			if (is_label && n > 0) {
				buf[n] = '\0';
				saw_marker = strstr(buf, "_GLOBAL__sub_I") != NULL;
				if (saw_marker && !already_seen(buf))
					printf("&%s\n!0x00 !0x00 !0x00 !0x00\n", buf);
			}
			if (c == EOF) break;
			c = fgetc(f);                 /* step past '\n' to next line */
		}
		fclose(f);
	}
	return 0;
}
