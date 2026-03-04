.PHONY: test lint

test:
	shellspec

lint:
	shellcheck common.sh install.sh setup.sh spec/spec_helper.sh spec/merge_claude_settings_spec.sh
