import triton
import triton.language as tl


@triton.jit
def softmax_kernel(out_ptr, in_ptr, row_stride, n_cols, BLOCK_SIZE: tl.constexpr):
    """Numerically stable softmax over one row of a 2D tensor."""
    row = tl.program_id(0)
    row_start = in_ptr + row * row_stride
    cols = tl.arange(0, BLOCK_SIZE)
    mask = cols < n_cols
    x = tl.load(row_start + cols, mask=mask, other=-1e30)
    x_max = tl.max(x, axis=0)
    z = x - x_max
    num = tl.exp(z)
    denom = tl.sum(num, axis=0)
    y = num / denom
    out_start = out_ptr + row * row_stride
    tl.store(out_start + cols, y, mask=mask)
