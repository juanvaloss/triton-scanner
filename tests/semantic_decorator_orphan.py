# tests/semantic_decorator_orphan.py
# -----------------------------------------------------------------------------
# Purpose: trigger a SEMANTIC error - a decorator that is NOT followed by a
# 'def' header.  This is syntactically valid Python tokens AND a valid
# parse, but semantically wrong: a decorator with no function to attach to
# has no meaning.  Only the third phase (semantic analysis) can catch this.
# -----------------------------------------------------------------------------
import triton
import triton.language as tl


@triton.jit
x = 0
