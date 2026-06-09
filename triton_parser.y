/* ============================================================================
 *  triton_parser.y  --  Syntax analyzer (parser) for Triton GPU kernels
 * ----------------------------------------------------------------------------
 *  COURSE : TC3002B - Module #3 Compilers
 *  PHASE  : Step II (Syntax Analysis) - builds on the Step I scanner
 *  TOOL   : GNU Bison (the modern Yacc).  We use a bottom-up LALR(1) parser
 *           because (a) Yacc/Bison is the tool taught in class, (b) LALR(1)
 *           handles left recursion naturally, which makes a precedence-encoded
 *           expression grammar straightforward to write, and (c) the class
 *           notes on bottom-up parsing (shift-reduce, LR(0), SLR(1)) describe
 *           exactly this family of parsers.
 *
 *  WHAT THIS FILE DOES
 *    Consumes the token stream produced by the scanner and validates the
 *    *syntactic structure* of a Triton source file (imports, decorators,
 *    function headers, assignments, expressions, calls, returns).  Reports
 *    SYNTAX ERRORS with line number when the structure is invalid.
 *
 *  DESIGN DECISION: FLAT (NON-NESTED) GRAMMAR
 *    Real Python uses INDENT/DEDENT tokens to mark nested function bodies.
 *    Implementing them at the scanner level adds substantial complexity
 *    (stack of indentation levels, virtual tokens at end-of-line, dedent on
 *    EOF). Per the project brief - "do not make this too complex" - we use a
 *    FLAT grammar: every statement is top-level. This means we validate that
 *    each statement is well-formed individually (imports, decorator, def
 *    header, assignment, return, expression-statement), but the HIERARCHICAL
 *    nesting of bodies inside a def is not modelled here. INDENT/DEDENT
 *    handling is explicitly listed as future work in the report.
 *
 *  GRAMMAR HIGHLIGHTS
 *    - Left-recursive expression grammar with precedence (E -> E op T -> ...).
 *      This is exactly the form bottom-up parsers like best, per the notes.
 *    - Two explicit precedence levels for arithmetic, one for comparisons,
 *      one for boolean ops.  %left / %right / %nonassoc resolve all
 *      shift/reduce conflicts that would otherwise arise from the flat
 *      expression form, exactly as the class notes describe.
 *    - NEWLINE is a real token (emitted by the scanner when paren depth = 0)
 *      and acts as a statement terminator, mirroring Python's line-oriented
 *      structure.  Inside parentheses/brackets/braces the scanner suppresses
 *      NEWLINE so that multi-line expressions parse correctly.
 *
 *  RELATION WITH OTHER FILES
 *    - triton_scanner.l : provides the tokens this parser consumes.
 *    - tokens.h / .c    : token catalogue, names, display IDs.
 *    - symtab.h / .c    : symbol table; parser actions call sym_declare()
 *                         for declared names and sym_use() for uses.
 *    - semantic.h / .c  : performs the two post-parse semantic checks
 *                         (orphan decorator, identifier used but never
 *                         declared).
 * ==========================================================================*/

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "tokens.h"
#include "symtab.h"
#include "semantic.h"

extern int yylex(void);
extern int yylineno;
extern FILE *yyin;

/* Counts used in the final summary. */
long g_syntax_error_count = 0;

/* yyerror is called by Bison whenever a syntax error is detected.
 * We print the message with line number and increment our counter; the
 * default %error rule then resynchronises the parser to NEWLINE so that one
 * bad statement does not abort the whole file (error recovery, as in the
 * class notes). */
void yyerror(const char *msg) {
    fprintf(stderr, "Syntax error (line %d): %s\n", yylineno, msg);
    g_syntax_error_count++;
}
%}

/* ---- Semantic values ------------------------------------------------------
 * Bison's %union defines the C type associated with each token / non-terminal
 * value.  We carry the lexeme string for names and the line number for
 * identifier uses (so we can report them with a precise location). */
%union {
    char *str;     /* lexeme text (allocated with strdup, freed at EOF)     */
    long  ival;    /* integer literal value                                  */
    double dval;   /* floating literal value                                 */
}

/* ---- Tokens with semantic values ------------------------------------------
 * Bison numbers these starting at 258 (after the ASCII range).  We don't
 * reference those numbers directly - tokens.c maps each one to a friendly
 * display ID (1..N) used by the printed token stream. */
%token <str> IDENTIFIER NAMESPACE TYPE STRING_LIT
%token <ival> INT_LIT
%token <dval> FLOAT_LIT

