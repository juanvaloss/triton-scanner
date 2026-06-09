/* ============================================================================
 * tokens.h  --  Token catalogue for the Triton compiler (scanner + parser)
 * ----------------------------------------------------------------------------
 * PURPOSE
 *   Bridges Bison's auto-generated token IDs (declared in triton_parser.tab.h
 *   and numbered from 258 upward) with the small, contiguous "display IDs"
 *   (1..N) we print in the SEQUENCE OF TOKENS report.
 *
 *   The scanner returns Bison's IDs (because that is what the parser
 *   consumes), but the human-readable token report prefers small, stable
 *   integers - hence the mapping layer here.
 *
 * RELATION WITH OTHER FILES
 *   - triton_parser.y / .tab.h : declares the actual token IDs.
 *   - tokens.c                 : implements the lookup tables.
 *   - triton_scanner.l         : calls token_name() / token_display_id().
 * ==========================================================================*/

#ifndef TOKENS_H
#define TOKENS_H

#include "triton_parser.tab.h"   /* brings in KW_DEF, IDENTIFIER, ... as ints */

/* Printable category name for a Bison token id, e.g. "KW_DEF", "IDENTIFIER".
 * Returns "??UNKNOWN??" for an id not in the catalogue.                     */
const char *token_name(int bison_id);

/* Small contiguous display id (1..N) for printing in the report.  This is
 * the "Token ID" column required by the rubric.  Returns -1 if unknown.    */
int token_display_id(int bison_id);

#endif /* TOKENS_H */
