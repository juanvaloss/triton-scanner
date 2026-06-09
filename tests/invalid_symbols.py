# This file intentionally contains symbols that are NOT part of the
# reduced Triton alphabet, so the scanner must report a lexical error
# for each one while still tokenizing everything around them correctly.
import triton
import triton.language as tl


@triton.jit
def bad_kernel(x_ptr, n):
    a = x_ptr $ 5      # '$' is not a Triton symbol  -> error
    b = a ? 3          # '?' is illegal              -> error
    c = a & b          # '&' is outside our alphabet -> error
    return c