/* ---- Tokens without semantic values --------------------------------------
 * KW_* are the individual Python keywords (each has its own token rather
 * than a single "KEYWORD" class, because the PARSER needs to know which one
 * it is - e.g. DEF triggers a function header rule, IMPORT triggers an
 * import rule, etc.).                                                       */
%token KW_DEF KW_RETURN KW_IF KW_ELIF KW_ELSE KW_FOR KW_WHILE KW_IN
%token KW_IMPORT KW_FROM KW_AS KW_PASS
%token KW_AND KW_OR KW_NOT KW_IS
%token KW_NONE KW_TRUE KW_FALSE

%token AT                                       /* @  (decorator marker)    */
%token ASSIGN PLUSEQ MINUSEQ STAREQ SLASHEQ     /* assignment family        */
%token EQ NEQ LT GT LE GE                       /* comparisons              */
%token PLUS MINUS STAR SLASH DSLASH PERCENT DSTAR
%token LPAREN RPAREN LBRACKET RBRACKET LBRACE RBRACE
%token COMMA COLON DOT SEMICOLON ARROW
%token NEWLINE                                  /* logical line terminator  */

/* ---- Non-terminals that carry a value -------------------------------------
 * Bison requires the type of any non-terminal whose semantic value we use
 * inside an action ($$, $1, $3, ...).  We only need this for the helper
 * non-terminal that bubbles up the name string of an IDENTIFIER / NAMESPACE
 * token to the import-rename rules.                                         */
%type <str> name_token

/* ---- Precedence and associativity ----------------------------------------
 * Listed from LOWEST to HIGHEST precedence, the standard way of resolving
 * the shift/reduce ambiguity in flat expression grammars (see the class
 * notes on ambiguity removal: instead of layering E/T/F by hand we declare
 * the precedences here, which is equivalent and much shorter).             */
%left KW_OR
%left KW_AND
%right KW_NOT
%nonassoc EQ NEQ LT GT LE GE
%left PLUS MINUS
%left STAR SLASH DSLASH PERCENT
%right DSTAR
%right UMINUS                                   /* unary minus              */

%start program

%%

/* ======================== TOP-LEVEL STRUCTURE =============================*/

/* A program is any number of "items".  Each item is either a real statement
 * (terminated by NEWLINE) or a lone NEWLINE (= blank line, tolerated).
 * This is the most permissive top-level shape: it accepts kernel files with
 * any amount of blank-line padding between statements.                     */
program
    : items
    ;

items
    : /* empty */
    | items item
    ;

item
    : stmt
    | NEWLINE                        /* tolerated blank line               */
    ;

/* A statement is either a simple one-line construct terminated by NEWLINE,
 * a decorator (which the semantic phase pairs with a following def), or a
 * function header. */
stmt
    : simple_stmt NEWLINE
    | decorator NEWLINE                  { sem_record_decorator(yylineno); }
    | func_header NEWLINE                { sem_record_def(yylineno); }
    | error NEWLINE                      { yyerrok; }   /* error recovery   */
    ;

simple_stmt
    : import_stmt
    | assignment
    | aug_assignment
    | return_stmt
    | expr_stmt
    | KW_PASS
    ;

/* ============================ IMPORTS =====================================*/

import_stmt
    : KW_IMPORT dotted_name
    | KW_IMPORT dotted_name KW_AS name_token       { sym_declare($4, yylineno); free($4); }
    | KW_FROM dotted_name KW_IMPORT name_token     { sym_declare($4, yylineno); free($4); }
    ;

/* "name_token" is any single name token (IDENTIFIER or NAMESPACE) returning
 * its string so semantic actions can use it. */
name_token
    : IDENTIFIER                       { $$ = $1; }
    | NAMESPACE                        { $$ = $1; }
    ;

dotted_name
    : name_token                       { free($1); }
    | dotted_name DOT name_token       { free($3); }
    ;

/* ====================== DECORATORS AND FUNCTIONS ==========================*/

decorator
    : AT dotted_name
    | AT dotted_name LPAREN arg_list_opt RPAREN
    ;

func_header
    : KW_DEF IDENTIFIER LPAREN param_list_opt RPAREN return_type_opt COLON
                                       { sym_declare($2, yylineno); free($2); }
    ;

param_list_opt
    : /* empty */
    | param_list
    ;

param_list
    : param
    | param_list COMMA param
    ;

/* Parameter shapes accepted:
 *    name
 *    name : type
 *    name = expr            (default value)
 *    name : type = expr
 * Each parameter name is recorded as a declared identifier. */
