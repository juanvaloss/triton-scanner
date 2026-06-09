/* ============================================================================
 * symtab.h  --  Symbol-table interface for the Triton lexical analyzer
 * ----------------------------------------------------------------------------
 * PURPOSE
 *   Declares the symbol table the scanner builds while it reads the source
 *   file.  The lexical phase only needs a *preliminary* symbol table: one
 *   entry per distinct identifier (variable names, function names, kernel
 *   parameters).  Later phases (parser, semantic analysis) will enrich each
 *   entry with type, scope, etc.  For Step I we record what the lexer can
 *   actually know: the name, that it is an IDENTIFIER, where it first appeared,
 *   and how many times it was seen.
 *
 * RELATION WITH OTHER FILES
 *   - symtab.c          : implements every function declared here.
 *   - tokens.h          : provides the TokenId stored in each entry.
 *   - triton_scanner.l  : calls sym_insert() for each identifier and
 *                         sym_print() once, at end of input.
 *
 * DATA STRUCTURE CHOICE
 *   A fixed-capacity array searched linearly.  Rationale:
 *     * It is the smallest structure that satisfies the requirement.
 *     * It is trivial to explain and to reason about in an oral exam.
 *     * Source files for a single kernel hold only tens of identifiers, so
 *       linear search is more than fast enough.
 *   A hash table would scale better and is noted as future work in the report.
 * ==========================================================================*/

#ifndef SYMTAB_H
#define SYMTAB_H

#include "tokens.h"

#define SYM_MAX_ENTRIES 512   /* maximum number of distinct identifiers      */
#define SYM_MAX_NAME    128   /* maximum identifier length we store           */

/* One row of the symbol table. */
typedef struct {
    char    name[SYM_MAX_NAME]; /* the identifier lexeme                      */
    TokenId token_id;           /* always T_IDENTIFIER in this phase          */
    int     first_line;         /* line number of the first occurrence        */
    int     count;              /* how many times the identifier appeared     */
} SymbolEntry;

/* Look up an identifier by name.
 * Returns its index in the table, or -1 if it is not present.                */
int  sym_lookup(const char *name);

/* Insert an identifier seen on the given line.
 *   - If it is new, a fresh entry is created and its index returned.
 *   - If it already exists, its occurrence counter is incremented and the
 *     existing index is returned.
 * Returns the table index, or -1 if the table is full.                       */
int  sym_insert(const char *name, int line);

/* Print the whole symbol table as a formatted block (called once at EOF).    */
void sym_print(void);

/* Number of distinct identifiers currently stored (useful for the summary).  */
int  sym_size(void);

#endif /* SYMTAB_H */
