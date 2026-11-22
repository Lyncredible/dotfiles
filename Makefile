.PHONY: test test-integration lint lint-shell lint-lines test-deps test-integration-deps check
.PHONY: test-powershell

# Every spec is checked, so a new one can't be missed.
SHELLCHECK_FILES = \
	common.sh \
	install.sh \
	setup.sh \
	$(wildcard .local/bin/*) \
	$(wildcard spec/*.sh)

SCRIPT_FILES := $(sort $(patsubst ./%,%,$(shell \
	{ find . -type f \( \
		-name "*.sh" -o \
		-name "*.zsh" -o \
		-name ".zshrc" -o \
		-name "main.zshrc" \
	\) ! -name ".p10k.zsh" -print; } \
	| git check-ignore --stdin --non-matching -v 2>/dev/null \
	| awk -F '\t' '$$1 ~ /^::/ { print $$2 }' \
)))

LINE_LENGTH_FILES = Makefile $(SCRIPT_FILES)
MAX_LINE_LENGTH ?= 100
TEST_ENV = LC_ALL=C TZ=UTC

test: test-deps
	@env $(TEST_ENV) shellspec $(FILES)

test-integration: test-integration-deps
	@if [ -n "$(FILES)" ]; then \
		for f in $(FILES); do env $(TEST_ENV) sh "$$f" || exit $$?; done; \
	else \
		env $(TEST_ENV) sh ./spec/integration_zsh_startup.sh && \
		env $(TEST_ENV) sh ./spec/integration_antigen_lock.sh; \
	fi

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
	shellcheck $(or $(FILES),$(SHELLCHECK_FILES))

lint-lines:
	@awk 'length($$0) > $(MAX_LINE_LENGTH) { \
		printf "%s:%d:%d\n", FILENAME, FNR, length($$0); bad=1 \
	} END { exit bad }' $(or $(FILES),$(LINE_LENGTH_FILES))

check: lint test test-integration

# Not part of check: needs pwsh and Pester 5, which the macOS/Linux hook may not have.
test-powershell:
	pwsh -NoProfile -Command 'Invoke-Pester -Path spec/powershell -CI'