param
    : IDENTIFIER                                            { sym_declare($1, yylineno); free($1); }
    | IDENTIFIER COLON type_expr                            { sym_declare($1, yylineno); free($1); }
    | IDENTIFIER ASSIGN expr                                { sym_declare($1, yylineno); free($1); }
    | IDENTIFIER COLON type_expr ASSIGN expr                { sym_declare($1, yylineno); free($1); }
    ;

return_type_opt
    : /* empty */
    | ARROW type_expr
    ;

/* A type annotation is just a primary expression syntactically (e.g.
 * 'tl.constexpr', 'float32', 'tl.float16').  The semantic phase would
 * later check that the expression resolves to a real type.                  */
type_expr
    : primary
    ;

/* ======================== ASSIGNMENTS =====================================*/

assignment
    : IDENTIFIER ASSIGN expr            { sym_declare($1, yylineno); free($1); }
    ;

aug_assignment
    : IDENTIFIER PLUSEQ expr            { sym_use($1, yylineno); free($1); }
    | IDENTIFIER MINUSEQ expr           { sym_use($1, yylineno); free($1); }
    | IDENTIFIER STAREQ expr            { sym_use($1, yylineno); free($1); }
    | IDENTIFIER SLASHEQ expr           { sym_use($1, yylineno); free($1); }
    ;

/* ========================== RETURN ========================================*/

return_stmt
    : KW_RETURN
    | KW_RETURN expr
    ;

/* ===================== EXPRESSION STATEMENTS ==============================*/

expr_stmt
    : expr
    ;

/* =========================== EXPRESSIONS ==================================*/
/* Expression grammar uses precedence directives (declared above) to remove
 * the ambiguity of a flat form, exactly the technique the class notes on
 * ambiguity removal cover.  Left recursion is fine here because the parser
 * is LALR (bottom-up).                                                      */

expr
    : expr PLUS expr
    | expr MINUS expr
    | expr STAR expr
    | expr SLASH expr
    | expr DSLASH expr
    | expr PERCENT expr
    | expr DSTAR expr
    | expr EQ expr
    | expr NEQ expr
    | expr LT expr
    | expr GT expr
    | expr LE expr
    | expr GE expr
    | expr KW_AND expr
    | expr KW_OR expr
    | KW_NOT expr
    | MINUS expr   %prec UMINUS
    | primary
    ;

/* "primary" unifies atoms, attribute access (a.b), calls (f(...)) and
 * indexing (x[i]).  The recursive shape "primary OP suffix" is the standard
 * LALR-friendly way of chaining postfix operators without ambiguity:
 *
 *     tl.load(x_ptr + offsets, mask=mask)
 *        \__/\___________________________/
 *      primary . IDENTIFIER         primary ( args )
 *
 *     a.b.c[0]   parses as   (((a.b).c)[0])   left-to-right.
 *
 * This single-non-terminal approach replaces the separate atom / call /
 * indexing / dotted_attr rules I had originally, which produced LALR
 * conflicts at "name . name (" because the parser could not decide whether
 * the dotted name was a value or the start of a call.                       */
primary
    : IDENTIFIER                                  { sym_use($1, yylineno); free($1); }
    | NAMESPACE                                   { free($1); }
    | TYPE                                        { free($1); }
    | INT_LIT
    | FLOAT_LIT
    | STRING_LIT                                  { free($1); }
    | KW_TRUE
    | KW_FALSE
    | KW_NONE
    | LPAREN expr RPAREN
    | LBRACKET RBRACKET
    | LBRACKET expr_list RBRACKET
    | primary DOT IDENTIFIER                      { free($3); }
    | primary DOT NAMESPACE                       { free($3); }
    | primary DOT TYPE                            { free($3); }
    | primary LPAREN arg_list_opt RPAREN          /* function / method call */
    | primary LBRACKET expr RBRACKET              /* indexing               */
    ;

arg_list_opt
    : /* empty */
    | arg_list
    ;

arg_list
    : arg
    | arg_list COMMA arg
    ;

arg
    : expr                              /* positional argument              */
    | IDENTIFIER ASSIGN expr            { /* keyword argument */ free($1); }
    ;

expr_list
    : expr
    | expr_list COMMA expr
    ;

%%

/* The rest of the program (main, mode handling, output formatting) lives in
 * main.c so this file stays focused on the grammar.  Bison generates
 * triton_parser.tab.c and triton_parser.tab.h from this specification.    */
