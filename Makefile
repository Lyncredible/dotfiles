.PHONY: test lint

test:
	shellspec

lint:
	shellcheck common.sh install.sh setup.sh spec/spec_helper.sh spec/common_spec.sh spec/zshrc_update_spec.sh
