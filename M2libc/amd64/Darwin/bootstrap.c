/* Copyright (C) 2016 Jeremiah Orians
 * This file is part of M2-Planet.
 *
 * M2-Planet is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * M2-Planet is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with M2-Planet.  If not, see <http://www.gnu.org/licenses/>.
 */

enum
{
	stdin = 1,
	stdout = 2,
	stderr = 3,
};

enum
{
	EOF = 0xFFFFFFFF,
	NULL = 0,
};

enum
{
	EXIT_FAILURE = 1,
	EXIT_SUCCESS = 0,
};

enum
{
	TRUE = 1,
	FALSE = 0,
};

void* malloc(int size);

unsigned read(FILE* f, char* buffer, unsigned count) {
	asm(
			"mov_rax, %0x2000003"
			"lea_rsi,[rsp+DWORD] %16"
			"mov_rsi,[rsi]"
			"lea_rdx,[rsp+DWORD] %8"
			"mov_rdx,[rdx]"
			"lea_rdi,[rsp+DWORD] %24"
			"mov_rdi,[rdi]"
			"sub_rdi,BYTE !1"
			"syscall");
}

char* __fputc_buffer;
int fgetc(FILE* f)
{
	if(__fputc_buffer == NULL) {
		__fputc_buffer = malloc(1);
	}

	if(read(f, __fputc_buffer, 1) <= 0) {
		return EOF;
	}

	return __fputc_buffer[0];
}

unsigned fread(char* buffer, unsigned size, unsigned count, FILE* f) {
	return read(f, buffer, size * count);
}

unsigned write(FILE* f, char* buffer, unsigned count) {
	asm(
			"mov_rax, %0x2000004"
			"lea_rsi,[rsp+DWORD] %16"
			"mov_rsi,[rsi]"
			"lea_rdx,[rsp+DWORD] %8"
			"mov_rdx,[rdx]"
			"lea_rdi,[rsp+DWORD] %24"
			"mov_rdi,[rdi]"
			"sub_rdi,BYTE !1"
			"syscall");
}

void fputc(char s, FILE* f)
{
	if(__fputc_buffer == NULL) {
		__fputc_buffer = malloc(1);
	}
	__fputc_buffer[0] = s;

	write(f, __fputc_buffer, 1);
}

unsigned fwrite(char* buffer, unsigned size, unsigned count, FILE* f) {
	if(size == 0 || count == 0) {
		return 0;
	}

	return write(f, buffer, size * count);
}

int strlen(char* str )
{
	int i = 0;
	while(0 != str[i]) i = i + 1;
	return i;
}

void fputs(char* s, FILE* f)
{
	write(f, s, strlen(s));
}

FILE* open(char* name, int flag, int mode)
{
	asm("lea_rdi,[rsp+DWORD] %24"
	    "mov_rdi,[rdi]"
	    "lea_rsi,[rsp+DWORD] %16"
	    "mov_rsi,[rsi]"
	    "lea_rdx,[rsp+DWORD] %8"
	    "mov_rdx,[rdx]"
	    "mov_rax, %0x2000005"
	    "syscall"
	    "add_rax,BYTE !1");
}

FILE* fopen(char* filename, char* mode)
{
	FILE* f;
	if('w' == mode[0])
	{
		f = open(filename, 1537 , 384);
	}
	else
	{
		f = open(filename, 0, 0);
	}

	if(0 > f)
	{
		return 0;
	}
	if(0 == f)
	{
		if('w' == mode[0])
		{
			f = open(filename, 1537 , 384);
		}
		else
		{
			f = open(filename, 0, 0);
		}
	}
	return f;
}

int close(int fd)
{
	asm("lea_rdi,[rsp+DWORD] %8"
	    "mov_rdi,[rdi]"
	    "sub_rdi,BYTE !1"
	    "mov_rax, %0x2000006"
	    "syscall");
}

int fclose(FILE* stream)
{
	int error = close(stream);
	return error;
}

void* mmap(void* addr, int length, int prot, int flags, int fd, int offset)
{
	asm("lea_rdi,[rsp+DWORD] %48"
	    "mov_rdi,[rdi]"
	    "lea_rsi,[rsp+DWORD] %40"
	    "mov_rsi,[rsi]"
	    "lea_rdx,[rsp+DWORD] %32"
	    "mov_rdx,[rdx]"
	    "lea_r10,[rsp+DWORD] %24"
	    "mov_r10,[r10]"
	    "lea_r8,[rsp+DWORD] %16"
	    "mov_r8,[r8]"
	    "lea_r9,[rsp+DWORD] %8"
	    "mov_r9,[r9]"
	    "mov_rax, %0x20000C5"
	    "syscall");
}

long _malloc_ptr;
long _malloc_end;

void* malloc(int size)
{
	if(NULL == _malloc_ptr)
	{
			_malloc_ptr = mmap(0, 134217728, 3, 4098, -1, 0);
			if(-1 == _malloc_ptr) return 0;
			_malloc_end = _malloc_ptr + 134217728;
	}

	size = (size + 7) & -8;
	if(_malloc_end < (_malloc_ptr + size)) return 0;

	long old_malloc = _malloc_ptr;
	_malloc_ptr = _malloc_ptr + size;
	return old_malloc;
}

void* memset(void* ptr, int value, int num)
{
	char* s;
	for(s = ptr; 0 < num; num = num - 1)
	{
		s[0] = value;
		s = s + 1;
	}
}

void* calloc(int count, int size)
{
	void* ret = malloc(count * size);
	if(NULL == ret) return NULL;
	memset(ret, 0, (count * size));
	return ret;
}

void free(void* l)
{
	return;
}

void exit(int value)
{
	asm("pop_rbx"
	    "pop_rdi"
	    "mov_rax, %0x2000001"
	    "syscall");
}
