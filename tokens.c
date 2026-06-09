/* ============================================================================
 * tokens.c  --  Token name / display-id lookup tables
 * ----------------------------------------------------------------------------
 * Implements the helpers declared in tokens.h.  The lookup is done by a
 * single static table, so adding a token in three places (here, the .y
 * %token line, and the .l rule) keeps everything consistent.
 *
 * DESIGN
 *   The table is small (about 60 entries) so a linear scan is fine; it runs
 *   only when we PRINT a token row, never during parsing.
 * ==========================================================================*/

#include "tokens.h"

typedef struct {
    int         bison_id;
    int         display_id;
    const char *name;
} TokenInfo;

/* One row per token category.  display_id starts at 1 and is assigned in a
 * stable order: keywords, then category names, then literals, then the
 * decorator marker, then operators, then delimiters, then NEWLINE.        */
static const TokenInfo info[] = {
    /* keywords - one entry each (the parser needs to distinguish them) */
    { KW_DEF,     1,  "KW_DEF"     },
    { KW_RETURN,  2,  "KW_RETURN"  },
    { KW_IF,      3,  "KW_IF"      },
    { KW_ELIF,    4,  "KW_ELIF"    },
    { KW_ELSE,    5,  "KW_ELSE"    },
    { KW_FOR,     6,  "KW_FOR"     },
    { KW_WHILE,   7,  "KW_WHILE"   },
    { KW_IN,      8,  "KW_IN"      },
    { KW_IMPORT,  9,  "KW_IMPORT"  },
    { KW_FROM,    10, "KW_FROM"    },
    { KW_AS,      11, "KW_AS"      },
    { KW_PASS,    12, "KW_PASS"    },
    { KW_AND,     13, "KW_AND"     },
    { KW_OR,      14, "KW_OR"      },
    { KW_NOT,     15, "KW_NOT"     },
    { KW_IS,      16, "KW_IS"      },
    { KW_NONE,    17, "KW_NONE"    },
    { KW_TRUE,    18, "KW_TRUE"    },
    { KW_FALSE,   19, "KW_FALSE"   },

    /* word-like categories (still classified at lex time) */
    { NAMESPACE,  20, "NAMESPACE"  },
    { TYPE,       21, "TYPE"       },
    { IDENTIFIER, 22, "IDENTIFIER" },

    /* literals */
    { INT_LIT,    23, "INT_LIT"    },
    { FLOAT_LIT,  24, "FLOAT_LIT"  },
    { STRING_LIT, 25, "STRING_LIT" },

    /* decorator marker */
    { AT,         26, "AT"         },

    /* operators */
    { ASSIGN,     27, "ASSIGN"     },
    { PLUS,       28, "PLUS"       },
    { MINUS,      29, "MINUS"      },
    { STAR,       30, "STAR"       },
    { SLASH,      31, "SLASH"      },
    { DSLASH,     32, "DSLASH"     },
    { PERCENT,    33, "PERCENT"    },
    { DSTAR,      34, "DSTAR"      },
    { EQ,         35, "EQ"         },
    { NEQ,        36, "NEQ"        },
    { LT,         37, "LT"         },
    { GT,         38, "GT"         },
    { LE,         39, "LE"         },
    { GE,         40, "GE"         },
    { PLUSEQ,     41, "PLUSEQ"     },
    { MINUSEQ,    42, "MINUSEQ"    },
    { STAREQ,     43, "STAREQ"     },
    { SLASHEQ,    44, "SLASHEQ"    },

    /* delimiters */
    { LPAREN,     45, "LPAREN"     },
    { RPAREN,     46, "RPAREN"     },
    { LBRACKET,   47, "LBRACKET"   },
    { RBRACKET,   48, "RBRACKET"   },
    { LBRACE,     49, "LBRACE"     },
    { RBRACE,     50, "RBRACE"     },
    { COMMA,      51, "COMMA"      },
    { COLON,      52, "COLON"      },
    { DOT,        53, "DOT"        },
    { SEMICOLON,  54, "SEMICOLON"  },
    { ARROW,      55, "ARROW"      },

    /* synchronisation */
    { NEWLINE,    56, "NEWLINE"    }
};

static const int N_TOKENS = sizeof(info) / sizeof(info[0]);

const char *token_name(int bison_id)
{
    for (int i = 0; i < N_TOKENS; i++)
        if (info[i].bison_id == bison_id)
            return info[i].name;
    return "??UNKNOWN??";
}

int token_display_id(int bison_id)
{
    for (int i = 0; i < N_TOKENS; i++)
        if (info[i].bison_id == bison_id)
            return info[i].display_id;
    return -1;
}
