/* ============================================================================
 * tokens.h  --  Token catalogue for the Triton GPU-kernel lexical analyzer
 * ----------------------------------------------------------------------------
 * PURPOSE
 *   This header is the single source of truth for *what tokens exist* in our
 *   reduced Triton language.  Every other source file in the project refers to
 *   tokens through the symbolic names declared here, never through "magic
 *   numbers".  This keeps the lexer (triton_scanner.l), the symbol table
 *   (symtab.c) and the reporting code in agreement.
 *
 * RELATION WITH OTHER FILES
 *   - tokens.c          : implements token_name(), the human-readable label
 *                         printed for each Token ID.
 *   - triton_scanner.l  : the Flex rules return / print these Token IDs.
 *   - symtab.{h,c}      : stores the Token ID of each identifier it keeps.
 *
 * DESIGN NOTE (Token ID numbering)
 *   IDs are small consecutive integers starting at 1.  Small IDs make the
 *   "Sequence of Tokens" output and the Transition Table in the report easy to
 *   read.  Because this phase is a *stand-alone* scanner (there is no Yacc
 *   parser yet), the IDs do not need to avoid the ASCII range the way they
 *   would if Bison were generating them in y.tab.h.
 * ==========================================================================*/

#ifndef TOKENS_H
#define TOKENS_H

/* The order of this enum MUST match the order of the names array in tokens.c,
 * because token_name() indexes that array with (id - 1).                     */
typedef enum {
    /* --- word-like tokens (recognised by the identifier rule + classifier) */
    T_KEYWORD = 1,   /* def return if elif else for while in import from ...  */
    T_NAMESPACE,     /* the Triton namespaces:  triton , tl                   */
    T_TYPE,          /* Triton dtypes / constexpr: float32, int32, constexpr  */
    T_IDENTIFIER,    /* user names: variables, function names, parameters     */

    /* --- literals                                                          */
    T_INT,           /* integer literal:        0  16  1024                   */
    T_FLOAT,         /* floating literal:        1.0  0.5  1e-3               */
    T_STRING,        /* single-line string:     "msg"  'x'                    */

    /* --- the decorator marker                                              */
    T_AT,            /* '@'  -- begins a decorator such as @triton.jit        */

    /* --- arithmetic / assignment operators                                 */
    T_ASSIGN,        /* =                                                     */
    T_PLUS,          /* +                                                     */
    T_MINUS,         /* -                                                     */
    T_STAR,          /* *                                                     */
    T_SLASH,         /* /                                                     */
    T_DSLASH,        /* //   (integer / floor division)                       */
    T_PERCENT,       /* %                                                     */
    T_DSTAR,         /* **   (power)                                          */

    /* --- comparison operators                                              */
    T_EQ,            /* ==                                                    */
    T_NEQ,           /* !=                                                    */
    T_LT,            /* <                                                     */
    T_GT,            /* >                                                     */
    T_LE,            /* <=                                                    */
    T_GE,            /* >=                                                    */

    /* --- augmented assignment (common inside kernels: acc += ...)          */
    T_PLUSEQ,        /* +=                                                    */
    T_MINUSEQ,       /* -=                                                    */
    T_STAREQ,        /* *=                                                    */
    T_SLASHEQ,       /* /=                                                    */

    /* --- delimiters / punctuation                                          */
    T_LPAREN,        /* (                                                     */
    T_RPAREN,        /* )                                                     */
    T_LBRACKET,      /* [                                                     */
    T_RBRACKET,      /* ]                                                     */
    T_LBRACE,        /* {                                                     */
    T_RBRACE,        /* }                                                     */
    T_COMMA,         /* ,                                                     */
    T_COLON,         /* :    (type hints, slices, block headers)              */
    T_DOT,           /* .    (attribute access, e.g. tl . load)               */
    T_SEMICOLON,     /* ;                                                     */
    T_ARROW,         /* ->   (return-type annotation)                         */

    T_TOKEN_COUNT    /* sentinel: number-of-tokens + 1 (NOT a real token)     */
} TokenId;

/* Returns the printable category label for a Token ID (e.g. "KEYWORD").
 * Used by the lexer when it prints the token stream.                         */
const char *token_name(TokenId id);

#endif /* TOKENS_H */
