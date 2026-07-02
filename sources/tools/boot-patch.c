/* boot-patch — minimal unified-diff applier for the from-seed chain.
 *
 * Replaces host /usr/bin/patch in the bootstrap.  Written in the
 * M2-Planet C subset so it can be built at step 14b, right after the
 * stage0 toolchain and before anything that needs source patching
 * (mes at step 15, tinycc at step 22, gcc at steps 47/48/51/53b).
 * The same file compiles unchanged with any hosted C compiler, which
 * is how the test suite cross-checks it against GNU patch.
 *
 * Interface (the subset the chain uses):
 *   boot-patch -p1 [-d DIR] [-s] [PATCHFILE]
 * PATCHFILE defaults to standard input.  -pN strips N leading path
 * components from the diff headers; -d prepends DIR to every target
 * path (no chdir, so M2libc needs no cwd support); -s is accepted and
 * ignored (silent-flag compatibility).
 *
 * Supported input: unified diffs that MODIFY existing files.  Every
 * committed patch in this repo is such a diff — no file creation or
 * deletion (no /dev/null headers), no renames, no binary hunks, no
 * "\ No newline at end of file" markers.  The applier fails loudly on
 * anything outside that set rather than guessing.
 *
 * Hunk placement: a hunk is matched by its full old text (context +
 * deletions), first at the header-declared line, then scanning
 * outward, never before the end of the previous hunk.  If the old
 * text is absent but the hunk's NEW text is already in place, the
 * hunk is skipped — re-running boot-patch on a patched tree is a
 * no-op, which the idempotent steps (53b) rely on.
 *
 * M2-Planet subset rules observed here: no structs, unions, typedefs,
 * ternary, switch, ++/--, compound assignment, or short-circuit
 * boolean assumptions (M2-Planet evaluates both sides of && and ||).
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ---- globals ---------------------------------------------------- */

int strip_p;            /* -pN */
char* dest_dir;         /* -d DIR or NULL */

char** plines;          /* patch, split into lines */
int pcount;

char** olines;          /* current target file, split into lines */
int ocount;
int otrail;             /* original file ended with newline */

char** rlines;          /* result being built */
int rcount;

char numbuf[32];
int read_size;
int split_count;
int parsed_int;

/* ---- small helpers ---------------------------------------------- */

void die2(char* a, char* b)
{
	fputs("boot-patch: ", stderr);
	fputs(a, stderr);
	if(NULL != b) fputs(b, stderr);
	fputc('\n', stderr);
	exit(1);
}

char* itoa10(int v)
{
	int i = 30;
	int neg = 0;
	numbuf[31] = 0;
	if(0 == v)
	{
		numbuf[30] = '0';
		return numbuf + 30;
	}
	if(v < 0)
	{
		neg = 1;
		v = 0 - v;
	}
	while(v > 0)
	{
		numbuf[i] = '0' + (v % 10);
		v = v / 10;
		i = i - 1;
	}
	if(1 == neg)
	{
		numbuf[i] = '-';
		i = i - 1;
	}
	return numbuf + i + 1;
}

int starts_with(char* s, char* prefix)
{
	int n = strlen(prefix);
	if(0 == strncmp(s, prefix, n)) return 1;
	return 0;
}

/* ---- file reading ----------------------------------------------- */

char* read_file(char* path)
{
	FILE* f = fopen(path, "r");
	int cap = 65536;
	int size = 0;
	int c;
	char* buf;
	if(NULL == f) return NULL;
	buf = malloc(cap);
	if(NULL == buf) die2("out of memory reading ", path);
	c = fgetc(f);
	while(EOF != c)
	{
		if(size + 1 >= cap)
		{
			cap = cap * 2;
			buf = realloc(buf, cap);
			if(NULL == buf) die2("out of memory reading ", path);
		}
		buf[size] = c;
		size = size + 1;
		c = fgetc(f);
	}
	buf[size] = 0;
	fclose(f);
	read_size = size;
	return buf;
}

