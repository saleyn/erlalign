.PHONY: help compile test cover clean publish bump-version retire-version

all: compile

compile: remove-crushdump
	rebar3 compile

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@echo "  compile              Compile the project"
	@echo "  test                 Run the test suite"
	@echo "  cover                Run tests with coverage report"
	@echo "  clean                Remove build artefacts and dependencies"
	@echo "  doc                  Generate documentation"
	@echo "  publish              Publish to Hex (pass replace=1 to replace an existing version)"
	@echo "  bump-version         Bump patch version"
	@echo "  retire-version       Retire a version on Hex (pass version=X.Y.Z)"
	@echo "  help                 Show this help message"

test:
	rebar3 eunit

cover:
	rebar3 eunit --cover
	rebar3 covertool generate
	@echo "==> Coverage report generated in _build/test/covertool/"

clean:
	@rebar3 clean
	@rm -rf _build .cover
	@rm -f erl_crash.dump *.beam

doc docs:
	@echo "ErlAlign documentation is generated via EDoc. No doc generation target yet."
	@echo "See README.md for usage information."

publish:
	rebar3 hex.publish$(if $(replace), --replace)

bump-version:
	@FILE=$$(ls -1 src/*.app.src | head -n1); \
	CURRENT=$$(grep -m1 '{vsn,' $$FILE | sed -E 's/.*"([0-9]+\.[0-9]+\.[0-9]+)".*/\1/'); \
	MAJOR=$$(echo $$CURRENT | cut -d. -f1); \
	MINOR=$$(echo $$CURRENT | cut -d. -f2); \
	PATCH=$$(echo $$CURRENT | cut -d. -f3); \
	NEW=$$(echo "$${MAJOR}.$${MINOR}.$$((PATCH + 1))" | tr -d '\n'); \
	echo "Bumping version from $${CURRENT} to $${NEW}"; \
	sed -i "s/{vsn, \"$${CURRENT}\"}/{vsn, \"$${NEW}\"}/" $$FILE; \
	echo "Changed: {vsn, \"$${CURRENT}\"} -> {vsn, \"$${NEW}\"}"; \
	echo ""; \
	read -p "Commit this change? [Y/n] " -n 1 -r || true; \
	echo ""; \
	if [[ $$REPLY =~ ^[Yy]$$ ]] || [[ -z $$REPLY ]]; then \
		git commit -am "Bump version to $${NEW}"; \
	else \
		echo "Aborted. Reverting rebar.config..."; \
		git checkout rebar.config; \
		exit 1; \
	fi

retire-version:
	@if [ -z "$(version)" ]; then \
		echo "Usage: make retire-version version=X.Y.Z"; \
		exit 1; \
	fi
	@echo "Retiring version $(version) of erlalign on Hex..."; \
	rebar3 hex.retire erlalign $(version) deprecated --message "Deprecated"
