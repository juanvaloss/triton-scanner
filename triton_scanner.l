/* ============================================================================
 *  triton_scanner.l  --  Lexical analyzer (scanner) for Triton GPU kernels
 * ----------------------------------------------------------------------------
 *  COURSE : TC3002B - Module #3 Compilers - Step I (Lexical Analysis Phase)
 *  TOOL   : UNIX lex / Flex (as seen in class).  No regex library is used:
 *           every pattern below is written as a regular expression that Flex
 *           compiles into a single deterministic finite automaton (DFA).
 *
 *  WHAT THIS FILE DOES
 *    Reads a Triton source file character by character and produces:
 *      (1) the SEQUENCE OF TOKENS, one row per lexeme, with its Token ID and,
 *          for identifiers, a reference into the symbol table;
 *      (2) the SYMBOL TABLE of all distinct identifiers (printed at EOF);
 *      (3) a clear ERROR MESSAGE for every symbol that does not belong to the
 *          language.
 *
 *  A LEX FILE HAS THREE SECTIONS, separated by %% :
 *      DEFINITION SECTION  -> C declarations + %options + named patterns
 *      RULES SECTION       -> pattern { action } pairs
 *      USER CODE SECTION   -> ordinary C (here: classifier, emitter, main)
 *
 *  RELATION WITH OTHER FILES
 *    - tokens.h / tokens.c : the Token IDs and their printable names.
 *    - symtab.h / symtab.c : the symbol table this scanner fills.
 * ==========================================================================*/


/* ======================= 1. DEFINITION SECTION ===========================*/
%{
#include <stdio.h>
#include <string.h>
#include "tokens.h"
#include "symtab.h"

/* Flex defines and maintains this for us because of "%option yylineno".
 * We declare it extern so the helper functions below can read it.           */
extern int yylineno;

/* Running counters used in the final summary.                               */
static long g_token_count = 0;   /* number of valid tokens emitted           */
static long g_error_count = 0;   /* number of unknown-symbol errors          */

/* ---- Reserved-word tables -------------------------------------------------
 * The classic technique seen in class: the scanner has ONE rule for the
 * "word" shape {ID}.  When a word is matched, we look it up in these tables
 * to decide whether it is a reserved word or a plain identifier.  This keeps
 * the rule section short and the reserved-word list easy to maintain.
 * Each table ends with a NULL sentinel so the lookup loop knows where to stop.
 * --------------------------------------------------------------------------*/

/* Python keywords that a Triton kernel actually needs. Unnecessary Python
 * keywords (lambda, yield, try, class, ...) are intentionally left out, as
 * the specification asks us to include only what is required for the goal.  */
static const char *const keywords[] = {
    "def", "return", "if", "elif", "else", "for", "while", "in",
    "import", "from", "as", "pass", "and", "or", "not", "is",
    "None", "True", "False", NULL
};

/* The two Triton namespaces.  Recognising them as a dedicated token class is
 * what makes the token stream "Triton-oriented": every Triton built-in call
 * appears as  NAMESPACE DOT IDENTIFIER  (e.g.  tl . load ).                  */
static const char *const namespaces[] = {
    "triton", "tl", NULL
};

/* Triton scalar data types and the compile-time-constant marker constexpr.  */
static const char *const types[] = {
    "constexpr",
    "float16", "float32", "float64", "bfloat16",
    "int8", "int16", "int32", "int64",
    "uint8", "uint16", "uint32", "uint64",
    "bool", NULL
};

/* Linear membership test in a NULL-terminated string table.                 */
static int in_table(const char *word, const char *const table[])
{
    for (int i = 0; table[i] != NULL; i++)
        if (strcmp(word, table[i]) == 0)
            return 1;
    return 0;
}

/* Decide the category of a word matched by the {ID} pattern.
 * Order matters only for readability here, because the three tables are
 * disjoint (no string belongs to two of them).                             */
static TokenId classify_word(const char *word)
{
    if (in_table(word, keywords))   return T_KEYWORD;
    if (in_table(word, namespaces)) return T_NAMESPACE;
    if (in_table(word, types))      return T_TYPE;
    return T_IDENTIFIER;            /* default: a user-defined name           */
}

/* Print one row of the token sequence.
 *   id     : the Token ID (see tokens.h)
 *   lexeme : the exact text matched (yytext)
 *   attr   : extra attribute, or NULL.  For identifiers we pass the symbol
 *            table reference ("#3"); for everything else it is "-".
 * The columns mirror the <token, attribute> pair notation used in class.    */
static void emit(TokenId id, const char *lexeme, const char *attr)
{
    g_token_count++;
    printf(" %-5d  %-3d  %-11s  %-22s  %s\n",
           yylineno, (int)id, token_name(id), lexeme, attr ? attr : "-");
}

/* Header printed once, above the token rows.                                */
static void print_header(void)
{
    printf("================= SEQUENCE OF TOKENS =================\n");
    printf(" %-5s  %-3s  %-11s  %-22s  %s\n",
           "LINE", "ID", "TOKEN", "LEXEME", "SYMTAB");
    printf(" %-5s  %-3s  %-11s  %-22s  %s\n",
           "-----", "---", "-----------", "----------------------", "------");
}
%}

