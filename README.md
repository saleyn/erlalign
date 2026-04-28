# ErlAlign

[![build](https://github.com/saleyn/erlalign/actions/workflows/ci.yml/badge.svg)](https://github.com/saleyn/erlalign/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/erlalign.svg)](https://hex.pm/packages/erlalign)

A column-aligning code formatter for Erlang source code, inspired by Go's `gofmt`. Works as a post-processor on top of the `erlfmt` formatter.

## What it does

ErlAlign scans consecutive lines that share the same indentation and pattern type, then pads them so their operators and values line up vertically. It aligns:

- **Record field assignments** - Aligns `=` operators in record definitions
- **Variable assignments** - Aligns `=` in consecutive variable declarations  
- **Case/if arrows** - Aligns `->` operators in case and if expressions
- **Function guards** - Aligns guard clauses

## ⚠️ Important: Version Control Required

**ErlAlign modifies your source code directly.** While it is designed to be a safe formatting tool, we strongly recommend:

1. **Use version control** - Always commit your code before running ErlAlign. This allows you to easily review changes and revert if needed.
2. **Use `--dry-run` or `--check` first** - Review what changes will be made before applying them:
   ```bash
   rebar3 format --dry-run src/   # Preview changes
   rebar3 format --check src/     # Check without modifying
   ```
3. **Review changes** - Inspect diffs before committing formatting changes to your repository.

If something goes wrong or you're unhappy with the formatting, you can always revert to your last commit.

## Features

### Record field alignment

```erlang
% before (erlfmt output)
User = #user{
  name = <<"Alice">>,
  age = 30,
  occupation = <<"developer">>
}.

% after (with ErlAlign)
User = #user{
  name       = <<"Alice">>,
  age        = 30,
  occupation = <<"developer">>
}.
```

### Variable assignment alignment

```erlang
% before
X = 1,
Foo = <<"bar">>,
SomethingLong = 42.

% after
X             = 1,
Foo           = <<"bar">>,
SomethingLong = 42.
```

### Case arrow alignment

```erlang
% before
case Result of
  {ok, Value} -> Value;
  {error, _} = Err -> Err
end.

% after
case Result of
  {ok, Value}      -> Value;
  {error, _} = Err -> Err
end.
```

### Documentation conversion

ErlAlign also includes `erlalign_docs` module for converting EDoc `@doc` blocks to OTP-27 `-doc` attributes:

```erlang
% before (EDoc format)
%% @doc
%% Returns the user record with the given ID.
%% See also: `user/2'.
-spec user(id()) -> {ok, user()} | {error, atom()}.
user(UserID) -> ...

% after (OTP-27 format)
-doc """
Returns the user record with the given ID.
See also: `user/2`.
""".
-spec user(id()) -> {ok, user()} | {error, atom()}.
user(UserID) -> ...
```

## Installation

### Requirements

- Erlang/OTP 27 or later
- rebar3 3.14+

### As a rebar3 plugin

Add erlalign to your project's `rebar.config` to use it as a rebar3 plugin:

#### From Hex.pm (when available)

```erlang
{plugins, [erlalign]}.  %% Or version specific: {erlalign, "0.1.5"}]}.
```

#### To install the plugin globally for all projects

Put the `plugins` setting above in this file:

```bash
~/.config/rebar3/rebar.config
```

### Using with rebar3

After adding erlalign as a plugin, you can use it in your project:

#### Format your project

```bash
# Format all Erlang files in src/ and app/*/src/ (if found)
rebar3 format

# Format specific directory
rebar3 format src/

# Format specific file or files
rebar3 format src/mymodule.erl src/another.erl

# Format apps and lib directories
rebar3 format apps/ lib/
```

#### Check formatting without modifying files

```bash
# Check if files need formatting
rebar3 format --check src/

# Useful in CI/CD to fail if files aren't formatted
rebar3 format --check
```

#### Preview changes

```bash
# See what would change without writing files
rebar3 format --dry-run src/

# Also good for code review
rebar3 format --dry-run apps/myapp/src/
```

#### Advanced options

```bash
# Custom line length
rebar3 format --line-length 120 src/

