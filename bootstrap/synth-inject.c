/* synth-inject — inject precise cross-object `:<sym>_plus_<hex>` synth-label
 * definitions into a combined (whitespace-flattened) M1 stream.
 *
 * M2-Planet-dialect port of bake/sources/tools/synth-inject.c
 * (byte-identical output), built through the m2 → m1 → hex2 →
 * macho-patcher pipeline so the tcc-darwin-cc wrapper never needs an awk
 * fallback.  elf64-to-m1 emits a synthetic label for every `sym+offset`
 * reference but can only DEFINE the ones it predicts; a cross-object
 * reference whose offset the defining object never relocates is left
 * undefined and hex2 rejects it.  This pass scans the whole link for
 * `&sym_plus_<hex>` / `%sym_plus_<hex>` references with no matching
 * `:sym_plus_<hex>` def and injects the def at byte (:sym + <hex>).
 *
 * Usage: synth-inject <combined.tok.M1>  (one token per line); output on
 * stdout.  The file is read three times via fopen (no rewind in the
 * minimal libcs).
 *
 * M2 dialect notes: heap-allocated hash tables (global pointer arrays
 * are unreliable under M2-Planet on Darwin), no ternary/switch/strstr/
 * strdup/snprintf.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define NB 65536
#define TOKCAP 1048576
#define LABCAP 65536

/* set / map node: key, val, numeric key, next.  One shape for all three
 * tables keeps the M2 struct handling simple. */
struct node {
	char *key;
	char *val;
	long nkey;
	struct node *next;
};

struct node **set_refd;
struct node **set_defd;
struct node **need;
struct node **sched;
int nneed;

unsigned hash_str(char *s) {
	unsigned h;
	int c;
	h = 5381;
	c = s[0];
	while (c != 0) {
		h = ((h << 5) + h) + c;
		s = s + 1;
		c = s[0];
	}
	return h & (NB - 1);
}

char *dup_str(char *s) {
	int n;
	char *d;
	n = strlen(s);
	d = calloc(n + 1, sizeof(char));
	memcpy(d, s, n);
	return d;
}

int set_has(struct node **t, char *k) {
	struct node *n;
	n = t[hash_str(k)];
	while (n != 0) {
		if (strcmp(n->key, k) == 0) return 1;
		n = n->next;
	}
	return 0;
}

void set_add(struct node **t, char *k) {
	unsigned h;
	struct node *n;
	h = hash_str(k);
	n = t[h];
	while (n != 0) {
		if (strcmp(n->key, k) == 0) return;
		n = n->next;
	}
	n = calloc(1, sizeof(struct node));
	n->key = dup_str(k);
	n->next = t[h];
	t[h] = n;
}

struct node *map_find(struct node **t, char *k) {
	struct node *n;
	n = t[hash_str(k)];
	while (n != 0) {
		if (strcmp(n->key, k) == 0) return n;
		n = n->next;
	}
	return 0;
}

/* append sep+s to n->val */
void val_append(struct node *n, int sep, char *s) {
	int l;
	int sl;
	char *v;
	l = strlen(n->val);
	sl = strlen(s);
	v = calloc(l + 1 + sl + 1, sizeof(char));
	memcpy(v, n->val, l);
	v[l] = sep;
	memcpy(v + l + 1, s, sl);
	free(n->val);
	n->val = v;
}

void need_append(char *base, char *hex) {
	unsigned h;
	struct node *n;
	h = hash_str(base);
	n = need[h];
	while (n != 0) {
		if (strcmp(n->key, base) == 0) break;
		n = n->next;
	}
	if (n == 0) {
		n = calloc(1, sizeof(struct node));
		n->key = dup_str(base);
		n->val = calloc(1, sizeof(char));
		n->next = need[h];
		need[h] = n;
	}
	val_append(n, ' ', hex);
}

struct node *sched_find(long k) {
	struct node *n;
	n = sched[k & (NB - 1)];
	while (n != 0) {
		if (n->nkey == k) return n;
		n = n->next;
	}
	return 0;
}

void sched_append(long k, char *lab) {
	long idx;
	struct node *n;
	idx = k & (NB - 1);
	n = sched[idx];
	while (n != 0) {
		if (n->nkey == k) break;
		n = n->next;
	}
	if (n == 0) {
		n = calloc(1, sizeof(struct node));
		n->nkey = k;
		n->val = calloc(1, sizeof(char));
		n->next = sched[idx];
		sched[idx] = n;
	}
	val_append(n, 1, lab);
}

