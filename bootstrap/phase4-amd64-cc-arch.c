/* Port-and-patch helper for the phase-4 cc_arch translator.
 * Mirrors scripts/stage0/phase4-amd64-cc-arch.pl one-for-one;
 * replaces it as a stage0-faithful Mach-O binary compiled via
 * phase5-m2 → phase9-m1 → phase10-hex2.
 *
 *   port  <linux-source.hex2> <darwin-source.hex2>
 *     Apply a fixed list of opcode-level rewrites that turn the Linux
 *     x86_64 syscalls in cc_arch's source into Darwin syscalls.
 *   patch <source.hex2> <binary>
 *     Locate the fix_types lea marker, copy the static block to the
 *     Darwin DATA segment, then re-target every RIP-relative load /
 *     store that points into the moved static block.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>

#define BASE             0x600000
#define DATA_FILE_OFFSET 0x800000
#define DATA_VM          0xE00000
#define HEAP_VM          0xF00000

#define MAX_SOURCE 524288       /* 512KB — cc_arch-0-linux.hex2 is ~60KB */

char* source;
int   source_len;

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

/* Read whole file into source buffer.  Returns the number of bytes read. */
int load_file(char* path)
{
	FILE* f;
	int c;
	int n;
	f = fopen(path, "r");
	if(f == NULL) { fputs("cannot open input\n", stderr); exit(1); }
	n = 0;
	c = fgetc(f);
	while(c != -1)
	{
		if(n >= MAX_SOURCE - 1) { fputs("source too large\n", stderr); exit(1); }
		source[n] = c;
		n = n + 1;
		c = fgetc(f);
	}
	source[n] = 0;
	fclose(f);
	return n;
}

void write_source(char* path)
{
	FILE* f;
	int i;
	f = fopen(path, "w");
	if(f == NULL) { fputs("cannot open output\n", stderr); exit(1); }
	i = 0;
	while(i < source_len)
	{
		fputc(source[i], f);
		i = i + 1;
	}
	fclose(f);
}

/* Compare needle[0..nlen) with source[pos..pos+nlen).  Returns 1 if equal. */
int matches_at(int pos, char* needle, int nlen)
{
	int i;
	if(pos + nlen > source_len) return 0;
	i = 0;
	while(i < nlen)
	{
		if(source[pos + i] != needle[i]) return 0;
		i = i + 1;
	}
	return 1;
}

/* Find first occurrence of needle[0..nlen) starting at pos.  Returns
 * index or -1. */
int find_needle(int pos, char* needle, int nlen)
{
	int i;
	if(nlen == 0) return pos;
	i = pos;
	while(i + nlen <= source_len)
	{
		if(matches_at(i, needle, nlen)) return i;
		i = i + 1;
	}
	return -1;
}

/* In-place replace [start, start+old_len) with replacement[0..new_len).
 * Adjusts source_len. */
void splice(int start, int old_len, char* replacement, int new_len)
{
	int delta;
	int i;
	delta = new_len - old_len;
	if(delta > 0)
	{
		if(source_len + delta >= MAX_SOURCE) { fputs("splice overflow\n", stderr); exit(1); }
		i = source_len - 1;
		while(i >= start + old_len)
		{
			source[i + delta] = source[i];
			i = i - 1;
		}
	}
	else if(delta < 0)
	{
		i = start + old_len;
		while(i < source_len)
		{
			source[i + delta] = source[i];
			i = i + 1;
		}
	}
	i = 0;
	while(i < new_len)
	{
		source[start + i] = replacement[i];
		i = i + 1;
	}
	source_len = source_len + delta;
	source[source_len] = 0;
}

int strlen_local(char* s)
{
	int i;
	i = 0;
	while(s[i] != 0) i = i + 1;
	return i;
}

/* Replace first occurrence of `old` with `new`; die if not found. */
void replace_once(char* old, char* nw)
{
	int oldlen;
	int newlen;
	int pos;
	oldlen = strlen_local(old);
	newlen = strlen_local(nw);
	pos = find_needle(0, old, oldlen);
	if(pos < 0) { fputs("pattern not found\n", stderr); exit(1); }
	splice(pos, oldlen, nw, newlen);
}

/* Replace all occurrences. */
void replace_all(char* old, char* nw)
{
	int oldlen;
	int newlen;
	int pos;
	int cursor;
	oldlen = strlen_local(old);
	newlen = strlen_local(nw);
	cursor = 0;
	while(1)
	{
		pos = find_needle(cursor, old, oldlen);
		if(pos < 0) break;
		splice(pos, oldlen, nw, newlen);
		cursor = pos + newlen;
	}
}

/* Replace first occurrence of `old` with empty string. */
void remove_once(char* old)
{
	int oldlen;
	int pos;
	oldlen = strlen_local(old);
	pos = find_needle(0, old, oldlen);
	if(pos < 0) return;
	splice(pos, oldlen, "", 0);
}

