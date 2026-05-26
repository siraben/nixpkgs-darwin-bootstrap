/* Darwin-specific post-link patch for hex2-produced Mach-O binaries.
 * Mirrors scripts/stage0/hex2-data-relocs.pl; replaces it as a
 * stage0-faithful Mach-O binary compiled via phase5-m2 → phase9-m1
 * → phase10-hex2 (see phase11c-hex2-data-relocs.nix).
 *
 * hex2 emits a flat layout where references assume code and data are
 * contiguous in VM (TEXT at BASE=0x600000, data immediately after).
 * Darwin's loader splits TEXT and DATA into separate segments at
 * DATA_VM=0xE00000 with a file gap (DATA_FILE_OFFSET=0x800000), so
 * every reference whose target lies past the first :ELF_data or
 * :HEX2_data label needs its disp32 (relative) or 4-byte absolute
 * slot recomputed.
 *
 * Usage: hex2-data-relocs patch <source.hex2> <binary>
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>

/* Constants — mirror perl. */
#define BASE             0x600000
#define ENTRY_OFFSET     0x400
#define DATA_FILE_OFFSET 0x800000
#define DATA_VM          0xE00000

/* Capacity for labels/refs/name pool.  Tuned for tinycc-self.hex2
 * (~50MB input, ~250K labels, ~100K refs, ~5MB names). */
#define MAX_LABELS    524288     /* 512K — power of 2 for cheap hashing */
#define MAX_REFS      524288
#define NAME_POOL     33554432    /* 32MB */
#define TOK_BUF       4096

/* Parallel arrays for the label table. */
int*  label_name_pool_off;  /* offset into name_pool */
int*  label_name_len;
int*  label_offset;
int   n_labels;

/* Parallel arrays for relative references (%name). */
int*  rel_name_pool_off;
int*  rel_name_len;
int*  rel_tok_offset;
int   n_relrefs;

/* Parallel arrays for absolute references (&name). */
int*  abs_name_pool_off;
int*  abs_name_len;
int*  abs_tok_offset;
int   n_absrefs;

char* name_pool;
int   name_pool_len;

int  static_offset;        /* -1 sentinel until first :ELF_data / :HEX2_data */

/* Token scratch. */
char* tok;
int   tok_len;

int hex_digit_value(char c)
{
	if(c >= '0' && c <= '9') return c - '0';
	if(c >= 'a' && c <= 'f') return c - 'a' + 10;
	if(c >= 'A' && c <= 'F') return c - 'A' + 10;
	return -1;
}

int is_decimal_digit(char c)
{
	if(c >= '0' && c <= '9') return 1;
	return 0;
}

/* Returns 1 iff tok looks numeric: [+-]?(0x[0-9A-Fa-f]+|[0-9]+) */
int numeric_reference(char* s, int len)
{
	int i;
	int d;
	i = 0;
	if(len > 0 && (s[0] == '-' || s[0] == '+')) i = 1;
	if(len - i <= 0) return 0;
	if(len - i >= 2 && s[i] == '0' && (s[i+1] == 'x' || s[i+1] == 'X'))
	{
		i = i + 2;
		if(i >= len) return 0;
		while(i < len)
		{
			d = hex_digit_value(s[i]);
			if(d < 0) return 0;
			i = i + 1;
		}
		return 1;
	}
	while(i < len)
	{
		if(!is_decimal_digit(s[i])) return 0;
		i = i + 1;
	}
	return 1;
}

/* True iff substring [start, start+len) of s is exactly the C-string c. */
int str_eq_n(char* s, int start, int len, char* c)
{
	int i;
	i = 0;
	while(i < len)
	{
		if(c[i] == 0) return 0;
		if(s[start + i] != c[i]) return 0;
		i = i + 1;
	}
	if(c[len] != 0) return 0;
	return 1;
}

/* Hex2 token width. */
int hex2_width(char* s, int len)
{
	int i;
	int even;
	int d;
	if(len == 0) return 0;
	if(s[0] == '!') return 1;
	if(s[0] == '@' || s[0] == '$') return 2;
	if(s[0] == '%' || s[0] == '&') return 4;
	/* All-hex-digits, even length → len/2 bytes. */
	even = (len % 2 == 0);
	i = 0;
	while(i < len)
	{
		d = hex_digit_value(s[i]);
		if(d < 0) return 0;
		i = i + 1;
	}
	if(even) return len / 2;
	return 0;
}

/* Stash a name (s[0..len)) into name_pool, return its offset. */
int stash_name(char* s, int len)
{
	int off;
	int i;
	if(name_pool_len + len >= NAME_POOL)
	{
		fputs("name pool exhausted\n", stderr);
		exit(1);
	}
	off = name_pool_len;
	i = 0;
	while(i < len)
	{
		name_pool[off + i] = s[i];
		i = i + 1;
	}
	name_pool_len = name_pool_len + len;
	return off;
}