void sched_delete(long k) {
	long idx;
	struct node *n;
	struct node *prev;
	idx = k & (NB - 1);
	prev = 0;
	n = sched[idx];
	while (n != 0) {
		if (n->nkey == k) {
			if (prev == 0) sched[idx] = n->next;
			else prev->next = n->next;
			free(n->val);
			free(n);
			return;
		}
		prev = n;
		n = n->next;
	}
}

/* emit ":<piece>\n" for each sep-separated piece of n->val */
void flush_val(struct node *n, int sep) {
	char *p;
	int i;
	p = n->val;
	while (p[0] != 0) {
		while (p[0] == sep) p = p + 1;
		if (p[0] == 0) break;
		fputc(':', stdout);
		while (p[0] != 0) {
			if (p[0] == sep) break;
			fputc(p[0], stdout);
			p = p + 1;
		}
		fputc('\n', stdout);
	}
	/* silence unused warning pattern in some compilers */
	i = 0;
	if (i != 0) return;
}

void flush_at(long pos) {
	struct node *s;
	s = sched_find(pos);
	if (s != 0) {
		flush_val(s, 1);
		sched_delete(pos);
	}
}

int tokbytes(char *t) {
	int c;
	c = t[0];
	if (c == '!') return 1;
	if (c == '&') return 4;
	if (c == '%') return 4;
	if (c == '@') return 2;
	if (c == '$') return 2;
	if (c == '~') return 3;
	return 0;
}

long h2i(char *s) {
	long v;
	int c;
	int d;
	v = 0;
	c = s[0];
	while (c != 0) {
		d = -1;
		if (c >= '0') {
			if (c <= '9') d = c - '0';
		}
		if (c >= 'a') {
			if (c <= 'f') d = c - 'a' + 10;
		}
		if (c >= 'A') {
			if (c <= 'F') d = c - 'A' + 10;
		}
		if (d < 0) break;
		v = v * 16 + d;
		s = s + 1;
		c = s[0];
	}
	return v;
}

int is_hex_char(int c) {
	if (c >= '0') {
		if (c <= '9') return 1;
	}
	if (c >= 'a') {
		if (c <= 'f') return 1;
	}
	if (c >= 'A') {
		if (c <= 'F') return 1;
	}
	return 0;
}

/* label ends with _plus_<hex>?  return offset of the LAST "_plus_" or -1 */
long plus_pos(char *lab) {
	long n;
	long i;
	long last;
	long j;
	n = strlen(lab);
	last = 0 - 1;
	i = 0;
	while (i + 6 <= n) {
		if (lab[i] == '_') {
			if (strncmp(lab + i, "_plus_", 6) == 0) last = i;
		}
		i = i + 1;
	}
	if (last < 0) return 0 - 1;
	j = last + 6;
	if (j >= n) return 0 - 1;
	while (j < n) {
		if (is_hex_char(lab[j]) == 0) return 0 - 1;
		j = j + 1;
	}
	return last;
}

/* read one whitespace-delimited token; returns length or -1 at EOF */
int next_token(FILE *f, char *buf, int cap) {
	int c;
	int n;
	n = 0;
	c = fgetc(f);
	while (1 == 1) {
		if (c != ' ') {
			if (c != '\t') {
				if (c != '\n') break;
			}
		}
		c = fgetc(f);
	}
	if (c == EOF) return 0 - 1;
	while (c != EOF) {
		if (c == ' ') break;
		if (c == '\t') break;
		if (c == '\n') break;
		if (n < cap - 1) {
			buf[n] = c;
			n = n + 1;
		}
		c = fgetc(f);
	}
	buf[n] = 0;
	return n;
}

void emit_token_line(char *t) {
	fputs(t, stdout);
	fputc('\n', stdout);
}

