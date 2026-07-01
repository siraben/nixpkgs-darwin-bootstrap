/* boot-ar — a minimal `ar` that stores members verbatim (works with ELF).
 *
 * Link-path role: the tcc-darwin-cc wrapper's @AR@ hook.  The wrapper
 * extracts archives with `boot-ar -x` during archive symbol resolution,
 * and the gcc builds (steps 48+) pack their static libs with it.  Built
 * in step 44b by tcc-darwin-cc itself.  Replaces host python3
 * (boot-ar.py) in the link path.
 *
 * Apple's /usr/bin/ar refuses non-Mach-O members ("not a mach-o file")
 * and silently drops them, which breaks the gcc in-tree static libs
 * (the tcc toolchain emits ELF objects).
 *
 * Reads/writes: 4.4BSD `ar` archives (the container Apple's ar still
 * parses for -x) — "!<arch>\n" magic, 60-byte fixed-width member
 * headers, every member stored byte-for-byte with the BSD extended-name
 * convention "#1/<namelen>" (name bytes prepended to the member data),
 * members padded to even offsets with '\n'.
 *
 * Supported ops: create/replace/append (c r q), list (t), extract (x),
 * delete (d).  Symbol-table modifiers (s) are accepted and ignored —
 * tcc-darwin-cc indexes members itself, so no ranlib index is needed.
 *
 * Output is byte-identical to boot-ar.py for the same inputs.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char MAGIC[8] = { '!','<','a','r','c','h','>','\n' };
#define HDR 60

typedef struct { char *base; unsigned char *data; long len; } Member;

static void die(const char *msg, const char *arg) {
	fprintf(stderr, "boot-ar: %s%s%s\n", msg, arg ? ": " : "", arg ? arg : "");
	exit(1);
}

static void *xmalloc(long n) {
	void *p = malloc(n ? n : 1);
	if (!p) die("out of memory", 0);
	return p;
}

/* Left-justified, space-padded fixed-width field (no NUL), like Python ljust. */
static void field(char *dst, int width, const char *s) {
	int n = (int) strlen(s);
	memset(dst, ' ', width);
	if (n > width) n = width;
	memcpy(dst, s, n);
}

static void put_header(FILE *f, const char *name, long size) {
	char hdr[HDR];
	char tmp[32];
	field(hdr + 0, 16, name);
	field(hdr + 16, 12, "0");          /* mtime */
	field(hdr + 28, 6, "0");           /* uid   */
	field(hdr + 34, 6, "0");           /* gid   */
	field(hdr + 40, 8, "644");         /* mode (octal of 0644) */
	sprintf(tmp, "%ld", size);
	field(hdr + 48, 10, tmp);          /* size  */
	hdr[58] = '`';
	hdr[59] = '\n';
	fwrite(hdr, 1, HDR, f);
}

/* Serialize the member list: magic, then per member a "#1/<namelen>"
 * header, the name bytes, the data, and a '\n' pad to an even offset. */
static void write_archive(const char *path, Member *m, int n) {
	FILE *f = fopen(path, "wb");
	int i;
	if (!f) die("cannot open for write", path);
	fwrite(MAGIC, 1, 8, f);
	for (i = 0; i < n; i++) {
		long nblen = (long) strlen(m[i].base);
		long payload = nblen + m[i].len;
		char nm[32];
		sprintf(nm, "#1/%ld", nblen);
		put_header(f, nm, payload);
		fwrite(m[i].base, 1, nblen, f);
		fwrite(m[i].data, 1, m[i].len, f);
		if (payload % 2) fputc('\n', f);
	}
	fclose(f);
}

/* Read whole file; returns malloc'd buffer, sets *out_len. NULL if absent. */
static unsigned char *slurp(const char *path, long *out_len) {
	FILE *f = fopen(path, "rb");
	unsigned char *buf;
	long n;
	if (!f) return 0;
	fseek(f, 0, SEEK_END);
	n = ftell(f);
	fseek(f, 0, SEEK_SET);
	buf = xmalloc(n + 1);
	if (n > 0 && fread(buf, 1, n, f) != (size_t) n) die("short read", path);
	fclose(f);
	*out_len = n;
	return buf;
}

