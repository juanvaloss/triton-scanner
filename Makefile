# ============================================================================
#  Makefile  --  Build the Triton compiler (lex + yacc + semantic)
# ----------------------------------------------------------------------------
#  Pipeline (the standard lex+yacc flow taught in class):
#     bison -d triton_parser.y    ->  triton_parser.tab.c + triton_parser.tab.h
#     lex  triton_scanner.l       ->  lex.yy.c
#     gcc  *.c                    ->  triton_scanner (the executable)
#
#  The -d flag on bison emits the header file with token #defines (KW_DEF,
#  IDENTIFIER, ...).  The lexer and the rest of the C code #include that
#  header to know each token's id.
#
#  Note on lex vs Flex: /usr/bin/lex is a symlink to /usr/bin/flex on Ubuntu
#  (and most Linux distros), so 'lex' and 'flex' invoke the same binary.
#  We use 'lex' here to match the rubric.
#
#  Targets:
#     make            build the compiler
#     make test       build, then run the test files (default mode = all)
#     make clean      remove generated files
# ============================================================================

CC      = gcc
CFLAGS  = -Wall -Wextra -std=gnu11
LEX     = lex
YACC    = bison
LDLIBS  = -lfl
TARGET  = triton_scanner

# Hand-written modules + the two generated C files.
SRC     = main.c tokens.c symtab.c semantic.c lex.yy.c triton_parser.tab.c

all: $(TARGET)

# Generate parser tables + header.  '-d' produces triton_parser.tab.h.
triton_parser.tab.c triton_parser.tab.h: triton_parser.y
	$(YACC) -d triton_parser.y

# Generate the scanner; depends on the bison header so token IDs are known.
lex.yy.c: triton_scanner.l triton_parser.tab.h tokens.h symtab.h
	$(LEX) triton_scanner.l

# Final link.
$(TARGET): $(SRC) tokens.h symtab.h semantic.h
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC) $(LDLIBS)

# Convenience: run the compiler on every sample input (default mode).
test: $(TARGET)
	@for f in tests/*.py ; do \
		echo "" ; \
		echo "########## $$f ##########" ; \
		./$(TARGET) $$f ; \
	done

# Convenience: lex-only run (mirrors Step I behaviour exactly).
test-lex: $(TARGET)
	@for f in tests/add_kernel.py tests/softmax_kernel.py tests/invalid_symbols.py ; do \
		echo "" ; \
		echo "########## $$f (-l) ##########" ; \
		./$(TARGET) -l $$f ; \
	done

clean:
	rm -f lex.yy.c triton_parser.tab.c triton_parser.tab.h $(TARGET)

.PHONY: all test test-lex clean