void record_label(int name_off, int name_len, int offset)
{
	if(n_labels >= MAX_LABELS) { fputs("too many labels\n", stderr); exit(1); }
	label_name_pool_off[n_labels] = name_off;
	label_name_len[n_labels] = name_len;
	label_offset[n_labels] = offset;
	n_labels = n_labels + 1;
}

void record_relref(int name_off, int name_len, int tok_off)
{
	if(n_relrefs >= MAX_REFS) { fputs("too many rel refs\n", stderr); exit(1); }
	rel_name_pool_off[n_relrefs] = name_off;
	rel_name_len[n_relrefs] = name_len;
	rel_tok_offset[n_relrefs] = tok_off;
	n_relrefs = n_relrefs + 1;
}

void record_absref(int name_off, int name_len, int tok_off)
{
	if(n_absrefs >= MAX_REFS) { fputs("too many abs refs\n", stderr); exit(1); }
	abs_name_pool_off[n_absrefs] = name_off;
	abs_name_len[n_absrefs] = name_len;
	abs_tok_offset[n_absrefs] = tok_off;
	n_absrefs = n_absrefs + 1;
}

/* Linear scan label table looking for matching name.  Returns offset or
 * -1 if not found. */
int lookup_label(int ref_pool_off, int ref_len)
{
	int i;
	int eq;
	int j;
	int lpool;
	int llen;
	i = 0;
	while(i < n_labels)
	{
		llen = label_name_len[i];
		if(llen == ref_len)
		{
			lpool = label_name_pool_off[i];
			eq = 1;
			j = 0;
			while(j < ref_len)
			{
				if(name_pool[lpool + j] != name_pool[ref_pool_off + j])
				{
					eq = 0;
					break;
				}
				j = j + 1;
			}
			if(eq) return label_offset[i];
		}
		i = i + 1;
	}
	return -1;
}

/* Process a token from the parser pass. */
void handle_token(int* offset)
{
	int width;
	int name_off;
	char c;
	if(tok_len == 0) return;
	c = tok[0];
	if(c == ':')
	{
		/* Label definition. */
		name_off = stash_name(tok + 1, tok_len - 1);
		record_label(name_off, tok_len - 1, *offset);
		if(static_offset == -1)
		{
			if(str_eq_n(tok + 1, 0, tok_len - 1, "ELF_data") ||
			   str_eq_n(tok + 1, 0, tok_len - 1, "HEX2_data"))
			{
				static_offset = *offset;
			}
		}
		/* Labels are 0-width. */
		return;
	}
	if(c == '%')
	{
		if(!numeric_reference(tok + 1, tok_len - 1))
		{
			name_off = stash_name(tok + 1, tok_len - 1);
			record_relref(name_off, tok_len - 1, *offset);
		}
		*offset = *offset + 4;
		return;
	}
	if(c == '&')
	{
		if(!numeric_reference(tok + 1, tok_len - 1))
		{
			name_off = stash_name(tok + 1, tok_len - 1);
			record_absref(name_off, tok_len - 1, *offset);
		}
		*offset = *offset + 4;
		return;
	}
	/* Plain byte/hex token: advance address by hex2_width. */
	width = hex2_width(tok, tok_len);
	if(width == 0)
	{
		fputs("untranslated hex2 token: ", stderr);
		fwrite(tok, 1, tok_len, stderr);
		fputc('\n', stderr);
		exit(1);
	}
	*offset = *offset + width;
}

/* Parse the source hex2 file, populating tables + static_offset. */
void parse_source(char* path)
{
	FILE* in;
	int c;
	int offset;
	int in_comment;
	in = fopen(path, "r");
	if(in == NULL)
	{
		fputs("cannot open source: ", stderr);
		fputs(path, stderr);
		fputc('\n', stderr);
		exit(1);
	}
	offset = 0;
	tok_len = 0;
	in_comment = 0;
	c = fgetc(in);
	while(c != -1)
	{
		if(in_comment)
		{
			if(c == '\n') in_comment = 0;
		}
		else if(c == '#')
		{
			/* Flush any in-progress token first. */
			if(tok_len > 0)
			{
				handle_token(&offset);
				tok_len = 0;
			}
			in_comment = 1;
		}
		else if(c == ' ' || c == '\t' || c == '\n' || c == '\r')
		{
			if(tok_len > 0)
			{
				handle_token(&offset);
				tok_len = 0;
			}
		}
		else
		{
			if(tok_len < TOK_BUF - 1)
			{
				tok[tok_len] = c;
				tok_len = tok_len + 1;
			}
		}
		c = fgetc(in);
	}
	if(tok_len > 0)
	{
		handle_token(&offset);
		tok_len = 0;
	}
	fclose(in);
}