char* read_stdin()
{
	int cap = 65536;
	int size = 0;
	int c;
	char* buf = malloc(cap);
	if(NULL == buf) die2("out of memory", NULL);
	c = fgetc(stdin);
	while(EOF != c)
	{
		if(size + 1 >= cap)
		{
			cap = cap * 2;
			buf = realloc(buf, cap);
			if(NULL == buf) die2("out of memory", NULL);
		}
		buf[size] = c;
		size = size + 1;
		c = fgetc(stdin);
	}
	buf[size] = 0;
	read_size = size;
	return buf;
}

/* Split buf into NUL-terminated lines in place.  Returns the line
 * vector; stores the count through count_out. */
char** split_lines(char* buf, int size)
{
	int n = 0;
	int i = 0;
	char** v;
	while(i < size)
	{
		if('\n' == buf[i]) n = n + 1;
		i = i + 1;
	}
	/* a final line without newline still counts (nested if: no
	 * short-circuit under M2-Planet, buf[-1] must never be read) */
	if(size > 0)
		if('\n' != buf[size - 1]) n = n + 1;
	v = malloc((n + 1) * sizeof(char*));
	if(NULL == v) die2("out of memory", NULL);
	n = 0;
	i = 0;
	while(i < size)
	{
		v[n] = buf + i;
		n = n + 1;
		while(i < size)
		{
			if('\n' == buf[i]) break;
			i = i + 1;
		}
		if(i < size)
		{
			buf[i] = 0;
			i = i + 1;
		}
	}
	v[n] = NULL;
	split_count = n;
	return v;
}

/* ---- diff header parsing ---------------------------------------- */

/* Extract the target path from a "--- name<TAB>stamp" header body:
 * terminate at tab, strip strip_p leading components, prepend
 * dest_dir.  Returns a malloc'd path. */
char* parse_name(char* s)
{
	char* out;
	char* q;
	int i = 0;
	int comp = strip_p;
	int len;
	/* copy up to tab or end */
	len = strlen(s);
	q = malloc(len + 1);
	if(NULL == q) die2("out of memory", NULL);
	while(0 != s[i])
	{
		if('\t' == s[i]) break;
		q[i] = s[i];
		i = i + 1;
	}
	q[i] = 0;
	/* strip leading components */
	while(comp > 0)
	{
		char* slash = strchr(q, '/');
		if(NULL == slash) die2("cannot strip path components from ", q);
		q = slash + 1;
		comp = comp - 1;
	}
	if(0 == q[0]) die2("empty path after -p strip", NULL);
	if(NULL == dest_dir) return q;
	out = malloc(strlen(dest_dir) + strlen(q) + 2);
	if(NULL == out) die2("out of memory", NULL);
	strcpy(out, dest_dir);
	strcat(out, "/");
	strcat(out, q);
	return out;
}

/* Parse a decimal integer at s; stores the value through val_out and
 * returns the first unconsumed position. */
char* parse_int(char* s)
{
	int v = 0;
	if(s[0] < '0') die2("bad number in hunk header", NULL);
	if(s[0] > '9') die2("bad number in hunk header", NULL);
	while(s[0] >= '0')
	{
		if(s[0] > '9') break;
		v = v * 10 + (s[0] - '0');
		s = s + 1;
	}
	parsed_int = v;
	return s;
}

/* ---- hunk matching ----------------------------------------------- */

/* Do the n lines at olines[pos..] equal hunk[0..n)? */
int match_at(int pos, char** hunk, int n)
{
	int i = 0;
	if(pos < 0) return 0;
	if(pos + n > ocount) return 0;
	while(i < n)
	{
		if(0 != strcmp(olines[pos + i], hunk[i])) return 0;
		i = i + 1;
	}
	return 1;
}

/* Find hunk (n lines) at or after floor, preferring positions close
 * to hint.  Returns the position or -1. */
int find_hunk(int hint, int floor, char** hunk, int n)
{
	int delta = 0;
	int cand;
	if(hint < floor) hint = floor;
	while(delta <= ocount)
	{
		cand = hint + delta;
		if(cand >= floor)
			if(match_at(cand, hunk, n)) return cand;
		cand = hint - delta;
		if(delta > 0)
			if(cand >= floor)
				if(match_at(cand, hunk, n)) return cand;
		delta = delta + 1;
	}
	return 0 - 1;
}