void port_source(char* input_path, char* output_path)
{
	source_len = load_file(input_path);

	/* The 5-th instruction in the perl version: replace the malloc-like
	 * mmap syscall with a literal `mov r13, 0xF00000` (HEAP_VM).  The
	 * little-endian 8-byte hex literal is the same in every build, so
	 * embed it as a string constant. */
	replace_once("58\n5F\n5F\n", "4889F3\n488B7B08\n");
	replace_once("5F\n48C7C6\n41020000\n", "488B7B10\n48C7C6\n01060000\n");
	replace_once("48C7C0\n0C000000\n48C7C7\n00000000\n0F05\n4989C5\n",
	             "49BD\n0000F00000000000\n");
	replace_all("48C7C0\n02000000\n0F05", "48C7C0\n05000002\n0F05");
	replace_all("48C7C0\n00000000\n52\n48C7C2\n01000000\n51\n4153\n0F05",
	            "48C7C0\n03000002\n52\n48C7C2\n01000000\n51\n4153\n0F05");
	replace_all("48C7C0\n01000000\n52\n48C7C2\n01000000\n51\n4153\n0F05",
	            "48C7C0\n04000002\n52\n48C7C2\n01000000\n51\n4153\n0F05");
	remove_once("48C7C0\n0C000000\n51\n4153\n0F05\n415B\n59\n");
	replace_all("48C7C0\n3C000000\n0F05", "48C7C0\n01000002\n0F05");
	replace_once(":match\n53\n51\n52\n4889C1\n4889DA\n:match_Loop\n",
	             ":match\n53\n51\n52\n4889C1\n4889DA\n4881F9\n00100000\n0F8C\n%match_False\n4881FA\n00100000\n0F8C\n%match_False\n:match_Loop\n");

	write_source(output_path);
}

/* === patch mode === */

#define MAX_BIN 67108864  /* 64MB — cc_arch-darwin output is ~50MB */
char* bytes;
int   bin_size;

int load_binary(char* path)
{
	FILE* f;
	int c;
	int n;
	f = fopen(path, "r");
	if(f == NULL) { fputs("cannot open binary\n", stderr); exit(1); }
	n = 0;
	c = fgetc(f);
	while(c != -1)
	{
		if(n >= MAX_BIN) { fputs("binary too large\n", stderr); exit(1); }
		bytes[n] = c;
		n = n + 1;
		c = fgetc(f);
	}
	fclose(f);
	return n;
}

void write_binary(char* path, int len)
{
	FILE* f;
	int i;
	f = fopen(path, "w");
	if(f == NULL) { fputs("cannot open output bin\n", stderr); exit(1); }
	i = 0;
	while(i < len)
	{
		fputc(bytes[i], f);
		i = i + 1;
	}
	fclose(f);
}

/* Find first occurrence of opcode prefix (op0, op1, op2-or-negative-for-2-byte). */
int find_pattern(int op0, int op1, int op2)
{
	int oplen;
	int i;
	if(op2 < 0) oplen = 2;
	else oplen = 3;
	i = 0;
	while(i + oplen <= bin_size)
	{
		if((bytes[i] & 0xFF) == op0 && (bytes[i + 1] & 0xFF) == op1)
		{
			if(oplen == 2) return i;
			if((bytes[i + 2] & 0xFF) == op2) return i;
		}
		i = i + 1;
	}
	return -1;
}

/* RIP-rel32 patch loop.  op2 < 0 means 2-byte opcode (88 05 / 8a 05). */
void patch_rel32(int op0, int op1, int op2, int static_vm, int data_vm, int data_length)
{
	int oplen;
	int start;
	int i;
	int matched;
	int disp_pos;
	int next_instr;
	int b0;
	int b1;
	int b2;
	int b3;
	int disp;
	int target;
	int new_target;
	int new_disp;
	if(op2 < 0) oplen = 2;
	else oplen = 3;
	start = 0;
	while(start + oplen <= bin_size)
	{
		matched = 0;
		i = start;
		while(i + oplen <= bin_size)
		{
			if((bytes[i] & 0xFF) == op0 && (bytes[i + 1] & 0xFF) == op1)
			{
				if(oplen == 2)
				{
					matched = 1;
					break;
				}
				if((bytes[i + 2] & 0xFF) == op2)
				{
					matched = 1;
					break;
				}
			}
			i = i + 1;
		}
		if(!matched) return;
		disp_pos = i + oplen;
		if(disp_pos + 4 > bin_size) return;
		next_instr = BASE + disp_pos + 4;
		b0 = bytes[disp_pos + 0] & 0xFF;
		b1 = bytes[disp_pos + 1] & 0xFF;
		b2 = bytes[disp_pos + 2] & 0xFF;
		b3 = bytes[disp_pos + 3] & 0xFF;
		disp = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24);
		if(disp & 0x80000000) disp = disp - 0x100000000;
		target = next_instr + disp;
		if(target >= static_vm && target < static_vm + data_length)
		{
			new_target = data_vm + (target - static_vm);
			new_disp = (new_target - next_instr) & 0xFFFFFFFF;
			bytes[disp_pos + 0] = new_disp & 0xFF;
			bytes[disp_pos + 1] = (new_disp >> 8) & 0xFF;
			bytes[disp_pos + 2] = (new_disp >> 16) & 0xFF;
			bytes[disp_pos + 3] = (new_disp >> 24) & 0xFF;
		}
		start = disp_pos + 4;
	}
}

