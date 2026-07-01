/* synth-inject — inject precise cross-object `:<sym>_plus_<hex>` synth-label
 * definitions into a combined (whitespace-flattened) M1 stream.
 *
 * Link-path role: the tcc-darwin-cc wrapper's @SYNTH_INJECT_BIN@ hook — per
 * link the wrapper flattens the combined M1 to one token per line with tr
 * and runs this tool on that file.  Built in step 44g by tcc-darwin-cc
 * itself.  Replaces host awk (synth-inject.awk) in the link path; the awk
 * stays as the fallback and as the byte-comparison reference in step 44g's
 * smoke test.
 *
 * Chain-built C port of synth-inject.awk (byte-identical).  elf64-to-m1 emits a
 * synthetic label for every `sym+offset` reference but can only DEFINE the ones
 * it predicts; a cross-object reference whose offset the defining object never
 * relocates (e.g. a C++ vtable slot `_ZTV...sym_plus_730`) is left undefined and
 * hex2 rejects it.  This pass scans the whole link for `&sym_plus_<hex>` /
 * `%sym_plus_<hex>` references with no matching `:sym_plus_<hex>` def and injects
 * the def at the right byte (position of `:sym` + <hex>).
 *
 * Usage: synth-inject <combined.tok.M1>   (one token per line; we read the file
 * THREE times via fopen+rewind — freopen hangs in the chain libc, but
 * fopen/fseek/rewind work.)  Output to stdout.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ---------- small string hash set ---------- */
#define NB 65536
typedef struct SNode { char *key; struct SNode *next; } SNode;
static SNode *set_refd[NB], *set_defd[NB];

static unsigned hash_str(const char *s) {
	unsigned h = 5381; int c;
	while ((c = (unsigned char) *s++)) h = ((h << 5) + h) + c;
	return h & (NB - 1);
}
static int set_has(SNode **t, const char *k) {
	SNode *n = t[hash_str(k)];
	for (; n; n = n->next) if (strcmp(n->key, k) == 0) return 1;
	return 0;
}
static void set_add(SNode **t, const char *k) {
	unsigned h = hash_str(k);
	SNode *n = t[h];
	for (; n; n = n->next) if (strcmp(n->key, k) == 0) return;
	n = malloc(sizeof(SNode));
	n->key = strdup(k);
	n->next = t[h];
	t[h] = n;
}

/* ---------- string -> string map (need: base -> " hex1 hex2 ...") ---------- */
typedef struct MNode { char *key, *val; struct MNode *next; } MNode;
static MNode *need[NB];
static int nneed;
static MNode *need_find(const char *k) {
	MNode *n = need[hash_str(k)];
	for (; n; n = n->next) if (strcmp(n->key, k) == 0) return n;
	return NULL;
}
static void need_append(const char *base, const char *hex) {
	unsigned h = hash_str(base);
	MNode *n = need[h];
	for (; n; n = n->next) if (strcmp(n->key, base) == 0) break;
	if (!n) {
		n = malloc(sizeof(MNode));
		n->key = strdup(base);
		n->val = strdup("");
		n->next = need[h];
		need[h] = n;
	}
	{
		size_t l = strlen(n->val);
		char *v = malloc(l + 1 + strlen(hex) + 1);
		memcpy(v, n->val, l);
		v[l] = ' ';
		strcpy(v + l + 1, hex);
		free(n->val);
		n->val = v;
	}
}

/* ---------- long -> string map (sched: position -> "\x01lab1\x01lab2") ------ */
typedef struct LNode { long key; char *val; struct LNode *next; } LNode;
static LNode *sched[NB];
static LNode *sched_find(long k) {
	LNode *n = sched[(unsigned long) k & (NB - 1)];
	for (; n; n = n->next) if (n->key == k) return n;
	return NULL;
}
static void sched_append(long k, const char *lab) {
	unsigned idx = (unsigned long) k & (NB - 1);
	LNode *n = sched[idx];
	for (; n; n = n->next) if (n->key == k) break;
	if (!n) {
		n = malloc(sizeof(LNode));
		n->key = k;
		n->val = strdup("");
		n->next = sched[idx];
		sched[idx] = n;
	}
	{
		size_t l = strlen(n->val);
		char *v = malloc(l + 1 + strlen(lab) + 1);
		memcpy(v, n->val, l);
		v[l] = '\x01';
		strcpy(v + l + 1, lab);
		free(n->val);
		n->val = v;
	}
}
static void sched_delete(long k) {
	unsigned idx = (unsigned long) k & (NB - 1);
	LNode **pp = &sched[idx], *n;
	while ((n = *pp)) {
		if (n->key == k) { *pp = n->next; free(n->val); free(n); return; }
		pp = &n->next;
	}
}

/* ---------- token helpers ---------- */
static int tokbytes(const char *t) {
	switch (t[0]) {
	case '!': return 1;
	case '&': case '%': return 4;
	case '@': case '$': return 2;
	case '~': return 3;
	default:  return 0;
	}
}
static long h2i(const char *s) {
	long v = 0; int c;
	for (; (c = *s); s++) {
		int d;
		if (c >= '0' && c <= '9') d = c - '0';
		else if (c >= 'a' && c <= 'f') d = c - 'a' + 10;
		else if (c >= 'A' && c <= 'F') d = c - 'A' + 10;
		else break;
		v = v * 16 + d;
	}
	return v;
}
/* label ends with _plus_<hex>? return offset of "_plus_" (0-based) or -1 */
static long plus_pos(const char *lab) {
	size_t n = strlen(lab), i;
	const char *p = NULL, *q = lab;
	while ((q = strstr(q, "_plus_")) != NULL) { p = q; q += 6; }  /* LAST _plus_ */
	if (!p) return -1;
	i = (p - lab) + 6;
	if (i >= n) return -1;                       /* nothing after _plus_ */
	for (; i < n; i++) {
		char c = lab[i];
		if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')))
			return -1;                           /* not all-hex suffix */
	}
	return p - lab;
}

