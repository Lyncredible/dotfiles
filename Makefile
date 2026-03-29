.PHONY: test test-integration lint lint-shell lint-lines test-deps test-integration-deps

SHELLCHECK_FILES = \
	common.sh \
	install.sh \
	setup.sh \
	.local/bin/whereami \
	.local/bin/whereami-color \
	.local/bin/tmux-set-colors \
	spec/common_spec.sh \
	spec/install_spec.sh \
	spec/main_zshrc_spec.sh \
	spec/setup_spec.sh \
	spec/spec_helper.sh \
	spec/whereami_spec.sh \
	spec/whereami_color_spec.sh \
	spec/zshrc_update_spec.sh \
	spec/integration_zsh_startup.sh

SCRIPT_FILES := $(sort $(patsubst ./%,%,$(shell \
	find . -type f \( \
		-name "*.sh" -o \
		-name "*.zsh" -o \
		-name ".zshrc" -o \
		-name "main.zshrc" \
	\) ! -name ".p10k.zsh" -print; \
	find bin -type f -print 2>/dev/null \
)))

LINE_LENGTH_FILES = Makefile $(SCRIPT_FILES)
MAX_LINE_LENGTH ?= 100
TEST_ENV = LC_ALL=C TZ=UTC

test: test-deps
	@env $(TEST_ENV) shellspec

test-integration: test-integration-deps
	@env $(TEST_ENV) sh ./spec/integration_zsh_startup.sh

test-deps:
	@for cmd in shellspec zsh jq readlink; do \
		command -v $$cmd >/dev/null 2>&1 || { echo "Missing test dependency: $$cmd"; exit 1; }; \
	done

test-integration-deps:
	@for cmd in zsh; do \
		command -v $$cmd >/dev/null 2>&1 || { echo "Missing integration dependency: $$cmd"; exit 1; }; \
	done

lint: lint-shell lint-lines

lint-shell:
	shellcheck $(SHELLCHECK_FILES)

lint-lines:
	@awk 'length($$0) > $(MAX_LINE_LENGTH) { \
		printf "%s:%d:%d\n", FILENAME, FNR, length($$0); bad=1 \
	} END { exit bad }' $(LINE_LENGTH_FILES)
