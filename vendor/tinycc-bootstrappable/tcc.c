/*
 *  TCC - Tiny C Compiler
 * 
 *  Copyright (c) 2001-2004 Fabrice Bellard
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#ifdef ONE_SOURCE
#include "libtcc.c"
#else
#include "tcc.h"
#endif
#include "tcctools.c"

static char* help = "Tiny C Compiler bootstrap\nUsage: tcc [options...] [-o outfile] [-c] infile(s)...\n";

static char* help2 = "Tiny C Compiler bootstrap extended help\n";

static char* version = "tcc bootstrap version\n";

static void print_dirs(const char *msg, char **paths, int nb_paths)
{
    int i;
    printf("%s:\n", msg);
    if (!nb_paths)
        printf("  -\n");
    for(i = 0; i < nb_paths; i++)
        printf("  %s\n", paths[i]);
}

static void print_search_dirs(TCCState *s)
{
    printf("install: %s\n", s->tcc_lib_path);
    /* print_dirs("programs", NULL, 0); */
    print_dirs("include", s->sysinclude_paths, s->nb_sysinclude_paths);
    print_dirs("libraries", s->library_paths, s->nb_library_paths);
#ifndef TCC_TARGET_PE
    print_dirs("crt", s->crt_paths, s->nb_crt_paths);
    printf("libtcc1:\n  %s/"TCC_LIBTCC1"\n", s->tcc_lib_path);
    printf("elfinterp:\n  %s\n",  DEFAULT_ELFINTERP(s));
#endif
}

static void set_environment(TCCState *s)
{
    char * path;

    path = getenv("C_INCLUDE_PATH");
    if(path != NULL) {
        tcc_add_include_path(s, path);
    }
    path = getenv("CPATH");
    if(path != NULL) {
        tcc_add_include_path(s, path);
    }
    path = getenv("LIBRARY_PATH");
    if(path != NULL) {
        tcc_add_library_path(s, path);
    }
}

static char *default_outputfile(TCCState *s, const char *first_file)
{
    char buf[1024];
    char *ext;
    const char *name = "a";

    if (first_file && strcmp(first_file, "-"))
        name = tcc_basename(first_file);
    snprintf(buf, sizeof(buf), "%s", name);
    ext = tcc_fileextension(buf);
#ifdef TCC_TARGET_PE
    if (s->output_type == TCC_OUTPUT_DLL)
        strcpy(ext, ".dll");
    else
    if (s->output_type == TCC_OUTPUT_EXE)
        strcpy(ext, ".exe");
    else
#endif
    if (s->output_type == TCC_OUTPUT_OBJ && !s->option_r && *ext)
        strcpy(ext, ".o");
    else
        strcpy(buf, "a.out");
    return tcc_strdup(buf);
}

static unsigned getclock_ms(void)
{
#ifdef _WIN32
    return GetTickCount();
#else
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec*1000 + (tv.tv_usec+500)/1000;
#endif
}

int main(int argc, char **argv)
{
    TCCState *s;
    int ret, opt, n = 0;
    unsigned start_time = 0;
    const char *first_file;

redo:
    s = tcc_new();
    opt = tcc_parse_args(s, &argc, &argv, 1);

    if (n == 0) {
        if (opt == OPT_HELP)
            return printf(help), 1;
        if (opt == OPT_HELP2)
            return printf(help2), 1;
        if (opt == OPT_M32 || opt == OPT_M64)
            tcc_tool_cross(s, argv, opt); /* never returns */
        if (s->verbose)
            printf(version);
        if (opt == OPT_AR)
            return tcc_tool_ar(s, argc, argv);
#ifdef TCC_TARGET_PE
        if (opt == OPT_IMPDEF)
            return tcc_tool_impdef(s, argc, argv);
#endif
        if (opt == OPT_V)
            return 0;
        if (opt == OPT_PRINT_DIRS) {
            /* initialize search dirs */
            tcc_set_output_type(s, TCC_OUTPUT_MEMORY);
            print_search_dirs(s);
            return 0;
        }

        n = s->nb_files;
        if (n == 0)
            tcc_error("no input files\n");

        if (s->output_type == TCC_OUTPUT_PREPROCESS) {
            if (!s->outfile) {
                s->ppfp = stdout;
            } else {
                s->ppfp = fopen(s->outfile, "w");
                if (!s->ppfp)
                    tcc_error("could not write '%s'", s->outfile);
            }
        } else if (s->output_type == TCC_OUTPUT_OBJ && !s->option_r) {
            if (s->nb_libraries)
                tcc_error("cannot specify libraries with -c");
            if (n > 1 && s->outfile)
                tcc_error("cannot specify output file with -c many files");
        } else {
            if (s->option_pthread)
                tcc_set_options(s, "-lpthread");
        }

        if (s->do_bench)
            start_time = getclock_ms();
    }

    set_environment(s);
    if (s->output_type == 0)
        s->output_type = TCC_OUTPUT_EXE;
    tcc_set_output_type(s, s->output_type);

    /* compile or add each files or library */
    for (first_file = NULL, ret = 0;;) {
        struct filespec *f = s->files[s->nb_files - n];
        s->filetype = f->type;
        s->alacarte_link = f->alacarte;
        if (f->type == AFF_TYPE_LIB) {
            if (tcc_add_library_err(s, f->name) < 0)
                ret = 1;
        } else {
            if (1 == s->verbose)
                printf("-> %s\n", f->name);
            if (!first_file)
                first_file = f->name;
            if (tcc_add_file(s, f->name) < 0)
                ret = 1;
        }
        s->filetype = 0;
        s->alacarte_link = 1;
        if (ret || --n == 0
            || (s->output_type == TCC_OUTPUT_OBJ && !s->option_r))
            break;
    }

    if (s->output_type == TCC_OUTPUT_PREPROCESS) {
        if (s->outfile)
            fclose(s->ppfp);
    } else if (0 == ret) {
        if (s->output_type == TCC_OUTPUT_MEMORY) {
#ifdef TCC_IS_NATIVE
            ret = tcc_run(s, argc, argv);
#endif
        } else {
            if (!s->outfile)
                s->outfile = default_outputfile(s, first_file);
            if (tcc_output_file(s, s->outfile))
                ret = 1;
            else if (s->gen_deps)
                gen_makedeps(s, s->outfile, s->deps_outfile);
        }
    }

    if (s->do_bench && ret == 0 && n == 0)
        tcc_print_stats(s, getclock_ms() - start_time);
    tcc_delete(s);
    if (ret == 0 && n)
        goto redo; /* compile more files with -c */
    return ret;
}