/* Parse archive blob into members (members[] grows; returns count). */
static int read_archive(const char *path, Member **out) {
	long len, pos;
	unsigned char *blob = slurp(path, &len);
	int cap = 8, n = 0;
	Member *m;
	if (!blob) die("not an archive (missing)", path);
	if (len < 8 || memcmp(blob, MAGIC, 8) != 0) die("not an archive", path);
	m = xmalloc(cap * sizeof(Member));
	pos = 8;
	while (pos + HDR <= len) {
		char name[17];
		char sizebuf[11];
		long size, k;
		int ni;
		memcpy(name, blob + pos, 16);
		name[16] = 0;
		for (ni = 16; ni > 0 && (name[ni - 1] == ' ' || name[ni - 1] == 0); ni--)
			name[ni - 1] = 0;
		memcpy(sizebuf, blob + pos + 48, 10);
		sizebuf[10] = 0;
		/* trim leading/trailing spaces; bail if not a number */
		{
			char *p = sizebuf;
			while (*p == ' ') p++;
			if (*p < '0' || *p > '9') break;   /* malformed -> stop, like py */
			size = atol(p);
		}
		pos += HDR;
		if (n == cap) { cap *= 2; m = realloc(m, cap * sizeof(Member)); if (!m) die("oom", 0); }
		if (strncmp(name, "#1/", 3) == 0) {
			long nlen = atol(name + 3);
			char *base = xmalloc(nlen + 1);
			memcpy(base, blob + pos, nlen);
			base[nlen] = 0;
			m[n].base = base;
			m[n].len = size - nlen;
			m[n].data = xmalloc(m[n].len ? m[n].len : 1);
			memcpy(m[n].data, blob + pos + nlen, m[n].len);
			n++;
		} else if (strcmp(name, "/") == 0 || strcmp(name, "//") == 0 ||
		           strncmp(name, "__.SYMDEF", 9) == 0) {
			/* skip symbol-table / long-name-table members */
		} else {
			/* plain name: strip trailing '/' */
			long bl = (long) strlen(name);
			char *base;
			if (bl > 0 && name[bl - 1] == '/') name[--bl] = 0;
			base = xmalloc(bl + 1);
			memcpy(base, name, bl + 1);
			m[n].base = base;
			m[n].len = size;
			m[n].data = xmalloc(size ? size : 1);
			memcpy(m[n].data, blob + pos, size);
			n++;
		}
		k = size + (size % 2);
		pos += k;
	}
	free(blob);
	*out = m;
	return n;
}

static const char *basename_of(const char *p) {
	const char *s = strrchr(p, '/');
	return s ? s + 1 : p;
}

int main(int argc, char **argv) {
	const char *mods, *archive;
	char **files;
	int nfiles, i;
	char op = 0;
	if (argc < 3) die("usage: boot-ar <[cqrxtds]...> archive [members...]", 0);
	mods = argv[1];
	while (*mods == '-') mods++;
	archive = argv[2];
	files = argv + 3;
	nfiles = argc - 3;
	/* x/t/d select an explicit op; any other modifier combination
	 * (c, r, q, s) means create/replace/append, handled as op 0. */
	for (i = 0; mods[i]; i++)
		if (mods[i] == 'x' || mods[i] == 't' || mods[i] == 'd') op = mods[i];

	if (op == 0) {
		/* create / replace / quick-append: merge with existing members,
		 * dropping any whose basename is being (re)added. */
		Member *ex = 0;
		int nex = 0, j, nout = 0, cap;
		Member *out;
		FILE *t = fopen(archive, "rb");
		if (t) { fclose(t); nex = read_archive(archive, &ex); }
		cap = nex + nfiles + 1;
		out = xmalloc(cap * sizeof(Member));
		for (j = 0; j < nex; j++) {
			int drop = 0, k;
			for (k = 0; k < nfiles; k++)
				if (strcmp(ex[j].base, basename_of(files[k])) == 0) { drop = 1; break; }
			if (!drop) out[nout++] = ex[j];
		}
		for (j = 0; j < nfiles; j++) {
			long flen;
			unsigned char *d = slurp(files[j], &flen);
			if (!d) die("cannot read member", files[j]);
			out[nout].base = (char *) basename_of(files[j]);
			out[nout].data = d;
			out[nout].len = flen;
			nout++;
		}
		write_archive(archive, out, nout);
		return 0;
	}
	if (op == 't') {
		Member *m; int n = read_archive(archive, &m);
		for (i = 0; i < n; i++) printf("%s\n", m[i].base);
		return 0;
	}
	if (op == 'x') {
		Member *m; int n = read_archive(archive, &m);
		for (i = 0; i < n; i++) {
			int want = (nfiles == 0), k;
			for (k = 0; k < nfiles; k++)
				if (strcmp(m[i].base, files[k]) == 0) { want = 1; break; }
			if (!want) continue;
			{
				FILE *f = fopen(m[i].base, "wb");
				if (!f) die("cannot extract", m[i].base);
				fwrite(m[i].data, 1, m[i].len, f);
				fclose(f);
			}
		}
		return 0;
	}
	if (op == 'd') {
		Member *m; int n = read_archive(archive, &m), nout = 0, j;
		Member *out = xmalloc((n ? n : 1) * sizeof(Member));
		for (i = 0; i < n; i++) {
			int drop = 0;
			for (j = 0; j < nfiles; j++)
				if (strcmp(m[i].base, files[j]) == 0) { drop = 1; break; }
			if (!drop) out[nout++] = m[i];
		}
		write_archive(archive, out, nout);
		return 0;
	}
	return 0;
}