# Suppress output
rebar3 format --silent src/

# Write to a different output file (single file only)
rebar3 format --output /tmp/formatted.erl src/mymodule.erl

# Combine options
rebar3 format --line-length 100 --check src/
```

**Note:** The `--output` or `-o` option can only be used when formatting a single file. Use it to save the formatted output to a different location while leaving the original file unchanged.

#### Converting documentation

erlalign also includes a documentation converter for converting EDoc `@doc` blocks to OTP-27 `-doc` attributes:

```bash
# Convert documentation in all files
rebar3 edoc-to-doc

# Check documentation conversion without modifying
rebar3 edoc-to-doc --check

# Preview documentation changes
rebar3 edoc-to-doc --dry-run

# Keep separator lines
rebar3 edoc-to-doc --keep-separators

# Custom line length for wrapped docs
rebar3 edoc-to-doc --line-length 100
```

### Integration tips

#### Git hooks (pre-commit)

Add to your `.git/hooks/pre-commit`:

```bash
#!/bin/bash
set -e

# Check formatting before commit
rebar3 format --check
```

Make it executable:
```bash
chmod +x .git/hooks/pre-commit
```

#### GitHub Actions CI

Add to your `.github/workflows/ci.yml`:

```yaml
- name: Check formatting
  run: rebar3 format --check
```

#### Gitlab CI

Add to your `.gitlab-ci.yml`:

```yaml
format_check:
  script:
    - rebar3 format --check
```

#### Combine with erlfmt

For maximum code cleanliness, combine erlalign with erlfmt:

```bash
# First format with erlfmt (basic formatting)
rebar3 fmt

# Then align with erlalign (column alignment)
rebar3 format
```

#### Creating a Makefile target

Add to your `Makefile`:

```makefile
.PHONY: format fmt check-fmt

fmt: format

format:
	rebar3 format

check-fmt:
	rebar3 format --check
```

Then use:
```bash
make format          # Format code
make check-fmt       # Check formatting
```

#### Configuration per project

Create a global config file at `~/.config/erlalign/.formatter.config`:

```erlang
[
  {line_length, 100},
  {trim_eol_ws, true},
  {eol_at_eof,  off}
].
```

This configuration will be used automatically by all projects using erlalign as a plugin or binary.

## Usage

### Formatting with rebar3

```bash
# Format all Erlang files in src/
rebar3 format

# Format specific directory
rebar3 format src/

# Use custom line length
rebar3 format --line-length 120

# Check mode (fail if formatting needed)
rebar3 format --check src/

# Dry run (preview changes)
rebar3 format --dry-run src/mymodule.erl
```

#### Options

| Flag | Default | Description |
|---|---|---|
| `--line-length N` | `98` | Maximum line length for alignment decisions |
| `--check` | off | Exit with error if any file would be changed |
| `--dry-run` | off | Print what would be changed without modifying files |
| `-s, --silent` | off | Suppress output |
| `-h, --help` | | Show help message |

### Converting documentation with rebar3

```bash
# Convert all EDoc @doc blocks to -doc attributes
rebar3 edoc-to-doc

# Custom line length for wrapped docs
rebar3 edoc-to-doc --line-length 100

# Keep separator lines (don't remove %%----)
rebar3 edoc-to-doc --keep-separators

# Check mode
rebar3 edoc-to-doc --check src/

# Dry run
rebar3 edoc-to-doc --dry-run src/
```

#### Options

| Flag | Default | Description |
|---|---|---|
| `--line-length N` | `80` | Line wrap width for formatted docs |
| `--keep-separators` | off | Preserve `%%----` separator lines (removed by default) |
| `--check` | off | Check mode - fail if files would change |
| `--dry-run` | off | Preview changes without writing |
| `-s, --silent` | off | Suppress output |
| `-h, --help` | | Show help message |

### Command-line binary

Build the standalone erlalign binary:

```bash
# Build binary with make
make escriptize

# Or with rebar3
rebar3 escriptize
```

The binary will be located at `_build/default/bin/erlalign`.

#### Using the binary

Format Erlang files directly from the command line:

```bash
# Format a single file (modifies in place)
erlalign src/mymodule.erl

