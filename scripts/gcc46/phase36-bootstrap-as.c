/* phase36-bootstrap-as — translate the Mach-O / GAS assembly that
 * gcc-4.6's cc1 emits into the subset tcc's integrated assembler accepts.
 *
 * This is a faithful C re-implementation of phase36-bootstrap-as.awk.  It
 * exists so the bootstrap `as` shim does NOT depend on the host's
 * /usr/bin/awk for what is really compiler-frontend work: by the gcc-4.6
 * libgcc stage the chain has already built tcc-darwin-cc, so this filter
 * is compiled BY THE CHAIN and run as a chain-built binary.
 *
 * Reads assembly on stdin, writes the translated assembly to stdout.
 * Its output is byte-for-byte identical to the awk version it replaces.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int ident_cont(int c) {
    return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
           (c >= '0' && c <= '9') || c == '_' || c == '$';
}
static int ident_start(int c) {
    return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || c == '_';
}
static int ws(int c) { return c == ' ' || c == '\t'; }

/* Remove a leading Darwin '_' from every identifier, mirroring the awk
 * regex (^|[^A-Za-z0-9_$])_([A-Za-z_][A-Za-z0-9_$]*): a '_' that is at the
 * start of the line or preceded by a non-identifier char and followed by
 * an identifier-start char has that single '_' dropped. */
static void strip_prefix(const char *in, char *out) {
    const char *p = in;
    char *o = out;
    while (*p) {
        int boundary = (p == in) || !ident_cont((unsigned char)p[-1]);
        if (*p == '_' && boundary && ident_start((unsigned char)p[1])) {
            p++;                         /* drop the underscore */
            *o++ = *p++;                 /* identifier start    */
            while (ident_cont((unsigned char)*p)) *o++ = *p++;
        } else {
            *o++ = *p++;
        }
    }
    *o = 0;
}

/* If s (ignoring leading whitespace) starts with mnemonic mn followed by
 * whitespace, return a pointer to the first operand char; else NULL. */
static const char *match_mn(const char *s, const char *mn) {
    const char *p = s;
    size_t n = strlen(mn);
    while (ws((unsigned char)*p)) p++;
    if (strncmp(p, mn, n) != 0) return NULL;
    p += n;
    if (!ws((unsigned char)*p)) return NULL;
    while (ws((unsigned char)*p)) p++;
    return p;
}

/* Like match_mn but the mnemonic must be the whole line (only trailing
 * whitespace allowed).  Returns 1 on match. */
static int match_mn_alone(const char *s, const char *mn) {
    const char *p = s;
    size_t n = strlen(mn);
    while (ws((unsigned char)*p)) p++;
    if (strncmp(p, mn, n) != 0) return NULL != NULL; /* 0 */
    p += n;
    while (ws((unsigned char)*p)) p++;
    return *p == 0;
}

/* leading-whitespace + ".directive" + whitespace test */
static const char *match_dir(const char *s, const char *dir) {
    return match_mn(s, dir);
}
static int starts_dir(const char *s, const char *dir) {
    /* s (after leading ws) starts with dir followed by whitespace.  Mirrors
     * awk's /^[[:space:]]*\.dir[[:space:]]/ — the trailing [[:space:]] does
     * NOT match end-of-line, so a bare ".text" (no trailing ws) is NOT a
     * match (important for the skip-section reset). */
    const char *p = s;
    size_t n = strlen(dir);
    while (ws((unsigned char)*p)) p++;
    if (strncmp(p, dir, n) != 0) return 0;
    return ws((unsigned char)p[n]);
}

/* dir followed by optional whitespace then end-of-line (awk's "[[:space:]]*$"). */
static int dir_eol(const char *s, const char *dir) {
    const char *p = s;
    size_t n = strlen(dir);
    while (ws((unsigned char)*p)) p++;
    if (strncmp(p, dir, n) != 0) return 0;
    p += n;
    while (ws((unsigned char)*p)) p++;
    return *p == 0;
}

/* power-of-two: 2^exp */
static long pow2(long exp) {
    long a = 1, i;
    for (i = 0; i < exp; i++) a *= 2;
    return a;
}

/* Remove every occurrence of needle from s (in place). */
static void gsub_remove(char *s, const char *needle) {
    size_t nl = strlen(needle);
    char *r = s, *w = s;
    while (*r) {
        if (strncmp(r, needle, nl) == 0) { r += nl; continue; }
        *w++ = *r++;
    }
    *w = 0;
}