int iabs(int v)
{
	if(v < 0) return 0 - v;
	return v;
}

/* ---- output ------------------------------------------------------ */

void write_result(char* path)
{
	FILE* f = fopen(path, "w");
	int i = 0;
	if(NULL == f) die2("cannot write ", path);
	while(i < rcount)
	{
		fputs(rlines[i], f);
		if(i + 1 < rcount) fputc('\n', f);
		else if(1 == otrail) fputc('\n', f);
		i = i + 1;
	}
	fclose(f);
}

/* ---- main -------------------------------------------------------- */

int main(int argc, char** argv)
{
	char* patch_path = NULL;
	char* pbuf;
	int psize;
	int i;

	strip_p = 0;
	dest_dir = NULL;

	i = 1;
	while(i < argc)
	{
		char* a = argv[i];
		if(0 == strcmp(a, "-d"))
		{
			i = i + 1;
			if(i >= argc) die2("-d needs a directory", NULL);
			dest_dir = argv[i];
		}
		else if(0 == strcmp(a, "-s"))
		{
			/* silent: accepted for GNU patch compatibility */
		}
		else if('-' == a[0])
		{
			if('p' == a[1])
			{
				int j = 2;
				if(0 == a[2]) die2("bad -p option ", a);
				strip_p = 0;
				while(0 != a[j])
				{
					if(a[j] < '0') die2("bad -p option ", a);
					if(a[j] > '9') die2("bad -p option ", a);
					strip_p = strip_p * 10 + (a[j] - '0');
					j = j + 1;
				}
			}
			else if(0 != a[1])
			{
				die2("unknown option ", a);
			}
			else
			{
				if(NULL != patch_path) die2("more than one patch file", NULL);
				patch_path = a;
			}
		}
		else
		{
			if(NULL != patch_path) die2("more than one patch file", NULL);
			patch_path = a;
		}
		i = i + 1;
	}

	if(NULL == patch_path) pbuf = read_stdin();
	else
	{
		pbuf = read_file(patch_path);
		if(NULL == pbuf) die2("cannot read ", patch_path);
	}
	psize = read_size;
	plines = split_lines(pbuf, psize);
	pcount = split_count;

	i = 0;
	while(i < pcount)
	{
		char* path;
		char* obuf;
		int osize;
		int cur;
		int nfiles_hunks = 0;

		if(0 == starts_with(plines[i], "--- "))
		{
			/* skip diff/index/mode noise between file sections */
			i = i + 1;
			continue;
		}
		if(i + 1 >= pcount)
			die2("--- header without +++ header", NULL);
		if(0 == starts_with(plines[i + 1], "+++ "))
			die2("--- header without +++ header", NULL);
		if(starts_with(plines[i], "--- /dev/null"))
			die2("file creation/deletion patches are not supported", NULL);
		if(starts_with(plines[i + 1], "+++ /dev/null"))
			die2("file creation/deletion patches are not supported", NULL);
		path = parse_name(plines[i] + 4);
		i = i + 2;

		obuf = read_file(path);
		if(NULL == obuf) die2("cannot read target ", path);
		osize = read_size;
		otrail = 0;
		if(osize > 0)
			if('\n' == obuf[osize - 1]) otrail = 1;
		olines = split_lines(obuf, osize);
		ocount = split_count;

		rlines = malloc((ocount + pcount + 16) * sizeof(char*));
		if(NULL == rlines) die2("out of memory", NULL);
		rcount = 0;
		cur = 0;

		while(i < pcount)
		{
			char* h = plines[i] + 4;
			int oldstart;
			int oldcnt = 1;
			int newcnt = 1;
			char** oldl;
			char** newl;
			int on = 0;
			int nn = 0;
			int pos;
			int k;

			if(0 == starts_with(plines[i], "@@ -")) break;

			h = parse_int(h);
			oldstart = parsed_int;
			if(',' == h[0])
			{
				h = parse_int(h + 1);
				oldcnt = parsed_int;
			}
			while(' ' == h[0]) h = h + 1;
			if('+' != h[0]) die2("bad hunk header: ", plines[i]);
			h = parse_int(h + 1);
			if(',' == h[0])
			{
				h = parse_int(h + 1);
				newcnt = parsed_int;
			}
			i = i + 1;

			oldl = malloc((oldcnt + 1) * sizeof(char*));
			newl = malloc((newcnt + 1) * sizeof(char*));
			if(NULL == oldl) die2("out of memory", NULL);
			if(NULL == newl) die2("out of memory", NULL);

			while(1)
			{
				char* l;
				if(on >= oldcnt)
					if(nn >= newcnt) break;
				if(i >= pcount) die2("truncated hunk", NULL);
				l = plines[i];
				if(' ' == l[0])
				{
					/* context ("" is a trimmed blank context line) */
					char* body = l;
					body = l + 1;
					if(on >= oldcnt)
						die2("hunk longer than header counts", NULL);
					if(nn >= newcnt)
						die2("hunk longer than header counts", NULL);
					oldl[on] = body;
					newl[nn] = body;
					on = on + 1;
					nn = nn + 1;
				}
				else if(0 == l[0])
				{
					if(on >= oldcnt)
						die2("hunk longer than header counts", NULL);
					if(nn >= newcnt)
						die2("hunk longer than header counts", NULL);
					oldl[on] = l;
					newl[nn] = l;
					on = on + 1;
					nn = nn + 1;
				}
				else if('-' == l[0])
				{
					if(on >= oldcnt) die2("hunk longer than header counts", NULL);
					oldl[on] = l + 1;
					on = on + 1;
				}
				else if('+' == l[0])
				{
					if(nn >= newcnt) die2("hunk longer than header counts", NULL);
					newl[nn] = l + 1;
					nn = nn + 1;
				}
				else if('\\' == l[0])
				{
					die2("\"No newline at end of file\" is not supported", NULL);
				}
				else die2("unexpected line in hunk: ", l);
				i = i + 1;
			}

			/* Search for the hunk's OLD text (normal application)
			 * and its NEW text (hunk already applied).  With
			 * repetitive source an already-applied hunk's old text
			 * can still match somewhere else in the file, so when
			 * both match, trust whichever sits closer to the
			 * header-declared position. */
			pos = find_hunk(oldstart - 1, cur, oldl, oldcnt);
			{
				int pos_new = find_hunk(oldstart - 1, cur, newl, newcnt);
				int skip = 0;
				if(pos < 0)
				{
					if(pos_new < 0)
					{
						fputs("boot-patch: hunk at old line ", stderr);
						fputs(itoa10(oldstart), stderr);
						die2(" does not apply to ", path);
					}
				}
				if(pos < 0) skip = 1;
				else if(pos_new >= 0)
					if(iabs(pos_new - (oldstart - 1)) < iabs(pos - (oldstart - 1)))
						skip = 1;
				if(1 == skip)
				{
					/* emit through the already-patched region unchanged */
					while(cur < pos_new + newcnt)
					{
						rlines[rcount] = olines[cur];
						rcount = rcount + 1;
						cur = cur + 1;
					}
					nfiles_hunks = nfiles_hunks + 1;
					continue;
				}
			}

			while(cur < pos)
			{
				rlines[rcount] = olines[cur];
				rcount = rcount + 1;
				cur = cur + 1;
			}
			k = 0;
			while(k < newcnt)
			{
				rlines[rcount] = newl[k];
				rcount = rcount + 1;
				k = k + 1;
			}
			cur = pos + oldcnt;
			nfiles_hunks = nfiles_hunks + 1;
		}

		if(0 == nfiles_hunks) die2("no hunks for ", path);

		while(cur < ocount)
		{
			rlines[rcount] = olines[cur];
			rcount = rcount + 1;
			cur = cur + 1;
		}
		write_result(path);
		fputs("patching file ", stdout);
		fputs(path, stdout);
		fputc('\n', stdout);
	}

	return 0;
}
