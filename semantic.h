/* ============================================================================
 * semantic.h  --  Semantic-analysis interface
 * ----------------------------------------------------------------------------
 * PURPOSE
 *   Performs the small set of semantic checks Step III contributes on top
 *   of the lexical and syntactic phases.  Two checks are implemented:
 *
 *     (1) ORPHAN DECORATOR
 *         A '@something' decorator must be followed by a 'def' header on
 *         (essentially) the next statement.  We record every decorator and
 *         every def the parser sees; at end of parse we verify that each
 *         decorator was paired with a def that came after it.  This is the
 *         classic semantic check that "a decorator without a function is
 *         meaningless code" - syntactically valid, but semantically wrong.
 *
 *     (2) USE OF UNDECLARED IDENTIFIER
 *         By the end of parsing, every identifier in the symbol table
 *         should have been declared somewhere (assignment target, function
 *         parameter, imported name, def name).  Names that were USED but
 *         never DECLARED are reported.
 *
 *   These two checks together exercise the standard semantic-phase
 *   responsibilities discussed in the course notes (the symbol table is
 *   consulted, not the parse tree; this is sufficient for Step III).
 *
 * RELATION WITH OTHER FILES
 *   - triton_parser.y : calls sem_record_decorator and sem_record_def at
 *                       the appropriate productions.
 *   - symtab.c        : the table sem_check_undeclared iterates over.
 *   - main.c          : calls sem_check_all() once parsing has finished.
 * ==========================================================================*/

#ifndef SEMANTIC_H
#define SEMANTIC_H

/* Called by the parser when it reduces a decorator statement. */
void sem_record_decorator(int line);

/* Called by the parser when it reduces a func_header statement. */
void sem_record_def(int line);

/* Run all semantic checks now that parsing is complete.  Prints any
 * problems to stderr and returns the count of semantic errors found. */
long sem_check_all(void);

#endif /* SEMANTIC_H */