/* ---- Flex options --------------------------------------------------------
 *   yylineno          : keep an automatic 1-based line counter in yylineno.
 *   noinput / nounput : do not emit the input()/unput() helper functions
 *                       (we never call them), which keeps -Wall output clean.
 * --------------------------------------------------------------------------*/
%option yylineno
%option noinput nounput

/* ---- Named regular expressions -------------------------------------------
 * Giving names to common sub-patterns makes the rules section read almost
 * like the formal lexical specification in the report.                      */
DIGIT   [0-9]
LETTER  [A-Za-z_]
ID      {LETTER}({LETTER}|{DIGIT})*
INT     {DIGIT}+
FLOAT   {DIGIT}+"."{DIGIT}+([eE][+-]?{DIGIT}+)?|{DIGIT}+[eE][+-]?{DIGIT}+
WS      [ \t\r]+

/* Exclusive start condition used to swallow triple-quoted docstrings.
 * "%x" means that while we are inside DOCSTRING only the <DOCSTRING> rules
 * are active, so the normal rules cannot accidentally fire on the body.     */
%x DOCSTRING


/* ========================== 2. RULES SECTION =============================*/
%%

 /* ----- whitespace, line breaks and comments: skipped, no token emitted -- */
{WS}              { /* spaces, tabs and CR carry no token                  */ }
\n                { /* newline: yylineno was already advanced by Flex      */ }
"#".*             { /* line comment: from '#' up to (but not incl.) EOL    */ }

 /* ----- triple-quoted docstrings are documentation, not code: skip them -- */
