/* ============================================================================
 * symtab.c  --  Symbol-table implementation (array + linear search)
 * ----------------------------------------------------------------------------
 * PURPOSE
 *   Implements the interface declared in symtab.h.  Builds the preliminary
 *   symbol table for the Triton scanner: one entry per distinct identifier.
 *
 * RELATION WITH OTHER FILES
 *   - symtab.h          : the interface this file implements.
 *   - triton_scanner.l  : the only caller of sym_insert()/sym_print().
 *
 * ALGORITHMS
 *   sym_lookup : linear scan comparing names with strcmp  -> O(n).
 *   sym_insert : lookup; if found, ++count; else append a new row -> O(n).
 *   sym_print  : iterate and print every row in insertion order  -> O(n).
 * ==========================================================================*/

#include <stdio.h>
#include <string.h>
#include "symtab.h"

/* The table itself plus a counter of how many rows are in use.
 * 'static' keeps these names private to this translation unit; the rest of
 * the program touches the table only through the functions below.           */
static SymbolEntry table[SYM_MAX_ENTRIES];
static int         n_entries = 0;

int sym_lookup(const char *name)
{
    for (int i = 0; i < n_entries; i++) {
        if (strcmp(table[i].name, name) == 0)
            return i;            /* found: return its index                  */
    }
    return -1;                   /* not present                              */
}

int sym_insert(const char *name, int line)
{
    /* Already known? Just count one more occurrence and reuse the index.     */
    int idx = sym_lookup(name);
    if (idx != -1) {
        table[idx].count++;
        return idx;
    }

    /* New identifier, but is there room left?                                */
    if (n_entries >= SYM_MAX_ENTRIES) {
        fprintf(stderr,
                "symtab: table full (%d entries), cannot store '%s'\n",
                SYM_MAX_ENTRIES, name);
        return -1;
    }

    /* Create a new row.  strncpy + explicit NUL guarantees no buffer overrun
     * even if the identifier were longer than SYM_MAX_NAME-1 characters.     */
    idx = n_entries++;
    strncpy(table[idx].name, name, SYM_MAX_NAME - 1);
    table[idx].name[SYM_MAX_NAME - 1] = '\0';
    table[idx].token_id   = T_IDENTIFIER;
    table[idx].first_line = line;
    table[idx].count      = 1;
    return idx;
}

int sym_size(void)
{
    return n_entries;
}

void sym_print(void)
{
    printf("\n");
    printf("=================== SYMBOL TABLE ===================\n");
    printf(" %-4s  %-24s  %-11s  %-9s  %s\n",
           "IDX", "NAME", "TOKEN", "1ST-LINE", "COUNT");
    printf(" %-4s  %-24s  %-11s  %-9s  %s\n",
           "----", "------------------------", "-----------",
           "---------", "-----");

    for (int i = 0; i < n_entries; i++) {
        printf(" %-4d  %-24s  %-11s  %-9d  %d\n",
               i,
               table[i].name,
               token_name(table[i].token_id),
               table[i].first_line,
               table[i].count);
    }
    printf("====================================================\n");
    printf("Distinct identifiers: %d\n", n_entries);
}