/* Replace every "from" (whitespace-insensitive: literal) with "to". Only
 * used for the bswap rewrites, which match a literal "bswap %r"/"bswap %e"
 * possibly with extra spaces collapsed to one by awk's [[:space:]]+.  The
 * awk uses gsub(/bswap[[:space:]]+%r/, "bswapq %r"); we reproduce that by
 * scanning for "bswap" followed by whitespace then '%r' or '%e'. */
static void rewrite_bswap(char *s) {
    char out[8192];
    char *o = out;
    char *p = s;
    while (*p) {
        if (strncmp(p, "bswap", 5) == 0 && ws((unsigned char)p[5])) {
            const char *q = p + 5;
            while (ws((unsigned char)*q)) q++;
            if (q[0] == '%' && (q[1] == 'r' || q[1] == 'e')) {
                o += sprintf(o, "bswap%c %%%c", q[1] == 'r' ? 'q' : 'l', q[1]);
                p = q + 2;
                continue;
            }
        }
        *o++ = *p++;
    }
    *o = 0;
    strcpy(s, out);
}

/* Anchored mnemonic substitution: if line starts (after ws) with `mn`
 * followed by ws, rewrite to "\t<rep> <operands>".  Returns 1 if done. */
static int sub_mn(char *line, const char *mn, const char *rep) {
    const char *args = match_mn(line, mn);
    if (!args) return 0;
    char out[8192];
    sprintf(out, "\t%s %s", rep, args);
    strcpy(line, out);
    return 1;
}

/* Parse a register token at p (which must point at '%').  Returns the register
 * number 0-15 (and sets *is_xmm), advancing *end past the token; -1 on failure.
 * Handles %rax..%rdi, %r8..%r15, %eax..%edi (same low-3), %xmm0..%xmm15. */
static int parse_reg(const char *p, const char **end, int *is_xmm) {
    if (*p != '%') return -1;
    p++;
    if (strncmp(p, "xmm", 3) == 0) {
        p += 3;
        if (*p < '0' || *p > '9') return -1;
        int n = *p++ - '0';
        if (*p >= '0' && *p <= '9') n = n * 10 + (*p++ - '0');
        if (n > 15) return -1;
        *is_xmm = 1; *end = p; return n;
    }
    *is_xmm = 0;
    if (*p == 'r' && p[1] >= '0' && p[1] <= '9') {       /* r8..r15 */
        p++;
        int n = *p++ - '0';
        if (*p >= '0' && *p <= '9') n = n * 10 + (*p++ - '0');
        if (n < 8 || n > 15) return -1;
        *end = p; return n;
    }
    {
        static const struct { const char *nm; int n; } names[] = {
            {"rax",0},{"rcx",1},{"rdx",2},{"rbx",3},{"rsp",4},{"rbp",5},{"rsi",6},{"rdi",7},
            {"eax",0},{"ecx",1},{"edx",2},{"ebx",3},{"esp",4},{"ebp",5},{"esi",6},{"edi",7},
            {0,0}
        };
        int i;
        for (i = 0; names[i].nm; i++) {
            size_t n = strlen(names[i].nm);
            if (strncmp(p, names[i].nm, n) == 0) { *end = p + n; return names[i].n; }
        }
    }
    return -1;
}

/* The four 64-bit SSE int<->double conversions gcc emits but the bootstrap tcc
 * MISCOMPILES (its assembler never emits the REX.W prefix for these, silently
 * producing 32-bit conversions).  We hand-encode them to raw .byte here.
 *
 *   prefix f2(sd)/f3(ss); REX = 0x48 | R(reg>=8) | X(index>=8) | B(base/rm>=8);
 *   0x0f; opcode 2a(cvtsi2*)/2c(cvtt*2si); ModRM.reg = dest(op1), rm = src(op0).
 *
 * Verified byte-for-byte against the host assembler for all operand forms gcc
 * emits (see scripts/gcc46/cvt-encoder-tests.{s,expected}).  On any operand
 * shape we don't recognise we emit the original line (=> a loud tcc "unknown
 * opcode" rather than a silent miscompile).  Returns 1 if the line was a target
 * mnemonic (handled), 0 otherwise. */
