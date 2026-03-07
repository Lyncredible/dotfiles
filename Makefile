.PHONY: test lint lint-shell lint-lines

SHELLCHECK_FILES = \
	common.sh \
	install.sh \
	setup.sh \
	spec/common_spec.sh \
	spec/install_spec.sh \
	spec/main_zshrc_spec.sh \
	spec/setup_spec.sh \
	spec/spec_helper.sh \
	spec/zshrc_update_spec.sh

SCRIPT_FILES := $(shell \
	{ \
		find . -type f \( \
			-name '*.sh' -o \
			-name '*.zsh' -o \
			-name '.zshrc' -o \
			-name 'main.zshrc' \
		\) ! -name '.p10k.zsh' -print; \
		find bin -type f -print 2>/dev/null; \
	} \
	| sed 's#^\./##' \
	| sort -u \
)

LINE_LENGTH_FILES = Makefile $(SCRIPT_FILES)
MAX_LINE_LENGTH ?= 100

test:
	shellspec

lint: lint-shell lint-lines

lint-shell:
	shellcheck $(SHELLCHECK_FILES)

lint-lines:
	@awk 'length($$0) > $(MAX_LINE_LENGTH) { \
		printf "%s:%d:%d\n", FILENAME, FNR, length($$0); bad=1 \
	} END { exit bad }' $(LINE_LENGTH_FILES)
