/* ============================================================================
 * tokens.c  --  Human-readable labels for each Token ID
 * ----------------------------------------------------------------------------
 * PURPOSE
 *   Implements token_name() declared in tokens.h.  The lexer calls this to
 *   turn a numeric Token ID into the category string ("KEYWORD", "IDENTIFIER",
 *   ...) that appears in the "Sequence of Tokens" output.
 *
 * RELATION WITH OTHER FILES
 *   - tokens.h          : declares TokenId and this function.
 *   - triton_scanner.l  : calls token_name() while printing every token.
 *
 * MAINTENANCE RULE
 *   The names[] array is indexed by (id - 1).  Its order MUST stay identical
 *   to the TokenId enum in tokens.h.  Add a token in one place => add it in
 *   the other, in the same position.
 * ==========================================================================*/

#include "tokens.h"

/* Parallel array to the TokenId enum.  Index 0 corresponds to T_KEYWORD (==1),
 * which is why token_name() subtracts 1 before indexing.                     */
static const char *names[] = {
    "KEYWORD",      /* T_KEYWORD    */
    "NAMESPACE",    /* T_NAMESPACE  */
    "TYPE",         /* T_TYPE       */
    "IDENTIFIER",   /* T_IDENTIFIER */
    "INT_LIT",      /* T_INT        */
    "FLOAT_LIT",    /* T_FLOAT      */
    "STRING_LIT",   /* T_STRING     */
    "AT",           /* T_AT         */
    "ASSIGN",       /* T_ASSIGN     */
    "PLUS",         /* T_PLUS       */
    "MINUS",        /* T_MINUS      */
    "STAR",         /* T_STAR       */
    "SLASH",        /* T_SLASH      */
    "DSLASH",       /* T_DSLASH     */
    "PERCENT",      /* T_PERCENT    */
    "DSTAR",        /* T_DSTAR      */
    "EQ",           /* T_EQ         */
    "NEQ",          /* T_NEQ        */
    "LT",           /* T_LT         */
    "GT",           /* T_GT         */
    "LE",           /* T_LE         */
    "GE",           /* T_GE         */
    "PLUSEQ",       /* T_PLUSEQ     */
    "MINUSEQ",      /* T_MINUSEQ    */
    "STAREQ",       /* T_STAREQ     */
    "SLASHEQ",      /* T_SLASHEQ    */
    "LPAREN",       /* T_LPAREN     */
    "RPAREN",       /* T_RPAREN     */
    "LBRACKET",     /* T_LBRACKET   */
    "RBRACKET",     /* T_RBRACKET   */
    "LBRACE",       /* T_LBRACE     */
    "RBRACE",       /* T_RBRACE     */
    "COMMA",        /* T_COMMA      */
    "COLON",        /* T_COLON      */
    "DOT",          /* T_DOT        */
    "SEMICOLON",    /* T_SEMICOLON  */
    "ARROW"         /* T_ARROW      */
};

const char *token_name(TokenId id)
{
    /* Guard against out-of-range IDs so a programming mistake prints a clear
     * marker instead of reading past the array.                              */
    if (id < T_KEYWORD || id >= T_TOKEN_COUNT)
        return "??UNKNOWN??";
    return names[id - 1];
}
