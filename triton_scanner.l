/* ============================================================================
 *  triton_scanner.l  --  Lexical analyzer for the Triton compiler
 * ----------------------------------------------------------------------------
 *  PHASE I (lex):  recognise lexemes, classify them as tokens, build the
 *                  symbol table, report unknown symbols.
 *
 *  THIS REVISION ALSO SERVES PHASE II (yacc):
 *    - Every action now RETURNS the Bison token id (instead of only printing
 *      a row), so the parser declared in triton_parser.y can drive yylex().
 *    - For tokens that carry a value (IDENTIFIER, NAMESPACE, TYPE, STRING_LIT,
 *      INT_LIT, FLOAT_LIT) the lexeme / numeric value is placed in yylval so
 *      semantic actions in the parser can read it.
 *    - A new logical-line terminator token NEWLINE is emitted ONLY when we
 *      are at paren_depth == 0.  Inside parentheses, brackets or braces, a
 *      real '\n' is silently skipped, which is exactly how Python allows
 *      multi-line expressions and is essential for the parser to accept
 *      typical kernel signatures and calls.
 *
 *  THE THREE LEX SECTIONS ARE UNCHANGED IN SHAPE
 *      DEFINITION SECTION  -> includes, options, named patterns, helpers
 *      RULES SECTION       -> pattern { action } pairs
 *      USER CODE SECTION   -> plain C (here: the emit helper and yywrap)
 *
 *  RUNTIME MODES (selected from main.c via a global flag)
 *      verbose = 1  ->  the emit helper prints the "SEQUENCE OF TOKENS" row
 *                       (Step I style) AND returns the token to the parser.
 *      verbose = 0  ->  silent; tokens are only returned to the parser.
 * ==========================================================================*/


/* ======================= 1. DEFINITION SECTION ===========================*/
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "tokens.h"
#include "symtab.h"
#include "triton_parser.tab.h"     /* token IDs + yylval (%union) type     */

extern int yylineno;

/* Counters used in the final summary. */
long g_token_count = 0;
long g_lexical_error_count = 0;

/* Paren depth.  >0 means we are inside ( [ or { somewhere; newlines are
 * suppressed in that case, mirroring Python's implicit line continuation. */
static int paren_depth = 0;

/* Verbose mode flag (set from main).  When non-zero, every emitted token is
 * also printed as a row of the SEQUENCE OF TOKENS table.                    */
int g_lex_verbose = 0;

/* Standalone-lex flag.  When non-zero we are running in -l mode (no parser
 * is consuming our output), so the scanner itself populates the symbol
 * table on every IDENTIFIER.  In -p / -s modes this flag is OFF: the parser
 * calls sym_use only for IDENTIFIERS in real use positions (not for the
 * member name after a DOT), avoiding both double counting and false
 * positives in the "used but not declared" semantic check.                  */
int g_lex_standalone = 0;

/* Header printed once when verbose mode is on. */
void scanner_print_header(void)
{
    if (!g_lex_verbose) return;
    printf("================= SEQUENCE OF TOKENS =================\n");
    printf(" %-5s  %-3s  %-12s  %-22s  %s\n",
           "LINE", "ID", "TOKEN", "LEXEME", "ATTRIBUTE");
    printf(" %-5s  %-3s  %-12s  %-22s  %s\n",
           "-----", "---", "------------", "----------------------",
           "---------");
}

/* Optionally print one row of the token stream, always return the token.
 * 'attr' is a short extra column ("-" or e.g. an int literal value).        */
static int emit(int bison_id, const char *attr)
{
    g_token_count++;
    if (g_lex_verbose) {
        printf(" %-5d  %-3d  %-12s  %-22s  %s\n",
               yylineno, token_display_id(bison_id), token_name(bison_id),
               yytext, attr ? attr : "-");
    }
    return bison_id;
}

/* ---- Reserved-word tables -------------------------------------------------
 * The classic technique: one rule for the {ID} shape, then look the word up
 * here.  Unlike Step I, classify_word now returns a SPECIFIC token id per
 * keyword (KW_DEF, KW_RETURN, ...), because the parser needs to distinguish
 * them.  Namespaces and types remain grouped (parser only cares about the
 * category).                                                                */

typedef struct { const char *word; int bison_id; } KwEntry;

static const KwEntry keyword_table[] = {
    { "def",    KW_DEF    }, { "return", KW_RETURN },
    { "if",     KW_IF     }, { "elif",   KW_ELIF   }, { "else",  KW_ELSE  },
    { "for",    KW_FOR    }, { "while",  KW_WHILE  }, { "in",    KW_IN    },
    { "import", KW_IMPORT }, { "from",   KW_FROM   }, { "as",    KW_AS    },
    { "pass",   KW_PASS   },
    { "and",    KW_AND    }, { "or",     KW_OR     }, { "not",   KW_NOT   },
    { "is",     KW_IS     },
    { "None",   KW_NONE   }, { "True",   KW_TRUE   }, { "False", KW_FALSE },
    { NULL, 0 }
};

static const char *const namespaces[] = { "triton", "tl", NULL };

static const char *const types[] = {
    "constexpr",
    "float16", "float32", "float64", "bfloat16",
    "int8", "int16", "int32", "int64",
    "uint8", "uint16", "uint32", "uint64",
    "bool", NULL
};

static int in_string_table(const char *w, const char *const t[])
{
    for (int i = 0; t[i] != NULL; i++)
        if (strcmp(w, t[i]) == 0) return 1;
    return 0;
}

