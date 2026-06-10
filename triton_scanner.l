/* ============================================================================
 *  triton_scanner.l  --  Lexical analyzer for the Triton compiler (simple)
 * ----------------------------------------------------------------------------
 *  PHASE  : I (Lexical Analysis)
 *  TOOL   : GNU Flex  (on Ubuntu, /usr/bin/lex is a symlink to /usr/bin/flex)
 *
 *  WHAT THIS SCANNER DOES
 *    Reads a Triton source file character by character, groups characters
 *    into lexemes, classifies each lexeme as a TOKEN, and either prints it
 *    to stdout (in -l mode) or returns it to the parser (in -p / -s modes).
 *
 *  SIMPLIFICATIONS RESPECT TO A "FULL" SCANNER (documented future work)
 *    - No paren-depth tracking: every '\n' emits a NEWLINE token.  This
 *      means a multi-line call like "tl.load(\n  x_ptr, mask=m)" will
 *      cause a syntax error at the parser.  Single-line kernels work.
 *    - No triple-quoted docstring handling: a """ in input is not handled.
 *    - Limited keyword set: only def, return, import, from, as.  Other
 *      Python keywords (if/for/while/...) are treated as identifiers; if
 *      they appear in input, the parser will reject the statement.
 *
 *  THE THREE LEX SECTIONS (separated by %%)
 *    1. DEFINITIONS: C includes, options, named patterns, helpers
 *    2. RULES      : pattern { action } pairs
 *    3. USER CODE  : (empty here; main() lives in main.c)
 * ==========================================================================*/


/* ========================== 1. DEFINITIONS ===============================*/
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "tokens.h"
#include "symtab.h"
#include "triton_parser.tab.h"

extern int yylineno;

long g_token_count = 0;
long g_lexical_error_count = 0;

/* Standalone-lex mode: when -l is selected from main, this is 1 and the
 * scanner itself populates the symbol table.  When the parser is running
 * (-p / -s) this is 0 and only the parser calls sym_use, with correct
 * context (i.e. it skips the IDENTIFIER that follows a DOT, which is a
 * member name, not a free identifier reference).                           */
int g_lex_standalone = 0;

/* Print one row of the token stream (used in -l mode).  Always returns
 * the token id to the parser.                                              */
static int emit(int bison_id)
{
    g_token_count++;
    if (g_lex_standalone) {
        printf(" %-5d  %-3d  %-12s  %s\n",
               yylineno, token_display_id(bison_id),
               token_name(bison_id), yytext);
    }
    return bison_id;
}

void scanner_print_header(void)
{
    printf("================= SEQUENCE OF TOKENS =================\n");
    printf(" %-5s  %-3s  %-12s  %s\n", "LINE", "ID", "TOKEN", "LEXEME");
    printf(" %-5s  %-3s  %-12s  %s\n", "-----", "---", "------------", "------");
}

/* Reserved-word lookup tables.  Tiny on purpose: only the keywords this
 * grammar actually distinguishes.  Everything else is an IDENTIFIER.       */
typedef struct { const char *word; int bison_id; } KwEntry;

static const KwEntry keyword_table[] = {
    { "def",    KW_DEF    },
    { "return", KW_RETURN },
    { "import", KW_IMPORT },
    { "from",   KW_FROM   },
    { "as",     KW_AS     },
    { NULL, 0 }
};

static const char *const namespaces[] = { "triton", "tl", NULL };

static const char *const types[] = {
    "constexpr",
    "float16", "float32", "float64",
    "int8", "int16", "int32", "int64",
    "bool",
    NULL
};

static int in_table(const char *w, const char *const t[])
{
    for (int i = 0; t[i] != NULL; i++)
        if (strcmp(w, t[i]) == 0) return 1;
    return 0;
}

static int classify_word(const char *w)
{
    for (int i = 0; keyword_table[i].word != NULL; i++)
        if (strcmp(w, keyword_table[i].word) == 0)
            return keyword_table[i].bison_id;
    if (in_table(w, namespaces)) return NAMESPACE;
    if (in_table(w, types))      return TYPE;
    return IDENTIFIER;
}
%}

%option yylineno
%option noinput nounput
%option noyywrap

DIGIT   [0-9]
LETTER  [A-Za-z_]
ID      {LETTER}({LETTER}|{DIGIT})*
INT     {DIGIT}+
FLOAT   {DIGIT}+"."{DIGIT}+([eE][+-]?{DIGIT}+)?|{DIGIT}+[eE][+-]?{DIGIT}+
WS      [ \t\r]+

%%

 /* whitespace and line comments: skip */
{WS}              { /* skip */ }
"#".*             { /* skip line comment */ }

 /* triple-quoted docstring on a single line: skip */
\"\"\".*\"\"\"    { /* skip docstring */ }

 /* newline: emit NEWLINE token (no paren-depth tracking) */
\n                { return NEWLINE; }

 /* string literals (single-line only) */
\"([^\"\\\n]|\\.)*\"   { yylval.str = strdup(yytext); return emit(STRING_LIT); }
'([^'\\\n]|\\.)*'      { yylval.str = strdup(yytext); return emit(STRING_LIT); }

 /* numeric literals: FLOAT before INT to honour longest-match */
{FLOAT}           { yylval.dval = strtod(yytext, NULL); return emit(FLOAT_LIT); }
{INT}             { yylval.ival = strtol(yytext, NULL, 10); return emit(INT_LIT); }

 /* decorator marker */
"@"               { return emit(AT); }

 /* multi-character operators (must come BEFORE their 1-char prefixes) */
"=="              { return emit(EQ);  }
"!="              { return emit(NEQ); }
"<="              { return emit(LE);  }
">="              { return emit(GE);  }
"->"              { return emit(ARROW); }

 /* single-character operators and delimiters */
"="               { return emit(ASSIGN); }
"+"               { return emit(PLUS);   }
"-"               { return emit(MINUS);  }
"*"               { return emit(STAR);   }
"/"               { return emit(SLASH);  }
"<"               { return emit(LT);     }
">"               { return emit(GT);     }
"("               { return emit(LPAREN);   }
")"               { return emit(RPAREN);   }
"["               { return emit(LBRACKET); }
"]"               { return emit(RBRACKET); }
","               { return emit(COMMA); }
":"               { return emit(COLON); }
"."               { return emit(DOT);   }

 /* identifiers / keywords / namespaces / types (all share the {ID} shape) */
{ID}              {
                      int id = classify_word(yytext);
                      if (id == IDENTIFIER || id == NAMESPACE || id == TYPE) {
                          yylval.str = strdup(yytext);
                      }
                      if (g_lex_standalone && id == IDENTIFIER) {
                          sym_use(yytext, yylineno);
                      }
                      return emit(id);
                  }

 /* catch-all: any character no rule matched is a lexical error */
.                 {
                      g_lexical_error_count++;
                      fprintf(stderr,
                          "Lexical error (line %d): unknown symbol '%s'\n",
                          yylineno, yytext);
                  }
%%
