# Triton Compiler (simple version) — TC3002B

A minimal three-phase compiler front-end for Triton GPU kernels.

## Scope

This is the **simplest possible** implementation that:
- recognises the structural shape of a Triton kernel (imports, decorator, def, assignments, returns, calls);
- builds a symbol table;
- performs two semantic checks (orphan decorator, use-before-declare).

## Out of scope (documented future work)

- Indented nested bodies (no INDENT/DEDENT)
- Control flow (`if`/`for`/`while`/`else`)
- Augmented assignments (`+=`, etc.)
- Boolean operators (`and`/`or`/`not`)
- Multi-line expressions (paren-depth tracking)
- Triple-quoted strings spanning multiple lines
- Power (`**`), floor division (`//`), modulo (`%`) operators

## Build and run
sudo apt install -y flex bison gcc make libfl-dev
make
./triton_scanner tests/add_kernel.py            # full pipeline (default)
./triton_scanner -l tests/add_kernel.py         # lex only
./triton_scanner -p tests/add_kernel.py         # lex + parse


##Token catalogue

32 tokens total:
- 5 keywords (`def`, `return`, `import`, `from`, `as`)
- 3 word categories (`NAMESPACE`, `TYPE`, `IDENTIFIER`)
- 3 literal kinds (`INT_LIT`, `FLOAT_LIT`, `STRING_LIT`)
- 1 decorator marker (`AT`)
- 10 operators (`=`, `+`, `-`, `*`, `/`, `==`, `!=`, `<`, `>`, `<=`, `>=`)
- 8 delimiters (`(`, `)`, `[`, `]`, `,`, `:`, `.`, `->`)
- 1 line terminator (`NEWLINE`)

## Grammar properties

- LALR(1) bottom-up (GNU Bison default).
- **Zero shift/reduce conflicts.**
- Flat top-level statement list (no nesting via INDENT/DEDENT).
- Expressions use precedence directives instead of layered E/T/F.

## Files
Makefile              build pipeline
triton_scanner.l      lex spec (Phase I)
triton_parser.y       bison spec (Phase II)
tokens.h / tokens.c   token catalogue
symtab.h / symtab.c   symbol table
semantic.h / semantic.c   Phase III checks
main.c                driver
tests/                seven .py inputs (valid + lex/syntax/semantic errors)

##Note
This proyect does not generate code, it is only used to evaluate 