/* Pack a 4-byte little-endian signed value into dest[0..4). */
void pack_le32(char* dest, int value)
{
	dest[0] = value & 0xFF;
	dest[1] = (value >> 8) & 0xFF;
	dest[2] = (value >> 16) & 0xFF;
	dest[3] = (value >> 24) & 0xFF;
}

/* Open, mmap-like load, patch, write back. */
void patch_binary(char* bin_path)
{
	FILE* bf;
	char* bytes;
	int bin_size;
	int total_size;
	int static_file_offset;
	int static_length;
	int i;
	int tgt;
	int disp_pos;
	int next_instr;
	int target;
	int disp;
	int pos;
	int new_target;

	bf = fopen(bin_path, "r");
	if(bf == NULL) { fputs("open bin\n", stderr); exit(1); }

	/* Determine size: read until EOF into a generous buffer. */
	bin_size = 0;
	bytes = calloc(DATA_FILE_OFFSET + 8 * 1024 * 1024, sizeof(char));
	if(bytes == NULL) { fputs("calloc bytes\n", stderr); exit(1); }
	{
		int c;
		c = fgetc(bf);
		while(c != -1)
		{
			bytes[bin_size] = c;
			bin_size = bin_size + 1;
			c = fgetc(bf);
		}
	}
	fclose(bf);

	static_file_offset = ENTRY_OFFSET + static_offset;
	static_length = bin_size - static_file_offset;
	total_size = bin_size;
	if(total_size < DATA_FILE_OFFSET + static_length)
		total_size = DATA_FILE_OFFSET + static_length;

	/* Backward copy static block from src→dst (overlapping ranges). */
	i = static_length - 1;
	while(i >= 0)
	{
		bytes[DATA_FILE_OFFSET + i] = bytes[static_file_offset + i];
		i = i - 1;
	}

	/* Relative refs: patch disp32 if target is in data segment. */
	i = 0;
	while(i < n_relrefs)
	{
		tgt = lookup_label(rel_name_pool_off[i], rel_name_len[i]);
		if(tgt >= 0 && tgt >= static_offset)
		{
			disp_pos = ENTRY_OFFSET + rel_tok_offset[i];
			next_instr = BASE + disp_pos + 4;
			target = DATA_VM + (tgt - static_offset);
			disp = target - next_instr;
			pack_le32(bytes + disp_pos, disp);
		}
		i = i + 1;
	}

	/* Absolute refs: write absolute address. */
	i = 0;
	while(i < n_absrefs)
	{
		tgt = lookup_label(abs_name_pool_off[i], abs_name_len[i]);
		if(tgt >= 0)
		{
			if(tgt < static_offset)
			{
				new_target = BASE + ENTRY_OFFSET + tgt;
			}
			else
			{
				new_target = DATA_VM + (tgt - static_offset);
			}
			if(abs_tok_offset[i] >= static_offset)
			{
				pos = DATA_FILE_OFFSET + (abs_tok_offset[i] - static_offset);
			}
			else
			{
				pos = ENTRY_OFFSET + abs_tok_offset[i];
			}
			pack_le32(bytes + pos, new_target);
		}
		i = i + 1;
	}

	/* Write back. */
	bf = fopen(bin_path, "w");
	if(bf == NULL) { fputs("reopen bin for write\n", stderr); exit(1); }
	i = 0;
	while(i < total_size)
	{
		fputc(bytes[i], bf);
		i = i + 1;
	}
	fclose(bf);
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
	if(argc != 4 || !streq(argv[1], "patch"))
	{
		fputs("usage: hex2-data-relocs patch <source.hex2> <binary>\n", stderr);
		exit(1);
	}

	/* Allocate the large tables on heap (M2-Planet's BSS layout for big
	 * globals isn't reliable on Darwin; calloc keeps us out of trouble). */
	label_name_pool_off = calloc(MAX_LABELS, sizeof(int));
	label_name_len      = calloc(MAX_LABELS, sizeof(int));
	label_offset        = calloc(MAX_LABELS, sizeof(int));
	rel_name_pool_off   = calloc(MAX_REFS, sizeof(int));
	rel_name_len        = calloc(MAX_REFS, sizeof(int));
	rel_tok_offset      = calloc(MAX_REFS, sizeof(int));
	abs_name_pool_off   = calloc(MAX_REFS, sizeof(int));
	abs_name_len        = calloc(MAX_REFS, sizeof(int));
	abs_tok_offset      = calloc(MAX_REFS, sizeof(int));
	name_pool           = calloc(NAME_POOL, sizeof(char));
	tok                 = calloc(TOK_BUF, sizeof(char));
	n_labels   = 0;
	n_relrefs  = 0;
	n_absrefs  = 0;
	name_pool_len = 0;
	static_offset = -1;

	parse_source(argv[2]);
	if(static_offset == -1)
	{
		fputs("static data label not found\n", stderr);
		exit(1);
	}
	patch_binary(argv[3]);
	return 0;
}
