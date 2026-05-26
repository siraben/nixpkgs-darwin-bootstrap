/* Translate M1-macro-assembler output to hex2 input.  Mirrors
 * scripts/stage0/m1-to-hex2.pl and replaces it as a stage0-faithful
 * Mach-O binary compiled via phase5-m2 → phase9-m1 → phase10-hex2.
 *
 * Recognizes the small subset of M1/hex2 tokens that elf64-to-m1 emits:
 *   !0xXX (5 chars)  →  raw hex byte XX (uppercase)
 *   %LABEL / &LABEL  →  passthrough (4-byte references resolved by hex2)
 *   :LABEL           →  passthrough; may trigger --align-label padding
 *   anything else    →  passthrough (single byte / literal hex)
 *
 * Usage:
 *   m1-to-hex2 [--architecture <a>] [--little-endian|--big-endian]
 *              [--base-address <addr>] [--align-label NAME=ADDR ...]
 *              -f <file> [-f <file> ...] -o <out>
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>

#define MAX_FILES 64
#define MAX_ALIGN_LABELS 64
#define MAX_LINE 8192
#define MAX_TOKEN 1024
#define MAX_TOKENS_PER_LINE 256

/* Globals: argv-parsed state.  M2-Planet's codegen for global arrays of
 * pointers is unreliable on Darwin Mach-O, so use heap-allocated tables
 * via calloc — same pattern upstream stage0 mescc-tools/Kaem uses. */
int base_address;
char** files;
int nfiles;
char* output_path;
char** align_names;
int* align_values;
int n_aligns;

/* Output state. */
FILE* outfp;
int address;

/* Per-line scratch buffers — heap-allocated via calloc since M2-Planet
 * codegen for global char[] storage is also unreliable. */
char* line;
char* tok;

int hex_digit_value(char c)
{
	if(c >= '0' && c <= '9') return c - '0';
	if(c >= 'a' && c <= 'f') return c - 'a' + 10;
	if(c >= 'A' && c <= 'F') return c - 'A' + 10;
	return -1;
}

/* Parse 0xNN or decimal integer. */
int parse_int(char* s)
{
	int result;
	int sign;
	int d;
	result = 0;
	sign = 1;
	if(s[0] == '-') { sign = -1; s = s + 1; }
	if(s[0] == '0' && (s[1] == 'x' || s[1] == 'X'))
	{
		s = s + 2;
		while(s[0] != 0)
		{
			d = hex_digit_value(s[0]);
			if(d < 0) { fputs("bad hex digit\n", stderr); exit(1); }
			result = result * 16 + d;
			s = s + 1;
		}
	}
	else
	{
		while(s[0] != 0)
		{
			if(s[0] < '0' || s[0] > '9') { fputs("bad decimal digit\n", stderr); exit(1); }
			result = result * 10 + (s[0] - '0');
			s = s + 1;
		}
	}
	return sign * result;
}

/* Find first '=' in string; -1 if none. */
int find_eq(char* s)
{
	int i;
	i = 0;
	while(s[i] != 0)
	{
		if(s[i] == '=') return i;
		i = i + 1;
	}
	return -1;
}

/* Substring [start, end) into newly malloc'd buffer with NUL terminator. */
char* strndup_local(char* s, int len)
{
	char* r;
	int i;
	r = calloc(len + 1, sizeof(char));
	i = 0;
	while(i < len) { r[i] = s[i]; i = i + 1; }
	r[len] = 0;
	return r;
}

/* Lookup align label value by name; returns 1 + value (or 0 if not found). */
int align_lookup(char* name)
{
	int i;
	int j;
	int ok;
	i = 0;
	while(i < n_aligns)
	{
		ok = 1;
		j = 0;
		while(align_names[i][j] != 0 || name[j] != 0)
		{
			if(align_names[i][j] != name[j]) { ok = 0; }
			if(align_names[i][j] == 0 || name[j] == 0) { break; }
			j = j + 1;
		}
		if(align_names[i][j] != name[j]) ok = 0;
		if(ok) return 1 + align_values[i];
		i = i + 1;
	}
	return 0;
}

