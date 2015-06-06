PROJECT = xref_dot
TEST_DIR = test

SHELL_DEPS = tddreloader
SHELL_OPTS = -s tddreloader
dep_tddreloader = git https://github.com/Version2beta/tddreloader.git master

include erlang.mk
