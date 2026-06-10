/* ============================================================================
 * tokens.c  --  Token name + display id lookup
 * ==========================================================================*/

#include "tokens.h"

typedef struct {
    int         bison_id;
    int         display_id;
    const char *name;
} TokenInfo;

static const TokenInfo info[] = {
    /* keywords (5) */
    { KW_DEF,     1,  "KW_DEF"     },
    { KW_RETURN,  2,  "KW_RETURN"  },
    { KW_IMPORT,  3,  "KW_IMPORT"  },
    { KW_FROM,    4,  "KW_FROM"    },
    { KW_AS,      5,  "KW_AS"      },

    /* word-like categories (3) */
    { NAMESPACE,  6,  "NAMESPACE"  },
    { TYPE,       7,  "TYPE"       },
    { IDENTIFIER, 8,  "IDENTIFIER" },

    /* literals (3) */
    { INT_LIT,    9,  "INT_LIT"    },
    { FLOAT_LIT,  10, "FLOAT_LIT"  },
    { STRING_LIT, 11, "STRING_LIT" },

    /* decorator marker (1) */
    { AT,         12, "AT"         },

    /* operators (10) */
    { ASSIGN,     13, "ASSIGN"     },
    { PLUS,       14, "PLUS"       },
    { MINUS,      15, "MINUS"      },
    { STAR,       16, "STAR"       },
    { SLASH,      17, "SLASH"      },
    { EQ,         18, "EQ"         },
    { NEQ,        19, "NEQ"        },
    { LT,         20, "LT"         },
    { GT,         21, "GT"         },
    { LE,         22, "LE"         },
    { GE,         23, "GE"         },

    /* delimiters (8) */
    { LPAREN,     24, "LPAREN"     },
    { RPAREN,     25, "RPAREN"     },
    { LBRACKET,   26, "LBRACKET"   },
    { RBRACKET,   27, "RBRACKET"   },
    { COMMA,      28, "COMMA"      },
    { COLON,      29, "COLON"      },
    { DOT,        30, "DOT"        },
    { ARROW,      31, "ARROW"      },

    /* synchronisation (1) */
    { NEWLINE,    32, "NEWLINE"    }
};

static const int N_TOKENS = sizeof(info) / sizeof(info[0]);

const char *token_name(int bison_id)
{
    for (int i = 0; i < N_TOKENS; i++)
        if (info[i].bison_id == bison_id) return info[i].name;
    return "??";
}

int token_display_id(int bison_id)
{
    for (int i = 0; i < N_TOKENS; i++)
        if (info[i].bison_id == bison_id) return info[i].display_id;
    return -1;
}
