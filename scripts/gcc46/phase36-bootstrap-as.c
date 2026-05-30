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

        puts(line);
    }
    return 0;
}
