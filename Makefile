.PHONY: lint
lint:
	hadolint --failure-threshold warning --config .hadolint.yaml Dockerfile
	shellcheck -x install-python.sh
	markdownlint-cli2 --config .markdownlint.json README.md AGENTS.md
	actionlint -shellcheck=shellcheck .github/workflows/*.yaml
