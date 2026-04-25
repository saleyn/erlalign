.PHONY: help compile doc test cover clean publish bump-version retire-version escript escriptize install regenerate

all: compile

compile: remove-crushdump
	rebar3 compile

escriptize: compile
	@echo "Building erlalign binary using rebar3..."
	@rebar3 escriptize
	@echo "✓ Binary created at _build/default/bin/erlalign"

install: escript
	@echo "Installing erlalign to /usr/local/bin/..."
	@sudo cp _build/prod/bin/erlalign /usr/local/bin/erlalign
	@sudo chmod +x /usr/local/bin/erlalign
	@echo "✓ erlalign installed at /usr/local/bin/erlalign"

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@echo "  compile              Compile the project"
	@echo "  escriptize           Build erlalign binary using rebar3"
	@echo "  install              Install erlalign to /usr/local/bin"
	@echo "  test                 Run the test suite"
	@echo "  regenerate           Regenerate expected fixtures from input fixtures"
	@echo "  cover                Run tests with coverage report"
	@echo "  clean                Remove build artefacts and dependencies"
	@echo "  doc                  Generate documentation"
	@echo "  publish              Publish to Hex (pass replace=1 to replace an existing version)"
	@echo "  bump-version         Bump patch version"
	@echo "  retire-version       Retire a version on Hex (pass version=X.Y.Z)"
	@echo "  help                 Show this help message"

test:
	rebar3 eunit

regenerate: compile
	@echo "Regenerating fixtures from input..."
	@erlc -pz _build/default/lib/erlalign/ebin -o _build/default/lib/erlalign/ebin priv/regen_fixtures.erl && \
	 erl -pz _build/default/lib/erlalign/ebin -noshell -run regen_fixtures main -s erlang halt

cover:
	rebar3 eunit --cover
	rebar3 covertool generate
	@echo "==> Coverage report generated in _build/test/covertool/"

clean:
	@rebar3 clean
	@rm -rf _build .cover
	@rm -f erl_crash.dump rebar3.crashdump *.beam

doc docs:
	@rebar3 ex_doc

publish:
	rebar3 hex publish$(if $(replace), --replace)

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

remove-crushdump:
	@rm -f erl_crash.dump

