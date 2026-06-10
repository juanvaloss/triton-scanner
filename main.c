/* ============================================================================
 * main.c  --  Driver for the Triton compiler (lex + yacc + semantic)
 * ----------------------------------------------------------------------------
 * Modes:
 *   -l   Lexical only.  Prints token stream + symbol table.
 *   -p   Lexical + Syntax.
 *   -s   Lexical + Syntax + Semantic (default).
 *
 * Usage:  ./triton_scanner [-l|-p|-s] <file.py>
 * Exit:   0 if no errors detected, 1 otherwise.
 * ==========================================================================*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "tokens.h"
#include "symtab.h"
#include "semantic.h"
#include "triton_parser.tab.h"

extern FILE *yyin;
extern int   yyparse(void);
extern int   yylex(void);
extern int   g_lex_standalone;
extern long  g_token_count;
extern long  g_lexical_error_count;
extern long  g_syntax_error_count;
extern void  scanner_print_header(void);

typedef enum { MODE_LEX, MODE_PARSE, MODE_SEMANTIC } Mode;

static void usage(const char *prog) {
    fprintf(stderr,
        "usage: %s [-l|-p|-s] <file.py>\n"
        "  -l   lexical analysis only\n"
        "  -p   lexical + syntax analysis\n"
        "  -s   lexical + syntax + semantic  (default)\n",
        prog);
}

int main(int argc, char **argv) {
    setvbuf(stdout, NULL, _IOLBF, 0);

    Mode mode = MODE_SEMANTIC;
    const char *path = NULL;

    for (int i = 1; i < argc; i++) {
        if      (strcmp(argv[i], "-l") == 0) mode = MODE_LEX;
        else if (strcmp(argv[i], "-p") == 0) mode = MODE_PARSE;
        else if (strcmp(argv[i], "-s") == 0) mode = MODE_SEMANTIC;
        else if (argv[i][0] == '-')          { usage(argv[0]); return 2; }
        else if (path == NULL)               path = argv[i];
        else                                 { usage(argv[0]); return 2; }
    }
    if (path == NULL) { usage(argv[0]); return 2; }

    yyin = fopen(path, "r");
    if (yyin == NULL) {
        fprintf(stderr, "error: cannot open '%s'\n", path);
        return 1;
    }
    printf("Scanning file: %s\n", path);

    g_lex_standalone = (mode == MODE_LEX);

    int phase_failed = 0;

    if (mode == MODE_LEX) {
        scanner_print_header();
        while (yylex() != 0) { /* loop until EOF */ }
        sym_print();
        printf("\nTOTAL tokens: %ld   |   Lexical errors: %ld\n",
               g_token_count, g_lexical_error_count);
        phase_failed = (g_lexical_error_count > 0);
    } else {
        yyparse();
        long sem_errors = 0;
        if (mode == MODE_SEMANTIC)
            sem_errors = sem_check_all();

        printf("\nTOTAL tokens: %ld   |   Lexical errors: %ld   |   "
               "Syntax errors: %ld",
               g_token_count, g_lexical_error_count, g_syntax_error_count);
        if (mode == MODE_SEMANTIC)
            printf("   |   Semantic issues: %ld", sem_errors);
        printf("\n");

        phase_failed = (g_lexical_error_count + g_syntax_error_count + sem_errors) > 0;
    }

    fclose(yyin);
    return phase_failed ? 1 : 0;
}