# Format multiple files
erlalign src/ lib/ test/

# Check formatting without modifying
erlalign --check src/

# Dry run (preview changes)
erlalign --dry-run src/mymodule.erl

# Trim trailing whitespace from end of lines (default)
erlalign --trim-eol-ws src/

# Disable trailing whitespace trimming
erlalign --no-trim-eol-ws src/

# Set line length
erlalign --line-length 120 src/

# Handle end-of-file newlines
erlalign --eol-at-eof add src/      # Add newline if missing
erlalign --eol-at-eof remove src/   # Remove trailing newline

# Convert @doc to -doc attributes (OTP 27+)
erlalign --doc src/

# Keep separator lines in documentation
erlalign --keep-separators src/

# Remove separators adjacent to -doc/@doc attributes
erlalign --remove-doc-separators src/

# Suppress output
erlalign --silent src/

# Show help
erlalign --help
```

#### Binary options

| Flag | Default | Description |
|---|---|---|
| `--line-length N` | `98` | Maximum line length for alignment decisions |
| `--trim-eol-ws` | on | Trim trailing whitespace from end of lines |
| `--no-trim-eol-ws` | off | Keep trailing whitespace |
| `--eol-at-eof VALUE` | off | Handle EOF newlines: `add`, `remove`, or `off` |
| `--keep-separators` | off | Preserve `%%----` separator lines in docs |
| `--remove-doc-separators` | off | Remove separators adjacent to -doc/@doc attributes |
| `--doc` | off | Convert @doc to -doc attributes (OTP 27+) |
| `--check` | off | Check mode - exit with error if unchanged needed |
| `--dry-run` | off | Preview changes without writing files |
| `-s, --silent` | off | Suppress output messages |
| `-h, --help` | | Show help message |

#### Global configuration

The binary supports global configuration via `~/.config/erlalign/.formatter.config`:

```erlang
[
  {line_length, 120},
  {trim_eol_ws, true},
  {eol_at_eof, off}
].
```

These default values can be overridden with command-line flags.

### Programmatic usage

Use the modules directly from Erlang code:

```erlang
% Format code
{ok, Code} = file:read_file("src/mymodule.erl"),
Formatted = erlalign:format(Code, [{line_length, 100}]),
ok = file:write_file("src/mymodule.erl", Formatted).

% Convert documentation and remove doc separators
erlalign_docs:process_file("src/mymodule.erl", [
  {line_length, 100},
  {remove_doc_separators, true}
]).

% Or with output to different file
erlalign_docs:process_file("src/mymodule.erl", [
  {output, "src/mymodule_formatted.erl"},
  {line_length, 80},
  {remove_doc_separators, true}
]).
```

#### Module functions

**erlalign module:**
- `format(Code)` - Format code with default options
- `format(Code, Options)` - Format code with options
- `load_global_config()` - Load global configuration from ~/.config/erlalign/.formatter.config

**erlalign_docs module:**
- `format_code(Code)` - Convert doc blocks in code
- `format_code(Code, Options)` - Convert with options
- `process_file(Path)` - Convert a file in-place
- `process_file(Path, Options)` - Convert with options

#### Configuration

Global configuration file: `~/.config/erlalign/.formatter.config`

```erlang
[
  {line_length, 120},
  {trim_eol_ws, true},
  {remove_doc_separators, false}
].
```

Supported options:
- `line_length` - Maximum line length for formatting (default: 98 for code, 80 for docs)
- `trim_eol_ws` - Trim trailing whitespace (default: true)
- `eol_at_eof` - Handle EOF newlines: `add`, `remove`, or `off` (default: off)
- `keep_separators` - Preserve separator lines (default: false)
- `remove_doc_separators` - Remove separators adjacent to -doc/@doc attributes (default: false)
- `doc` - Convert @doc to -doc attributes in erlalign_docs module (default: false, requires OTP 27+)

## Building

```bash
make
```

## Testing

```bash
make test
```

## License

MIT License - see LICENSE file

## See Also

- **ExAlign** - Column-aligning formatter for Elixir code: https://github.com/saleyn/exalign