/* Convert a 4-bit nibble to uppercase hex char. */
char hex_char(int n)
{
	if(n < 10) return '0' + n;
	return 'A' + (n - 10);
}

void write_padding(int target)
{
	int line_count;
	int high;
	int low;
	if(address > target)
	{
		fputs("align target before current address\n", stderr);
		exit(1);
	}
	line_count = 0;
	while(address < target)
	{
		if(line_count > 0) fputc(' ', outfp);
		fputc('0', outfp);
		fputc('0', outfp);
		address = address + 1;
		line_count = line_count + 1;
		if(line_count == 16)
		{
			fputc('\n', outfp);
			line_count = 0;
		}
	}
	if(line_count > 0) fputc('\n', outfp);
}

/* Compute hex2 token width after translation:
 *  4 for %LABEL / &LABEL
 *  0 for :LABEL
 *  1 otherwise (single hex byte, or single-byte after !0xXX translation)
 *
 * Used to advance address counter — for align-label padding to match. */
int translated_width(char* tok)
{
	if(tok[0] == '%' || tok[0] == '&') return 4;
	if(tok[0] == ':') return 0;
	return 1;
}

/* If tok matches '!0xXX' (5 chars), strip the '!0x' prefix and emit the
 * remaining two chars uppercased — matches perl/python which trust the
 * token shape without re-validating the hex digits.  Otherwise emit
 * the token verbatim. */
void emit_token(char* tok, int len)
{
	int i;
	char c;
	if(len == 5 && tok[0] == '!' && tok[1] == '0' && tok[2] == 'x')
	{
		c = tok[3];
		if(c >= 'a' && c <= 'z') c = c - 'a' + 'A';
		fputc(c, outfp);
		c = tok[4];
		if(c >= 'a' && c <= 'z') c = c - 'a' + 'A';
		fputc(c, outfp);
		return;
	}
	i = 0;
	while(i < len) { fputc(tok[i], outfp); i = i + 1; }
}

/* Process a single input file. */
void process_file(char* path)
{
	FILE* in;
	int line_len;
	int c;
	int i;
	int tok_len;
	int first_token;
	int target;

	in = fopen(path, "r");
	if(in == NULL)
	{
		fputs("cannot open input file: ", stderr);
		fputs(path, stderr);
		fputc('\n', stderr);
		exit(1);
	}

	line_len = 0;
	c = fgetc(in);
	while(c != -1)
	{
		if(c == '\n')
		{
			line[line_len] = 0;
			/* Tokenize line. */
			i = 0;
			/* Skip leading whitespace. */
			while(line[i] == ' ' || line[i] == '\t') i = i + 1;
			if(line[i] == 0)
			{
				fputc('\n', outfp);
			}
			else
			{
				first_token = 1;
				while(line[i] != 0)
				{
					tok_len = 0;
					while(line[i] != 0 && line[i] != ' ' && line[i] != '\t')
					{
						tok[tok_len] = line[i];
						tok_len = tok_len + 1;
						i = i + 1;
					}
					tok[tok_len] = 0;
					/* :LABEL with align target → emit padding + label. */
					if(tok_len > 0 && tok[0] == ':')
					{
						target = align_lookup(tok + 1);
						if(target > 0)
						{
							if(!first_token) fputc('\n', outfp);
							write_padding(target - 1);
							first_token = 1;
						}
					}
					if(!first_token) fputc(' ', outfp);
					emit_token(tok, tok_len);
					address = address + translated_width(tok);
					first_token = 0;
					/* Skip whitespace before next token. */
					while(line[i] == ' ' || line[i] == '\t') i = i + 1;
				}
				fputc('\n', outfp);
			}
			line_len = 0;
		}
		else
		{
			if(line_len < MAX_LINE - 1)
			{
				line[line_len] = c;
				line_len = line_len + 1;
			}
		}
		c = fgetc(in);
	}
	/* Last line might not end with newline. */
	if(line_len > 0)
	{
		line[line_len] = 0;
		i = 0;
		while(line[i] == ' ' || line[i] == '\t') i = i + 1;
		if(line[i] != 0)
		{
			first_token = 1;
			while(line[i] != 0)
			{
				tok_len = 0;
				while(line[i] != 0 && line[i] != ' ' && line[i] != '\t')
				{
					tok[tok_len] = line[i];
					tok_len = tok_len + 1;
					i = i + 1;
				}
				tok[tok_len] = 0;
				if(tok_len > 0 && tok[0] == ':')
				{
					target = align_lookup(tok + 1);
					if(target > 0)
					{
						if(!first_token) fputc('\n', outfp);
						write_padding(target - 1);
						first_token = 1;
					}
				}
				if(!first_token) fputc(' ', outfp);
				emit_token(tok, tok_len);
				address = address + translated_width(tok);
				first_token = 0;
				while(line[i] == ' ' || line[i] == '\t') i = i + 1;
			}
			fputc('\n', outfp);
		}
	}
	fclose(in);
}