static int emit_cvt(const char *line) {
    static const struct { const char *mn; int pfx; int op; int rexw; } tab[] = {
        {"cvtsi2sdq", 0xf2, 0x2a, 1}, {"cvtsi2ssq", 0xf3, 0x2a, 1},
        {"cvttsd2siq", 0xf2, 0x2c, 1}, {"cvttss2siq", 0xf3, 0x2c, 1},
        /* float<->double conversions (0F 5A /r), XMM<->XMM(/mem), reg=dst rm=src.
         * No REX.W (no 64-bit GP operand); SSE prefix is 0/66/f3/f2.  gcc-10's
         * gimple-pretty-print.c etc. emit cvtps2pd; tcc's assembler lacks it. */
        {"cvtps2pd", 0x00, 0x5a, 0}, {"cvtpd2ps", 0x66, 0x5a, 0},
        {"cvtss2sd", 0xf3, 0x5a, 0}, {"cvtsd2ss", 0xf2, 0x5a, 0},
        {0,0,0,0}
    };
    const char *args = NULL;
    int pfx = 0, op = 0, rexw = 0, t;
    for (t = 0; tab[t].mn; t++) {
        args = match_mn(line, tab[t].mn);
        if (args) { pfx = tab[t].pfx; op = tab[t].op; rexw = tab[t].rexw; break; }
    }
    if (!args) return 0;

    /* split into op0 (src) and op1 (dst) at the top-level comma (memory
     * operands contain commas inside parens, so track paren depth). */
    const char *comma = NULL, *p;
    int depth = 0;
    for (p = args; *p; p++) {
        if (*p == '(') depth++;
        else if (*p == ')') depth--;
        else if (*p == ',' && depth == 0) { comma = p; break; }
    }
    char op0[256], op1[256];
    if (!comma) goto bail;
    {
        size_t l0 = comma - args;
        if (l0 >= sizeof op0) l0 = sizeof op0 - 1;
        memcpy(op0, args, l0); op0[l0] = 0;
        while (l0 && ws((unsigned char)op0[l0 - 1])) op0[--l0] = 0;
        const char *q = comma + 1;
        while (ws((unsigned char)*q)) q++;
        strncpy(op1, q, sizeof op1 - 1); op1[sizeof op1 - 1] = 0;
        size_t m = strlen(op1);
        while (m && ws((unsigned char)op1[m - 1])) op1[--m] = 0;
    }

    /* op1 (dest) is always a register -> ModRM.reg */
    int is_xmm1; const char *e1;
    int reg = parse_reg(op1, &e1, &is_xmm1);
    if (reg < 0 || *e1 != 0) goto bail;
    int rex = rexw ? 0x48 : 0x40;   /* 0x40 base; W only for the int forms */
    if (reg >= 8) rex |= 0x4;                            /* REX.R */

    unsigned char modrm, sib = 0;
    int have_sib = 0, dispsize = 0;
    long disp = 0;

    if (op0[0] == '%') {                                 /* reg-direct rm */
        int is_xmm0; const char *e0;
        int rm = parse_reg(op0, &e0, &is_xmm0);
        if (rm < 0 || *e0 != 0) goto bail;
        if (rm >= 8) rex |= 0x1;                         /* REX.B */
        modrm = 0xC0 | ((reg & 7) << 3) | (rm & 7);
    } else {                                             /* memory rm */
        const char *paren = strchr(op0, '(');
        if (!paren) goto bail;
        int have_disp = 0;
        if (paren != op0) {
            char dbuf[64]; size_t dl = paren - op0;
            if (dl >= sizeof dbuf) dl = sizeof dbuf - 1;
            memcpy(dbuf, op0, dl); dbuf[dl] = 0;
            char *endp;
            disp = strtol(dbuf, &endp, 0);
            if (*endp != 0) goto bail;                   /* symbolic disp */
            have_disp = 1;
        }
        const char *ip = paren + 1;
        int base = -1, index = -1, scale = 1, is_x; const char *e;
        if (*ip == '%') { base = parse_reg(ip, &e, &is_x); if (base < 0) goto bail; ip = e; }
        if (base < 0) goto bail;                         /* no-base mem: gcc never emits for these */
        if (*ip == ',') {
            ip++;
            index = parse_reg(ip, &e, &is_x);
            if (index < 0) goto bail; ip = e;
            if (*ip == ',') { ip++; scale = atoi(ip); while (*ip >= '0' && *ip <= '9') ip++; }
        }
        if (*ip != ')') goto bail;
        if (base >= 8) rex |= 0x1;                       /* REX.B */
        if (index >= 8) rex |= 0x2;                      /* REX.X */
        int sclog = scale==1?0:scale==2?1:scale==4?2:scale==8?3:-1;
        if (index >= 0 && sclog < 0) goto bail;

        int need_sib = (index >= 0) || ((base & 7) == 4);      /* rsp/r12 force SIB */
        int base_is_bp = ((base & 7) == 5);                    /* rbp/r13 need disp */
        int mod;
        if (!have_disp || disp == 0) {
            if (base_is_bp) { mod = 1; dispsize = 1; disp = 0; }
            else { mod = 0; dispsize = 0; }
        } else if (disp >= -128 && disp <= 127) { mod = 1; dispsize = 1; }
        else { mod = 2; dispsize = 4; }

        if (need_sib) {
            modrm = (mod << 6) | ((reg & 7) << 3) | 4;
            int sib_index = (index >= 0) ? (index & 7) : 4;    /* 4 = no index */
            sib = ((sclog < 0 ? 0 : sclog) << 6) | (sib_index << 3) | (base & 7);
            have_sib = 1;
        } else {
            modrm = (mod << 6) | ((reg & 7) << 3) | (base & 7);
        }
    }

    /* SSE prefix (if any) then REX (only when it carries W/R/X/B), then 0F op modrm */
    int emit_rex = rexw || (rex != 0x40);
    int first = 1;
    printf("\t.byte ");
    if (pfx) { printf("0x%02x", pfx); first = 0; }
    if (emit_rex) { printf("%s0x%02x", first ? "" : ",", rex); first = 0; }
    printf("%s0x0f,0x%02x,0x%02x", first ? "" : ",", op, modrm);
    if (have_sib) printf(",0x%02x", (unsigned)(unsigned char)sib);
    if (dispsize == 1) printf(",0x%02x", (unsigned)(disp & 0xff));
    else if (dispsize == 4) {
        unsigned long u = (unsigned long)disp & 0xffffffffUL;
        printf(",0x%02lx,0x%02lx,0x%02lx,0x%02lx",
               u & 0xff, (u >> 8) & 0xff, (u >> 16) & 0xff, (u >> 24) & 0xff);
    }
    putchar('\n');
    return 1;

bail:
    fprintf(stderr, "as-filter: cvt: unrecognised operand form, emitting verbatim: %s\n", line);
    puts(line);
    return 1;
}