/* Find the 4-byte marker \x53 \x48 \x8d \x05 (push rbx; lea rax,[rip+...]). */
int find_fix_types_marker(void)
{
	int i;
	i = 0;
	while(i + 4 <= bin_size)
	{
		if((bytes[i] & 0xFF) == 0x53 &&
		   (bytes[i + 1] & 0xFF) == 0x48 &&
		   (bytes[i + 2] & 0xFF) == 0x8d &&
		   (bytes[i + 3] & 0xFF) == 0x05)
		{
			return i;
		}
		i = i + 1;
	}
	return -1;
}

void patch_binary(char* source_path, char* binary_path)
{
	int marker;
	int lea_position;
	int next_instr;
	int d0;
	int d1;
	int d2;
	int d3;
	int disp;
	int static_vm;
	int static_file_offset;
	int static_length;
	int total_size;
	int i;

	(void)source_path;
	bin_size = load_binary(binary_path);

	marker = find_fix_types_marker();
	if(marker < 0) { fputs("fix_types marker not found\n", stderr); exit(1); }

	lea_position = marker + 1;
	next_instr = BASE + lea_position + 7;
	d0 = bytes[lea_position + 3] & 0xFF;
	d1 = bytes[lea_position + 4] & 0xFF;
	d2 = bytes[lea_position + 5] & 0xFF;
	d3 = bytes[lea_position + 6] & 0xFF;
	disp = d0 | (d1 << 8) | (d2 << 16) | (d3 << 24);
	if(disp & 0x80000000) disp = disp - 0x100000000;
	static_vm = next_instr + disp;
	static_file_offset = static_vm - BASE;
	static_length = bin_size - static_file_offset;
	total_size = bin_size;
	if(total_size < DATA_FILE_OFFSET + static_length)
		total_size = DATA_FILE_OFFSET + static_length;

	/* Backward copy static block. */
	i = static_length - 1;
	while(i >= 0)
	{
		bytes[DATA_FILE_OFFSET + i] = bytes[static_file_offset + i];
		i = i - 1;
	}

	/* 16 opcode patterns from perl, dispatched by op-byte triples. */
	patch_rel32(0x48, 0x8d, 0x05, static_vm, DATA_VM, static_length);
	patch_rel32(0x48, 0x8d, 0x1d, static_vm, DATA_VM, static_length);
	patch_rel32(0x48, 0x8d, 0x0d, static_vm, DATA_VM, static_length);
	patch_rel32(0x48, 0x8d, 0x15, static_vm, DATA_VM, static_length);
	patch_rel32(0x48, 0x8d, 0x35, static_vm, DATA_VM, static_length);
	patch_rel32(0x48, 0x8b, 0x05, static_vm, DATA_VM, static_length);
	patch_rel32(0x48, 0x8b, 0x1d, static_vm, DATA_VM, static_length);
	patch_rel32(0x48, 0x8b, 0x0d, static_vm, DATA_VM, static_length);
	patch_rel32(0x48, 0x8b, 0x15, static_vm, DATA_VM, static_length);
	patch_rel32(0x48, 0x8b, 0x35, static_vm, DATA_VM, static_length);
	patch_rel32(0x48, 0x89, 0x05, static_vm, DATA_VM, static_length);
	patch_rel32(0x48, 0x89, 0x1d, static_vm, DATA_VM, static_length);
	patch_rel32(0x48, 0x89, 0x0d, static_vm, DATA_VM, static_length);
	patch_rel32(0x48, 0x89, 0x15, static_vm, DATA_VM, static_length);
	patch_rel32(0x88, 0x05, -1,   static_vm, DATA_VM, static_length);
	patch_rel32(0x8a, 0x05, -1,   static_vm, DATA_VM, static_length);

	write_binary(binary_path, total_size);
}

int main(int argc, char** argv)
{
	if(argc != 4)
	{
		fputs("usage: phase4-amd64-cc-arch (port|patch) <src> <dst>\n", stderr);
		exit(1);
	}
	source = calloc(MAX_SOURCE, sizeof(char));
	if(streq(argv[1], "port"))
	{
		port_source(argv[2], argv[3]);
	}
	else if(streq(argv[1], "patch"))
	{
		bytes = calloc(MAX_BIN, sizeof(char));
		patch_binary(argv[2], argv[3]);
	}
	else
	{
		fputs("unknown command\n", stderr);
		exit(1);
	}
	return 0;
}
