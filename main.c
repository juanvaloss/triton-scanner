/* ============================================================================
 * main.c  --  Driver for the Triton compiler (lex + yacc + semantic)
 * ----------------------------------------------------------------------------
 * Modes (selected by command-line flag; default is "all phases"):
 *
 *   -l   Lexical only.  Print the SEQUENCE OF TOKENS, the symbol table, and
 *        the lexical-error count.  Equivalent to the Step I deliverable.
 *
 *   -p   Lexical + Syntax.  Run the parser; print syntax errors (if any).
 *        Token stream is NOT printed by default in this mode; pass -v if
 *        you also want to see it.
 *
 *   -s   All three phases (default).  Lex, parse, then run semantic checks.
 *
 *   -v   Verbose: also print the SEQUENCE OF TOKENS table in modes -p / -s.
 *
 * Usage:
 *   ./triton_scanner [-l|-p|-s] [-v] <file.py>
 *
 * Exit status:
 *   0 if all enabled phases reported no errors, 1 otherwise.
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
extern int   yylex(void);             /* used only for -l mode             */
extern int   g_lex_verbose;
extern int   g_lex_standalone;
extern long  g_token_count;
extern long  g_lexical_error_count;
extern long  g_syntax_error_count;
extern void  scanner_print_header(void);

typedef enum { MODE_LEX = 1, MODE_PARSE = 2, MODE_SEMANTIC = 3 } Mode;

static void usage(const char *prog)
{
    fprintf(stderr,
        "usage: %s [-l|-p|-s] [-v] <file.py>\n"
        "  -l   lexical analysis only\n"
        "  -p   lexical + syntax analysis\n"
        "  -s   lexical + syntax + semantic (default)\n"
        "  -v   verbose: also print the token stream in -p / -s modes\n",
        prog);
}

int main(int argc, char **argv)
{
    /* Line-buffer stdout so error rows on stderr interleave correctly with
     * the token rows on stdout when both streams are merged (2>&1).        */
    setvbuf(stdout, NULL, _IOLBF, 0);

    Mode mode = MODE_SEMANTIC;
    int  verbose = 0;
    const char *path = NULL;

    /* Tiny ad-hoc argument parser: flags first, then exactly one filename. */
    for (int i = 1; i < argc; i++) {
        if      (strcmp(argv[i], "-l") == 0) mode = MODE_LEX;
        else if (strcmp(argv[i], "-p") == 0) mode = MODE_PARSE;
        else if (strcmp(argv[i], "-s") == 0) mode = MODE_SEMANTIC;
        else if (strcmp(argv[i], "-v") == 0) verbose = 1;
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

    /* Verbose printing is always on in -l mode, optional in -p / -s.       */
    g_lex_verbose = (mode == MODE_LEX) || verbose;
    g_lex_standalone = (mode == MODE_LEX);   /* fill symtab from scanner   */
    if (g_lex_verbose) scanner_print_header();

    int phase_failed = 0;

    if (mode == MODE_LEX) {
        /* Drain yylex() ourselves; the parser is not used.                 */
        while (yylex() != 0) { /* loop until EOF */ }
        sym_print();
        printf("\nTOTAL tokens: %ld   |   Lexical errors: %ld\n",
               g_token_count, g_lexical_error_count);
        phase_failed = (g_lexical_error_count > 0);

    } else {
        /* yyparse() calls yylex() internally until it sees EOF.            */
        int rc = yyparse();
        (void)rc;                       /* errors counted in yyerror()      */
        if (g_lex_verbose) sym_print();

        long sem_errors = 0;
        if (mode == MODE_SEMANTIC)
            sem_errors = sem_check_all();

        printf("\nTOTAL tokens: %ld   |   Lexical errors: %ld   |   "
               "Syntax errors: %ld",
               g_token_count, g_lexical_error_count, g_syntax_error_count);
        if (mode == MODE_SEMANTIC)
            printf("   |   Semantic issues: %ld", sem_errors);
        printf("\n");

        phase_failed = (g_lexical_error_count + g_syntax_error_count +
                        sem_errors) > 0;
    }

    fclose(yyin);
    return phase_failed ? 1 : 0;
}
