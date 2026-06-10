/* ============================================================================
 * tokens.h  --  Token catalogue (simple version)
 * ----------------------------------------------------------------------------
 * Bridges Bison's auto-generated token ids (258+) with small display ids
 * (1..N) used in the printed token stream.
 * ==========================================================================*/

#ifndef TOKENS_H
#define TOKENS_H

#include "triton_parser.tab.h"

const char *token_name(int bison_id);
int         token_display_id(int bison_id);

#endif
