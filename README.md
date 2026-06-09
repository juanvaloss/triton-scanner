# Triton Compiler — lex + yacc + semantic (TC3002B)

A three-phase compiler front-end for Triton GPU kernels, written in C with
GNU `lex` (Flex) and GNU `yacc` (Bison).

## Phases

1. **Lexical analysis** — `triton_scanner.l` recognises 56 token categories.
2. **Syntax analysis**  — `triton_parser.y` defines a flat LALR(1) grammar.
3. **Semantic analysis** — `semantic.c` performs orphan-decorator and
   use-before-declare checks.

## Build

```bash
sudo apt install -y flex bison gcc make libfl-dev
make
```

## Run

```bash
./triton_scanner [-l | -p | -s] [-v] <file.py>
```

- `-l` — lexical only (Step I parity).
- `-p` — lexical + syntax.
- `-s` — all three phases (default).
- `-v` — verbose token stream in `-p`/`-s` modes.

```bash
./triton_scanner tests/add_kernel.py            # full pipeline
./triton_scanner -l tests/add_kernel.py         # Phase I only
make test                                       # run every test (full mode)
```

## Layout

```
Makefile
triton_scanner.l       Lex specification (Phase I)
triton_parser.y        Bison specification (Phase II)
tokens.h / tokens.c    Token catalogue (display IDs and names)
symtab.h / symtab.c    Symbol table (declared / used tracking)
semantic.h / semantic.c   Phase III checks
main.c                 Driver and mode selection
tests/                 Seven test inputs (valid + lex / syntax / semantic errors)
sample_outputs/        Reference outputs for every test in both modes
```

See `01_Project_Explanation.md`, `02_Oral_Exam_Question_Bank_Answers.md`,
and `03_Testing_Manual.md` for the full documentation.
