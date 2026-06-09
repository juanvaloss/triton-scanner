/* ============================================================================
 * symtab.h  --  Symbol-table interface for the Triton compiler
 * ----------------------------------------------------------------------------
 * PURPOSE
 *   The symbol table stores one entry per distinct identifier the compiler
 *   sees in the source.  It is filled in two complementary ways:
 *
 *     sym_declare(name, line)  - called by parser actions when a name is
 *                                INTRODUCED: as an assignment target, a
 *                                function parameter, an imported name, a
 *                                def name.
 *
 *     sym_use(name, line)      - called by parser actions when a name is
 *                                USED in an expression: as the value on the
 *                                right of an assignment, as an argument to
 *                                a call, etc.
 *
 *   Distinguishing the two lets the semantic phase detect identifiers that
 *   are USED but never DECLARED, which is the classic semantic check
 *   covered in class.
 *
 * RELATION WITH OTHER FILES
 *   - triton_parser.y : the only caller of sym_declare/sym_use.
 *   - semantic.c      : reads the table to perform the semantic checks.
 *   - tokens.h        : provides the TokenId used in each entry (always
 *                       IDENTIFIER in this phase).
 *
 * DATA STRUCTURE
 *   A fixed-capacity array searched linearly.  Same rationale as in Step I:
 *   smallest structure that meets the requirement, trivial to explain, fast
 *   enough for the size of inputs we expect.  Future work: hash table.
 * ==========================================================================*/

#ifndef SYMTAB_H
#define SYMTAB_H

#define SYM_MAX_ENTRIES 512
#define SYM_MAX_NAME    128

typedef struct {
    char name[SYM_MAX_NAME];
    int  first_line;     /* line of first occurrence                       */
    int  use_count;      /* number of times appearing as a use             */
    int  declared;       /* 1 if ever appeared on the declaring side       */
    int  declare_line;   /* line where it was first declared, or -1        */
} SymbolEntry;

/* Lookup by name; returns table index or -1 if absent.                    */
int sym_lookup(const char *name);

/* Mark the name as DECLARED on the given line.  Creates the entry if new;
 * if the name was already used before being declared, the existing entry
 * is updated (declared = 1, declare_line = line).                          */
int sym_declare(const char *name, int line);

/* Mark the name as USED on the given line.  Creates the entry if new (with
 * declared = 0); increments use_count.                                     */
int sym_use(const char *name, int line);

/* Print the table at end of compilation (called by main).                  */
void sym_print(void);

/* Number of distinct identifiers stored.                                   */
int sym_size(void);

/* Accessor for the semantic phase: read entry by index.  Returns NULL if
 * the index is out of range.                                               */
const SymbolEntry *sym_get(int idx);

#endif /* SYMTAB_H */