\"\"\"            { BEGIN(DOCSTRING); }   /* enter docstring mode on """      */
'''               { BEGIN(DOCSTRING); }   /* ... or on '''                    */
<DOCSTRING>\"\"\"  { BEGIN(INITIAL);  }   /* leave docstring mode             */
<DOCSTRING>'''     { BEGIN(INITIAL);  }
<DOCSTRING>\n      { /* keep counting source lines (yylineno auto)         */ }
<DOCSTRING>.       { /* swallow every other character of the docstring     */ }

 /* ----- single-line string literals -------------------------------------- *
  * A string is a quote, any run of non-quote / escaped chars, then a quote.
  * Newlines are excluded so an unterminated string cannot eat the rest of
  * the file. Both " and ' are supported, mirroring Python.                  */
\"([^\"\\\n]|\\.)*\"   { emit(T_STRING, yytext, NULL); }
'([^'\\\n]|\\.)*'      { emit(T_STRING, yytext, NULL); }

 /* ----- numeric literals (FLOAT listed first; longest-match still decides) */
{FLOAT}           { emit(T_FLOAT, yytext, NULL); }
{INT}             { emit(T_INT,   yytext, NULL); }

 /* ----- decorator marker -------------------------------------------------- *
  * '@' introduces a decorator. The decorated name (e.g. triton.jit) then
  * flows as the tokens NAMESPACE DOT IDENTIFIER, so @triton.jit becomes
  *      AT  NAMESPACE(triton)  DOT  IDENTIFIER(jit).                         */
"@"               { emit(T_AT, yytext, NULL); }

 /* ----- multi-character operators (placed before their 1-char prefixes) -- */
"**"              { emit(T_DSTAR,   yytext, NULL); }
"//"              { emit(T_DSLASH,  yytext, NULL); }
"=="              { emit(T_EQ,      yytext, NULL); }
"!="              { emit(T_NEQ,     yytext, NULL); }
"<="              { emit(T_LE,      yytext, NULL); }
">="              { emit(T_GE,      yytext, NULL); }
"+="              { emit(T_PLUSEQ,  yytext, NULL); }
"-="              { emit(T_MINUSEQ, yytext, NULL); }
"*="              { emit(T_STAREQ,  yytext, NULL); }
"/="              { emit(T_SLASHEQ, yytext, NULL); }
"->"              { emit(T_ARROW,   yytext, NULL); }

 /* ----- single-character operators --------------------------------------- */
"="               { emit(T_ASSIGN,  yytext, NULL); }
"+"               { emit(T_PLUS,    yytext, NULL); }
"-"               { emit(T_MINUS,   yytext, NULL); }
"*"               { emit(T_STAR,    yytext, NULL); }
"/"               { emit(T_SLASH,   yytext, NULL); }
"%"               { emit(T_PERCENT, yytext, NULL); }
"<"               { emit(T_LT,      yytext, NULL); }
">"               { emit(T_GT,      yytext, NULL); }

 /* ----- delimiters / punctuation ----------------------------------------- */
"("               { emit(T_LPAREN,    yytext, NULL); }
")"               { emit(T_RPAREN,    yytext, NULL); }
"["               { emit(T_LBRACKET,  yytext, NULL); }
"]"               { emit(T_RBRACKET,  yytext, NULL); }
"{"               { emit(T_LBRACE,    yytext, NULL); }
"}"               { emit(T_RBRACE,    yytext, NULL); }
","               { emit(T_COMMA,     yytext, NULL); }
":"               { emit(T_COLON,     yytext, NULL); }
"."               { emit(T_DOT,       yytext, NULL); }
";"               { emit(T_SEMICOLON, yytext, NULL); }

 /* ----- words: keyword / namespace / type / identifier ------------------- *
  * One rule recognises the shape of any word; classify_word() then tells us
  * which of the four word categories it is. Only true identifiers are stored
  * in the symbol table (and only there do we attach a "#index" attribute).  */
{ID}              {
                      TokenId id = classify_word(yytext);
                      if (id == T_IDENTIFIER) {
                          int idx = sym_insert(yytext, yylineno);
                          char ref[32];
                          snprintf(ref, sizeof ref, "#%d", idx);
                          emit(T_IDENTIFIER, yytext, ref);
                      } else {
                          emit(id, yytext, NULL);
                      }
                  }

 /* ----- catch-all: any remaining single character is a lexical error ----- *
  * The regex '.' matches one character except newline, so this rule fires on
  * symbols outside the Triton alphabet (e.g. '$', '?', '\'). It must be the
  * LAST rule: every legal single character already has its own rule above,
  * and on equal match length Flex prefers the earlier rule.                 */
.                 {
                      g_error_count++;
                      fprintf(stderr,
                          "Lexical error (line %d): unknown symbol '%s'\n",
                          yylineno, yytext);
                  }
%%


/* ======================= 3. USER CODE SECTION ============================*/

/* Program entry point.
 *   - With a filename argument, scan that file.
 *   - Otherwise scan standard input (handy for quick manual tests).
 * yylex() runs the DFA until end of input; none of our rules call return,
 * so it processes the whole file and only then hands control back here.     */
int main(int argc, char **argv)
{
    /* Line-buffer stdout so that error messages (written to stderr) appear in
     * the correct position relative to the token rows when both streams are
     * viewed together, e.g.   ./triton_scanner file.py 2>&1                  */
    setvbuf(stdout, NULL, _IOLBF, 0);

    if (argc > 1) {
        yyin = fopen(argv[1], "r");
        if (yyin == NULL) {
            fprintf(stderr, "error: cannot open input file '%s'\n", argv[1]);
            return 1;
        }
        printf("Scanning file: %s\n", argv[1]);
    } else {
        printf("Scanning standard input (press Ctrl-D to finish):\n");
    }

    print_header();
    yylex();                 /* drive the scanner over the entire input      */
    sym_print();             /* dump the symbol table built along the way    */

    printf("\nTOTAL tokens: %ld   |   Lexical errors: %ld\n",
           g_token_count, g_error_count);

    if (yyin != NULL && yyin != stdin)
        fclose(yyin);

    /* Exit status: 0 if clean, 1 if any lexical error was reported.         */
    return (g_error_count > 0) ? 1 : 0;
}

/* yywrap() is called when the scanner reaches EOF. Returning 1 means "there
 * is no further input", so scanning stops. We have a single input source,
 * hence the constant 1 (this is the form shown in the course material).     */
int yywrap(void)
{
    return 1;
}