/* Classify a word.  Returns either a specific KW_* id, NAMESPACE, TYPE,
 * or IDENTIFIER.                                                            */
static int classify_word(const char *w)
{
    for (int i = 0; keyword_table[i].word != NULL; i++)
        if (strcmp(w, keyword_table[i].word) == 0)
            return keyword_table[i].bison_id;
    if (in_string_table(w, namespaces)) return NAMESPACE;
    if (in_string_table(w, types))      return TYPE;
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

%x DOCSTRING

%%

 /* ----- whitespace and line comments: skipped, no token emitted --------- */
{WS}              { /* skip spaces, tabs, CR */ }
"#".*             { /* skip line comment */ }

 /* ----- newline: NEWLINE token only at paren depth 0 -------------------- */
\n                {
                      if (paren_depth == 0) {
                          /* NEWLINE is a parser synchronisation token; it
                           * is not part of the program's semantic token
                           * stream, so we neither count it in g_token_count
                           * nor print it in the verbose table.              */
                          return NEWLINE;
                      }
                      /* inside parens: silently swallow                    */
                  }

 /* ----- triple-quoted docstrings: skip the whole block ------------------ */
\"\"\"            { BEGIN(DOCSTRING); }
'''               { BEGIN(DOCSTRING); }
<DOCSTRING>\"\"\"  { BEGIN(INITIAL); }
<DOCSTRING>'''     { BEGIN(INITIAL); }
<DOCSTRING>\n      { /* count source lines (yylineno is automatic) */ }
<DOCSTRING>.       { /* swallow */ }

 /* ----- single-line string literals ------------------------------------- */
\"([^\"\\\n]|\\.)*\"   {
                          yylval.str = strdup(yytext);
                          return emit(STRING_LIT, NULL);
                      }
'([^'\\\n]|\\.)*'      {
                          yylval.str = strdup(yytext);
                          return emit(STRING_LIT, NULL);
                      }

 /* ----- numeric literals (FLOAT first; longest match decides anyway) ---- */
{FLOAT}           {
                      yylval.dval = strtod(yytext, NULL);
                      return emit(FLOAT_LIT, yytext);
                  }
{INT}             {
                      yylval.ival = strtol(yytext, NULL, 10);
                      return emit(INT_LIT, yytext);
                  }

 /* ----- decorator marker ------------------------------------------------- */
"@"               { return emit(AT, NULL); }

 /* ----- multi-character operators (BEFORE their one-char prefixes) ------ */
"**"              { return emit(DSTAR,   NULL); }
"//"              { return emit(DSLASH,  NULL); }
"=="              { return emit(EQ,      NULL); }
"!="              { return emit(NEQ,     NULL); }
"<="              { return emit(LE,      NULL); }
">="              { return emit(GE,      NULL); }
"+="              { return emit(PLUSEQ,  NULL); }
"-="              { return emit(MINUSEQ, NULL); }
"*="              { return emit(STAREQ,  NULL); }
"/="              { return emit(SLASHEQ, NULL); }
"->"              { return emit(ARROW,   NULL); }

 /* ----- single-character operators -------------------------------------- */
"="               { return emit(ASSIGN,  NULL); }
"+"               { return emit(PLUS,    NULL); }
"-"               { return emit(MINUS,   NULL); }
"*"               { return emit(STAR,    NULL); }
"/"               { return emit(SLASH,   NULL); }
"%"               { return emit(PERCENT, NULL); }
"<"               { return emit(LT,      NULL); }
">"               { return emit(GT,      NULL); }

 /* ----- delimiters / punctuation; bracketing ones also adjust paren_depth*/
"("               { paren_depth++; return emit(LPAREN,   NULL); }
")"               { if (paren_depth > 0) paren_depth--; return emit(RPAREN, NULL); }
"["               { paren_depth++; return emit(LBRACKET, NULL); }
"]"               { if (paren_depth > 0) paren_depth--; return emit(RBRACKET, NULL); }
"{"               { paren_depth++; return emit(LBRACE,   NULL); }
"}"               { if (paren_depth > 0) paren_depth--; return emit(RBRACE,   NULL); }
","               { return emit(COMMA,     NULL); }
":"               { return emit(COLON,     NULL); }
"."               { return emit(DOT,       NULL); }
";"               { return emit(SEMICOLON, NULL); }

 /* ----- words: keyword / namespace / type / identifier ------------------ */
{ID}              {
                      int id = classify_word(yytext);
                      if (id == IDENTIFIER || id == NAMESPACE || id == TYPE) {
                          yylval.str = strdup(yytext);
                      }
                      /* Lex-only mode: the scanner is the only thing
                       * filling the symbol table, so we record every
                       * IDENTIFIER occurrence here (Step I behaviour).
                       * When the parser is running, it does the recording
                       * with correct context (e.g. skipping the member
                       * after a DOT).                                       */
                      if (g_lex_standalone && id == IDENTIFIER) {
                          sym_use(yytext, yylineno);
                      }
                      return emit(id, NULL);
                  }

 /* ----- catch-all: unknown character is a LEXICAL ERROR ----------------- */
.                 {
                      g_lexical_error_count++;
                      fprintf(stderr,
                          "Lexical error (line %d): unknown symbol '%s'\n",
                          yylineno, yytext);
                      /* do not return a token; keep scanning              */
                  }
%%

/* ======================= 3. USER CODE SECTION ============================*/

/* yywrap defaulted out via %option noyywrap, so nothing more is needed in
 * this file.  main() lives in main.c.                                       */
