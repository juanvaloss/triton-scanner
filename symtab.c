/* ============================================================================
 * symtab.c  --  Symbol-table implementation (array + linear search)
 * ----------------------------------------------------------------------------
 * Implements symtab.h.  Same algorithmic choices as Step I (linear scan
 * over a fixed array) plus the new declared / used distinction needed by
 * the semantic phase.
 * ==========================================================================*/

#include <stdio.h>
#include <string.h>
#include "symtab.h"
#include "tokens.h"

static SymbolEntry table[SYM_MAX_ENTRIES];
static int         n_entries = 0;

int sym_lookup(const char *name)
{
    for (int i = 0; i < n_entries; i++)
        if (strcmp(table[i].name, name) == 0)
            return i;
    return -1;
}

/* Create a fresh row for a name not yet in the table.  Returns its index
 * or -1 if the table is full.                                              */
static int new_entry(const char *name, int line)
{
    if (n_entries >= SYM_MAX_ENTRIES) {
        fprintf(stderr, "symtab: table full (%d), cannot store '%s'\n",
                SYM_MAX_ENTRIES, name);
        return -1;
    }
    int idx = n_entries++;
    strncpy(table[idx].name, name, SYM_MAX_NAME - 1);
    table[idx].name[SYM_MAX_NAME - 1] = '\0';
    table[idx].first_line   = line;
    table[idx].use_count    = 0;
    table[idx].declared     = 0;
    table[idx].declare_line = -1;
    return idx;
}

int sym_declare(const char *name, int line)
{
    int idx = sym_lookup(name);
    if (idx == -1) idx = new_entry(name, line);
    if (idx == -1) return -1;
    if (!table[idx].declared) {
        table[idx].declared     = 1;
        table[idx].declare_line = line;
    }
    return idx;
}

int sym_use(const char *name, int line)
{
    int idx = sym_lookup(name);
    if (idx == -1) idx = new_entry(name, line);
    if (idx == -1) return -1;
    table[idx].use_count++;
    return idx;
}

int sym_size(void) { return n_entries; }

const SymbolEntry *sym_get(int idx)
{
    if (idx < 0 || idx >= n_entries) return NULL;
    return &table[idx];
}

void sym_print(void)
{
    printf("\n=================== SYMBOL TABLE ===================\n");
    printf(" %-4s  %-22s  %-9s  %-9s  %s\n",
           "IDX", "NAME", "DECLARED", "DECL-LINE", "USE-COUNT");
    printf(" %-4s  %-22s  %-9s  %-9s  %s\n",
           "----", "----------------------", "--------",
           "---------", "---------");
    for (int i = 0; i < n_entries; i++) {
        char dl[16];
        if (table[i].declared)
            snprintf(dl, sizeof dl, "%d", table[i].declare_line);
        else
            snprintf(dl, sizeof dl, "-");
        printf(" %-4d  %-22s  %-9s  %-9s  %d\n",
               i,
               table[i].name,
               table[i].declared ? "yes" : "NO",
               dl,
               table[i].use_count);
    }
    printf("====================================================\n");
    printf("Distinct identifiers: %d\n", n_entries);
}
