# tests/syntax_error_missing_colon.py
# -----------------------------------------------------------------------------
# Purpose: trigger a SYNTAX error from the parser by writing a 'def' header
# without the closing ':'.  The lexical phase is happy (all tokens are valid
# Python tokens), so this file lets us demonstrate that the SECOND phase
# (syntax analysis) catches structural problems the first phase cannot.
# -----------------------------------------------------------------------------
import triton
import triton.language as tl


@triton.jit
def broken_kernel(x_ptr, n_elements)
    pid = tl.program_id(axis=0)
    x = tl.load(x_ptr + pid)
    return x