int main(void) {
    static char raw[8192], line[8192], tmp[8192];
    int skip_section = 0;

    while (fgets(raw, sizeof raw, stdin)) {
        size_t len = strlen(raw);
        if (len && raw[len - 1] == '\n') raw[--len] = 0;

        /* skip_section state machine.  A new section directive ends the skip.
         * NB .text/.data/.bss are usually emitted BARE (just "\t.text\n", no
         * trailing operand), so we must match end-of-line too — starts_dir
         * alone requires trailing whitespace and would never reset, dropping
         * all code after the first __gcc_except_tab/__eh_frame. */
        if (skip_section) {
            if (starts_dir(raw, ".text") || dir_eol(raw, ".text") ||
                starts_dir(raw, ".data") || dir_eol(raw, ".data") ||
                starts_dir(raw, ".bss")  || dir_eol(raw, ".bss")  ||
                starts_dir(raw, ".section"))
                skip_section = 0;
            else
                continue;
        }

        /* .section dispatch */
        {
            const char *a = match_dir(raw, ".section");
            if (a) {
                if (strncmp(a, "__TEXT,__eh_frame", 17) == 0 ||
                    strncmp(a, "__DWARF,", 8) == 0) {
                    skip_section = 1;
                    continue;
                }
                if (strncmp(a, "__TEXT,__text", 13) == 0) { puts("\t.text"); continue; }
                /* C++ coalesced text (templates/inlines/weak defs) -> .text */
                if (strncmp(a, "__TEXT,__textcoal_nt", 20) == 0) { puts("\t.text"); continue; }
                if (strncmp(a, "__TEXT,__cstring", 16) == 0 ||
                    strncmp(a, "__TEXT,__literal", 16) == 0 ||
                    strncmp(a, "__TEXT,__const", 14) == 0) { puts("\t.data"); continue; }
                if (strncmp(a, "__DATA,__data", 13) == 0) { puts("\t.data"); continue; }
                /* C++ exception LSDA tables: skip entirely.  EH does not unwind
                 * in this toolchain (eh_frame is also skipped), and the LSDA
                 * uses .set/label-difference/`$` syntax tcc's assembler rejects.
                 * The tables are only consumed by the unwinder, which we lack. */
                if (strncmp(a, "__DATA,__gcc_except_tab", 23) == 0) { skip_section = 1; continue; }
                /* C++ coalesced data / const data -> .data */
                if (strncmp(a, "__DATA,__datacoal_nt", 20) == 0 ||
                    strncmp(a, "__DATA,__const_coal", 19) == 0 ||
                    strncmp(a, "__DATA,__const", 14) == 0) { puts("\t.data"); continue; }
                if (strncmp(a, "__DATA,__bss", 12) == 0) { puts("\t.bss"); continue; }
                /* other sections fall through to default printing */
            }
        }

        if (dir_eol(raw, ".subsections_via_symbols")) continue;
        if (starts_dir(raw, ".no_dead_strip")) continue;
        /* Mach-O section-attribute directives gcc-4.6 emits (even for an empty
         * C++ TU); tcc's assembler has no such opcodes.  Drop them — the actual
         * static-init mechanism we honour is .mod_init_func (routed to .data
         * elsewhere), not these bare .constructor/.destructor attributes. */
        if (dir_eol(raw, ".constructor") || starts_dir(raw, ".constructor")) continue;
        if (dir_eol(raw, ".destructor") || starts_dir(raw, ".destructor")) continue;
        /* Mach-O symbol-visibility directive tcc lacks; drop it (the symbol
         * stays defined/global, fine for our static link). */
        if (starts_dir(raw, ".private_extern")) continue;
        /* C++ weak/coalesced markers: tcc's asm has no weak defs; drop them
         * (the symbol stays defined via its .globl).  NB cross-TU weak
         * coalescing in the minimal hex2 linker is a separate downstream
         * problem for libstdc++. */
        if (starts_dir(raw, ".weak_definition")) continue;
        if (starts_dir(raw, ".weak_def_can_be_hidden")) continue;

        /* drop DWARF ".file N" and ".loc" */
        {
            const char *a = match_dir(raw, ".file");
            if (a && a[0] >= '0' && a[0] <= '9') continue;
        }
        if (starts_dir(raw, ".loc")) continue;

        /* .const / .cstring / .literalN / .static_data (alone) -> .data */
        {
            const char *p = raw;
            while (ws((unsigned char)*p)) p++;
            if (*p == '.') {
                const char *names[] = {".const", ".const_data", ".cstring",
                                       ".static_data",
                                       /* C++ global ctor/dtor pointer sections:
                                        * route into .data so tcc assembles the
                                        * function-pointer table (running those
                                        * ctors at startup is handled elsewhere). */
                                       ".mod_init_func", ".mod_term_func", 0};
                int matched = 0, i;
                for (i = 0; names[i]; i++) {
                    size_t n = strlen(names[i]);
                    if (strncmp(p, names[i], n) == 0) {
                        const char *q = p + n;
                        while (ws((unsigned char)*q)) q++;
                        if (*q == 0) { matched = 1; break; }
                    }
                }
                /* .literal<digits> alone */
                if (!matched && strncmp(p, ".literal", 8) == 0) {
                    const char *q = p + 8;
                    while (*q >= '0' && *q <= '9') q++;
                    const char *r = q;
                    while (ws((unsigned char)*r)) r++;
                    if (q != p + 8 && *r == 0) matched = 1;
                }
                if (matched) { puts("\t.data"); continue; }
            }
        }

        /* .comm name,size[,align] -> .bss/.globl/label/.skip */
        {
            const char *a = match_dir(raw, ".comm");
            if (a) {
                strncpy(tmp, a, sizeof tmp - 1);
                tmp[sizeof tmp - 1] = 0;
                char *c1 = strchr(tmp, ',');
                if (c1) {
                    *c1 = 0;
                    char *size = c1 + 1;
                    char *c2 = strchr(size, ',');
                    if (c2) *c2 = 0;
                    char name[8192];
                    strip_prefix(tmp, name);
                    printf("\t.bss\n\t.globl %s\n%s:\n\t.skip %s\n", name, name, size);
                    continue;
                }
            }
        }

        /* .zerofill seg,sect,name,size[,align] -> .bss/.globl/label/.skip */
        {
            const char *a = match_dir(raw, ".zerofill");
            if (a) {
                strncpy(tmp, a, sizeof tmp - 1);
                tmp[sizeof tmp - 1] = 0;
                char *f[8];
                int nf = 0;
                char *t = tmp;
                f[nf++] = t;
                while (*t && nf < 8) {
                    if (*t == ',') { *t = 0; f[nf++] = t + 1; }
                    t++;
                }
                if (nf >= 4) {
                    char name[8192];
                    strip_prefix(f[2], name);
                    printf("\t.bss\n\t.globl %s\n%s:\n\t.skip %s\n", name, name, f[3]);
                    continue;
                }
            }
        }

        /* .align N -> .align 2^N ; .p2align N[,..] -> .align 2^N */
        {
            const char *a = match_dir(raw, ".align");
            if (!a) a = match_dir(raw, ".p2align");
            if (a && a[0] >= '0' && a[0] <= '9') {
                long exp = atol(a);
                printf("\t.align %ld\n", pow2(exp));
                continue;
            }
        }

        /* default: symbol-prefix strip (unless .ascii/.asciz/.string) */
        if (starts_dir(raw, ".ascii") || starts_dir(raw, ".asciz") ||
            starts_dir(raw, ".string")) {
            strcpy(line, raw);
        } else {
            strip_prefix(raw, line);
        }

        /* movq X@GOTPCREL(%rip), %r... -> leaq X(%rip), %r... */
        {
            const char *a = match_mn(line, "movq");
            if (a && ident_start((unsigned char)a[0])) {
                const char *q = a;
                while (ident_cont((unsigned char)*q)) q++;
                if (strncmp(q, "@GOTPCREL(%rip),", 16) == 0) {
                    /* require following ws* %r */
                    const char *r = q + 16;
                    while (ws((unsigned char)*r)) r++;
                    if (r[0] == '%' && r[1] == 'r') {
                        strcpy(tmp, line);
                        gsub_remove(tmp, "@GOTPCREL");
                        const char *args2 = match_mn(tmp, "movq");
                        printf("\tleaq %s\n", args2);
                        continue;
                    }
                }
            }
        }

        gsub_remove(line, "@GOTPCREL");

        if (sub_mn(line, "movabsq", "movq")) { puts(line); continue; }
        if (sub_mn(line, "movabsl", "movl")) { puts(line); continue; }
        if (sub_mn(line, "movdqa", "movaps")) { puts(line); continue; }
        if (sub_mn(line, "movlps", "movq")) { puts(line); continue; }
        if (sub_mn(line, "movss", "movd")) { puts(line); continue; }
        if (sub_mn(line, "xorps", "pxor")) { puts(line); continue; }
        if (sub_mn(line, "xorpd", "pxor")) { puts(line); continue; }

        rewrite_bswap(line);

        if (sub_mn(line, "salb", "shlb")) { puts(line); continue; }
        if (sub_mn(line, "salw", "shlw")) { puts(line); continue; }
        if (sub_mn(line, "sall", "shll")) { puts(line); continue; }
        if (sub_mn(line, "salq", "shlq")) { puts(line); continue; }

        if (match_mn_alone(line, "cltq")) { puts("\t.byte 72,152"); continue; }

        /* movaps %xmmA,%xmmB | divss .. | divsd .. -> raw .byte encodings */
        {
            struct { const char *mn; const char *pfx; } simd[] = {
                {"movaps", "15,40,"},
                {"divss", "243,15,94,"},
                {"divsd", "242,15,94,"},
                {0, 0}
            };
            int i, done = 0;
            for (i = 0; simd[i].mn; i++) {
                const char *a = match_mn(line, simd[i].mn);
                if (!a) continue;
                /* expect %xmmN , ws* %xmmM  (whole rest) */
                if (strncmp(a, "%xmm", 4) != 0) continue;
                if (a[4] < '0' || a[4] > '7') continue;
                int r1 = a[4] - '0';
                const char *q = a + 5;
                if (*q != ',') continue;
                q++;
                while (ws((unsigned char)*q)) q++;
                if (strncmp(q, "%xmm", 4) != 0) continue;
                if (q[4] < '0' || q[4] > '7') continue;
                int r2 = q[4] - '0';
                const char *r = q + 5;
                while (ws((unsigned char)*r)) r++;
                if (*r != 0) continue;
                printf("\t.byte %s%d\n", simd[i].pfx, 192 + r2 * 8 + r1);
                done = 1;
                break;
            }
            if (done) continue;
        }

        if (emit_cvt(line)) continue;

        puts(line);
    }
    return 0;
}
