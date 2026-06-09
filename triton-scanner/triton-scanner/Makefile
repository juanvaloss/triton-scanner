# ============================================================================
#  Makefile  --  Build the Triton lexical analyzer
# ----------------------------------------------------------------------------
#  Pipeline (exactly the one shown in the course material):
#     flex triton_scanner.l   ->  lex.yy.c        (the generated scanner)
#     gcc  *.c                ->  triton_scanner  (the executable)
#
#  Targets:
#     make            build the scanner
#     make test       build, then run it on every file in tests/
#     make clean      remove generated files
# ============================================================================

CC      = gcc
CFLAGS  = -Wall -Wextra -std=gnu11 # warnings on; gnu11 exposes POSIX fileno()
LEX     = flex
LDLIBS  = -lfl                     # Flex runtime library
TARGET  = triton_scanner

# C sources: our hand-written modules + the one Flex generates (lex.yy.c).
SRC     = lex.yy.c tokens.c symtab.c

# ---- default target -------------------------------------------------------
all: $(TARGET)

# Generate the scanner C code from the lex specification.
lex.yy.c: triton_scanner.l tokens.h symtab.h
	$(LEX) triton_scanner.l

# Compile and link everything into the final executable.
$(TARGET): $(SRC) tokens.h symtab.h
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC) $(LDLIBS)

# ---- convenience: run the scanner on the sample inputs --------------------
test: $(TARGET)
	@for f in tests/*.py ; do \
		echo "" ; \
		echo "########## $$f ##########" ; \
		./$(TARGET) $$f ; \
	done

# ---- housekeeping ---------------------------------------------------------
clean:
	rm -f lex.yy.c $(TARGET)

.PHONY: all test clean