/* read one whitespace-delimited token from f into buf; returns length, or -1 at
 * EOF.  Skips leading spaces/tabs/newlines (matches awk's FS=/[ \t]+/ over
 * records: empty fields are ignored by the caller anyway). */
static int next_token(FILE *f, char *buf, int cap) {
	int c, n = 0;
	do { c = fgetc(f); } while (c == ' ' || c == '\t' || c == '\n');
	if (c == EOF) return -1;
	while (c != EOF && c != ' ' && c != '\t' && c != '\n') {
		if (n < cap - 1) buf[n++] = (char) c;
		c = fgetc(f);
	}
	buf[n] = '\0';
	return n;
}

static char tokbuf[1 << 20];

int main(int argc, char **argv) {
	FILE *f;
	long pos = 0;
	if (argc < 2) { fprintf(stderr, "usage: synth-inject <combined.tok.M1>\n"); return 2; }
	f = fopen(argv[1], "rb");
	if (!f) { fprintf(stderr, "synth-inject: cannot open %s\n", argv[1]); return 1; }

	/* pass A1: referenced _plus_ labels */
	while (next_token(f, tokbuf, sizeof tokbuf) >= 0) {
		char c = tokbuf[0];
		if (c == '&' || c == '%') {
			char *lab = tokbuf + 1, *gt = strchr(lab, '>');
			if (gt) *gt = '\0';                  /* strip >base suffix */
			if (plus_pos(lab) >= 0) set_add(set_refd, lab);
		}
	}
	/* pass A2: which referenced labels are defined */
	rewind(f);
	while (next_token(f, tokbuf, sizeof tokbuf) >= 0) {
		if (tokbuf[0] == ':') {
			char *lab = tokbuf + 1;
			if (set_has(set_refd, lab)) set_add(set_defd, lab);
		}
	}
	/* needed = refd \ defd, indexed by base symbol */
	{
		int b;
		for (b = 0; b < NB; b++) {
			SNode *n;
			for (n = set_refd[b]; n; n = n->next) {
				long pp;
				if (set_has(set_defd, n->key)) continue;
				pp = plus_pos(n->key);
				if (pp >= 0) {
					char base[1 << 16];
					memcpy(base, n->key, pp);
					base[pp] = '\0';
					need_append(base, n->key + pp + 6);
					nneed++;
				}
			}
		}
	}

	/* pass B */
	rewind(f);
	if (nneed == 0) {
		/* fast path: copy verbatim, but as awk does — one record (token) per
		 * line, terminated by a newline.  The input is already one token per
		 * line, so re-emitting each token preserves bytes (and adds a final
		 * newline if the input lacked one, matching awk). */
		int len;
		while ((len = next_token(f, tokbuf, sizeof tokbuf)) >= 0)
			printf("%s\n", tokbuf);
		fclose(f);
		return 0;
	}
	while (next_token(f, tokbuf, sizeof tokbuf) >= 0) {
		char c = tokbuf[0];
		int b;
		if (c == ':') {
			LNode *s;
			MNode *m;
			/* flush_at(pos) */
			s = sched_find(pos);
			if (s) {
				char *p = s->val, *start;
				for (;;) {
					while (*p == '\x01') p++;
					if (!*p) break;
					start = p;
					while (*p && *p != '\x01') p++;
					{ char save = *p; *p = '\0'; if (*start) printf(":%s\n", start); *p = save; }
				}
				sched_delete(pos);
			}
			printf(":%s\n", tokbuf + 1);
			m = need_find(tokbuf + 1);
			if (m) {
				char *p = m->val, *start;
				for (;;) {
					while (*p == ' ') p++;
					if (!*p) break;
					start = p;
					while (*p && *p != ' ') p++;
					{
						char save = *p; *p = '\0';
						if (*start) {
							long tp = pos + h2i(start);
							char lab[1 << 16];
							snprintf(lab, sizeof lab, "%s_plus_%s", tokbuf + 1, start);
							sched_append(tp, lab);
						}
						*p = save;
					}
				}
			}
			continue;
		}
		b = tokbytes(tokbuf);
		if (b == 0) { printf("%s\n", tokbuf); continue; }
		/* flush_at(pos) then emit */
		{
			LNode *s = sched_find(pos);
			if (s) {
				char *p = s->val, *start;
				for (;;) {
					while (*p == '\x01') p++;
					if (!*p) break;
					start = p;
					while (*p && *p != '\x01') p++;
					{ char save = *p; *p = '\0'; if (*start) printf(":%s\n", start); *p = save; }
				}
				sched_delete(pos);
			}
		}
		printf("%s\n", tokbuf);
		pos += b;
	}
	/* END: flush_at(pos) */
	{
		LNode *s = sched_find(pos);
		if (s) {
			char *p = s->val, *start;
			for (;;) {
				while (*p == '\x01') p++;
				if (!*p) break;
				start = p;
				while (*p && *p != '\x01') p++;
				{ char save = *p; *p = '\0'; if (*start) printf(":%s\n", start); *p = save; }
			}
		}
	}
	fclose(f);
	return 0;
}
