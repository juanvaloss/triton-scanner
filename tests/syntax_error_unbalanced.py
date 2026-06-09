# tests/syntax_error_unbalanced.py
# -----------------------------------------------------------------------------
# Purpose: trigger a SYNTAX error from the parser by leaving an unclosed
# parenthesis in a function call.  The scanner accepts every character
# (parens are valid Python tokens), so the lexical phase reports zero
# errors, while the syntax phase reports a structural failure.
# -----------------------------------------------------------------------------
import triton
import triton.language as tl


@triton.jit
def unbalanced_kernel(x_ptr, n_elements):
    pid = tl.program_id(axis=0
    x = tl.load(x_ptr + pid)
    return x
