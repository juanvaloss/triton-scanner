# tests/semantic_undeclared_use.py
# -----------------------------------------------------------------------------
# Purpose: trigger the second SEMANTIC check - an identifier that is USED
# but was never DECLARED (no assignment target, no parameter, no import).
# Here, 'undeclared_var' appears on the right-hand side without ever being
# introduced.  This is again syntactically valid; only the symbol table
# inspection at the end of parsing can catch it.
# -----------------------------------------------------------------------------
import triton
import triton.language as tl


@triton.jit
def kernel_with_undeclared(x_ptr, n_elements):
    pid = tl.program_id(axis=0)
    x = undeclared_var + pid
    return x