int streq(char* a, char* b)
{
	int i;
	i = 0;
	while(a[i] == b[i])
	{
		if(a[i] == 0) return 1;
		i = i + 1;
	}
	return 0;
}

int main(int argc, char** argv)
{
	int i;
	char* kv;
	int eq;

	base_address = 0;
	nfiles = 0;
	output_path = NULL;
	n_aligns = 0;
	files = calloc(MAX_FILES, sizeof(char*));
	align_names = calloc(MAX_ALIGN_LABELS, sizeof(char*));
	align_values = calloc(MAX_ALIGN_LABELS, sizeof(int));
	line = calloc(MAX_LINE, sizeof(char));
	tok = calloc(MAX_TOKEN, sizeof(char));

	i = 1;
	while(i < argc)
	{
		if(streq(argv[i], "--architecture"))
		{
			i = i + 2;
		}
		else if(streq(argv[i], "--little-endian") || streq(argv[i], "--big-endian"))
		{
			i = i + 1;
		}
		else if(streq(argv[i], "--base-address"))
		{
			base_address = parse_int(argv[i + 1]);
			i = i + 2;
		}
		else if(streq(argv[i], "--align-label"))
		{
			kv = argv[i + 1];
			eq = find_eq(kv);
			if(eq < 0) { fputs("invalid --align-label value\n", stderr); exit(1); }
			align_names[n_aligns] = strndup_local(kv, eq);
			align_values[n_aligns] = parse_int(kv + eq + 1);
			n_aligns = n_aligns + 1;
			i = i + 2;
		}
		else if(streq(argv[i], "-f") || streq(argv[i], "--file"))
		{
			files[nfiles] = argv[i + 1];
			nfiles = nfiles + 1;
			i = i + 2;
		}
		else if(streq(argv[i], "-o") || streq(argv[i], "--output"))
		{
			output_path = argv[i + 1];
			i = i + 2;
		}
		else
		{
			fputs("unknown arg: ", stderr);
			fputs(argv[i], stderr);
			fputc('\n', stderr);
			exit(1);
		}
	}

	if(nfiles == 0) { fputs("no -f files\n", stderr); exit(1); }
	if(output_path == NULL) { fputs("no -o output\n", stderr); exit(1); }

	outfp = fopen(output_path, "w");
	if(outfp == NULL) { fputs("cannot open output file\n", stderr); exit(1); }

	address = base_address;

	i = 0;
	while(i < nfiles)
	{
		process_file(files[i]);
		i = i + 1;
	}

	fclose(outfp);
	return 0;
}
