/* ============================================================================
 *  triton_parser.y  --  Syntax analyzer for Triton GPU kernels (simple version)
 * ----------------------------------------------------------------------------
 *  COURSE : TC3002B - Module #3 Compilers
 *  PHASE  : Step II (Syntax Analysis) - bottom-up LALR(1) via GNU Bison
 *
 *  WHAT THIS GRAMMAR RECOGNIZES
 *    The structural shape of a Triton kernel file:
 *      - imports         (import X / import X as Y / from X import Y)
 *      - decorators      (@name or @name.attr or @name(...))
 *      - function header (def name(params) -> type:)
 *      - simple stmts    (assignments, returns, expression statements)
 *      - expressions     (arithmetic +-*\/, comparisons, calls, indexing,
 *                         attribute access, literals)
 *
 *  WHAT IT DOES NOT RECOGNIZE (documented future work)
 *    - Indented nested bodies (no INDENT/DEDENT)
 *    - Control flow (if / for / while)
 *    - Augmented assignments (+=, -=, ...)
 *    - Boolean operators (and / or / not)
 *    - True / False / None as built-in constants
 *    - Multi-line expressions (the scanner emits NEWLINE on every '\n')
 *
 *  KEY DESIGN DECISION
 *    A single 'primary' non-terminal recursively accumulates DOT, LPAREN,
 *    and LBRACKET postfix operators.  This is what makes 'tl.load(...)'
 *    parse without LALR conflicts.
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

long g_syntax_error_count = 0;

void yyerror(const char *msg) {
    fprintf(stderr, "Syntax error (line %d): %s\n", yylineno, msg);
    g_syntax_error_count++;
}
%}

%union {
    char *str;     /* lexeme for IDENTIFIER, NAMESPACE, TYPE, STRING_LIT */
    long  ival;    /* INT_LIT value                                       */
    double dval;   /* FLOAT_LIT value                                     */
}

%token <str> IDENTIFIER NAMESPACE TYPE STRING_LIT
%token <ival> INT_LIT
%token <dval> FLOAT_LIT

%token KW_DEF KW_RETURN KW_IMPORT KW_FROM KW_AS

%token AT
%token ASSIGN
%token EQ NEQ LT GT LE GE
%token PLUS MINUS STAR SLASH
%token LPAREN RPAREN LBRACKET RBRACKET
%token COMMA COLON DOT ARROW
%token NEWLINE

%type <str> name_token

/* Precedences, lowest to highest.  These resolve every shift/reduce
 * conflict in the flat 'expr' rule below.                                  */
%nonassoc EQ NEQ LT GT LE GE
%left PLUS MINUS
%left STAR SLASH
%right UMINUS

%start program

%%

/* ==================== TOP LEVEL ==========================================*/

program
    : items
    ;

items
    : /* empty */
    | items item
    ;

item
    : stmt
    | NEWLINE                       /* blank line is tolerated             */
    ;

stmt
    : simple_stmt NEWLINE
    | decorator NEWLINE             { sem_record_decorator(yylineno); }
    | func_header NEWLINE           { sem_record_def(yylineno); }
    | error NEWLINE                 { yyerrok; }
    ;

simple_stmt
    : import_stmt
    | assignment
    | return_stmt
    | expr                          /* expression statement                */
    ;

/* ==================== IMPORTS ============================================*/

import_stmt
    : KW_IMPORT dotted_name
    | KW_IMPORT dotted_name KW_AS name_token   { sym_declare($4, yylineno); free($4); }
    | KW_FROM dotted_name KW_IMPORT name_token { sym_declare($4, yylineno); free($4); }
    ;

name_token
    : IDENTIFIER                    { $$ = $1; }
    | NAMESPACE                     { $$ = $1; }
    ;

dotted_name
    : name_token                    { free($1); }
    | dotted_name DOT name_token    { free($3); }
    ;

/* ==================== DECORATORS AND FUNCTIONS ===========================*/

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

param
    : IDENTIFIER                                { sym_declare($1, yylineno); free($1); }
    | IDENTIFIER COLON type_expr                { sym_declare($1, yylineno); free($1); }
    | IDENTIFIER ASSIGN expr                    { sym_declare($1, yylineno); free($1); }
    | IDENTIFIER COLON type_expr ASSIGN expr    { sym_declare($1, yylineno); free($1); }
    ;

return_type_opt
    : /* empty */
    | ARROW type_expr
    ;

type_expr
    : primary                       /* tl.constexpr, float32, etc.         */
    ;

/* ==================== ASSIGNMENTS ========================================*/

assignment
    : IDENTIFIER ASSIGN expr        { sym_declare($1, yylineno); free($1); }
    ;

return_stmt
    : KW_RETURN
    | KW_RETURN expr
    ;

/* ==================== EXPRESSIONS ========================================*/

expr
    : expr PLUS expr
    | expr MINUS expr
    | expr STAR expr
    | expr SLASH expr
    | expr EQ expr
    | expr NEQ expr
    | expr LT expr
    | expr GT expr
    | expr LE expr
    | expr GE expr
    | MINUS expr   %prec UMINUS
    | primary
    ;

/* 'primary' chains the postfix operators (DOT, LPAREN, LBRACKET) in a
 * single recursive non-terminal.  This is the key trick that makes
 * 'tl.load(x, mask=m)' parse without LALR conflicts.                       */
primary
    : IDENTIFIER                              { sym_use($1, yylineno); free($1); }
    | NAMESPACE                               { free($1); }
    | TYPE                                    { free($1); }
    | INT_LIT
    | FLOAT_LIT
    | STRING_LIT                              { free($1); }
    | LPAREN expr RPAREN
    | primary DOT IDENTIFIER                  { free($3); }
    | primary DOT NAMESPACE                   { free($3); }
    | primary DOT TYPE                        { free($3); }
    | primary LPAREN arg_list_opt RPAREN      /* call                      */
    | primary LBRACKET expr RBRACKET          /* indexing                  */
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
    : expr
    | IDENTIFIER ASSIGN expr        { /* keyword argument */ free($1); }
    ;

%%