int main(int argc, char **argv) {
	FILE *f;
	char *tokbuf;
	char *base;
	char *lab;
	long pos;
	int len;
	int b;
	int c;

	if (argc < 2) {
		fputs("usage: synth-inject <combined.tok.M1>\n", stderr);
		return 2;
	}

	set_refd = calloc(NB, sizeof(struct node *));
	set_defd = calloc(NB, sizeof(struct node *));
	need = calloc(NB, sizeof(struct node *));
	sched = calloc(NB, sizeof(struct node *));
	tokbuf = calloc(TOKCAP, sizeof(char));
	base = calloc(LABCAP, sizeof(char));
	lab = calloc(LABCAP, sizeof(char));
	nneed = 0;

	/* pass A1: referenced _plus_ labels */
	f = fopen(argv[1], "r");
	if (f == 0) {
		fputs("synth-inject: cannot open ", stderr);
		fputs(argv[1], stderr);
		fputc('\n', stderr);
		return 1;
	}
	len = next_token(f, tokbuf, TOKCAP);
	while (len >= 0) {
		c = tokbuf[0];
		if (c == '&') c = '%';
		if (c == '%') {
			char *l;
			int i;
			l = tokbuf + 1;
			/* strip >base suffix */
			i = 0;
			while (l[i] != 0) {
				if (l[i] == '>') {
					l[i] = 0;
					break;
				}
				i = i + 1;
			}
			if (plus_pos(l) >= 0) set_add(set_refd, l);
		}
		len = next_token(f, tokbuf, TOKCAP);
	}
	fclose(f);

	/* pass A2: which referenced labels are defined */
	f = fopen(argv[1], "r");
	len = next_token(f, tokbuf, TOKCAP);
	while (len >= 0) {
		if (tokbuf[0] == ':') {
			if (set_has(set_refd, tokbuf + 1)) set_add(set_defd, tokbuf + 1);
		}
		len = next_token(f, tokbuf, TOKCAP);
	}
	fclose(f);

	/* needed = refd \ defd, indexed by base symbol */
	{
		int bx;
		struct node *n;
		long pp;
		bx = 0;
		while (bx < NB) {
			n = set_refd[bx];
			while (n != 0) {
				if (set_has(set_defd, n->key) == 0) {
					pp = plus_pos(n->key);
					if (pp >= 0) {
						memcpy(base, n->key, pp);
						base[pp] = 0;
						need_append(base, n->key + pp + 6);
						nneed = nneed + 1;
					}
				}
				n = n->next;
			}
			bx = bx + 1;
		}
	}

	/* pass B */
	f = fopen(argv[1], "r");
	pos = 0;
	if (nneed == 0) {
		/* fast path: one token per line, verbatim */
		len = next_token(f, tokbuf, TOKCAP);
		while (len >= 0) {
			emit_token_line(tokbuf);
			len = next_token(f, tokbuf, TOKCAP);
		}
		fclose(f);
		return 0;
	}
	len = next_token(f, tokbuf, TOKCAP);
	while (len >= 0) {
		c = tokbuf[0];
		if (c == ':') {
			struct node *m;
			flush_at(pos);
			emit_token_line(tokbuf);
			m = map_find(need, tokbuf + 1);
			if (m != 0) {
				char *p;
				int i;
				int li;
				p = m->val;
				while (p[0] != 0) {
					while (p[0] == ' ') p = p + 1;
					if (p[0] == 0) break;
					/* hex run -> base buffer */
					i = 0;
					while (p[0] != 0) {
						if (p[0] == ' ') break;
						base[i] = p[0];
						i = i + 1;
						p = p + 1;
					}
					base[i] = 0;
					if (i > 0) {
						long tp;
						tp = pos + h2i(base);
						/* lab = "<sym>_plus_<hex>" */
						li = strlen(tokbuf + 1);
						memcpy(lab, tokbuf + 1, li);
						memcpy(lab + li, "_plus_", 6);
						memcpy(lab + li + 6, base, i);
						lab[li + 6 + i] = 0;
						sched_append(tp, lab);
					}
				}
			}
			len = next_token(f, tokbuf, TOKCAP);
			continue;
		}
		b = tokbytes(tokbuf);
		if (b == 0) {
			emit_token_line(tokbuf);
			len = next_token(f, tokbuf, TOKCAP);
			continue;
		}
		flush_at(pos);
		emit_token_line(tokbuf);
		pos = pos + b;
		len = next_token(f, tokbuf, TOKCAP);
	}
	flush_at(pos);
	fclose(f);
	return 0;
}
