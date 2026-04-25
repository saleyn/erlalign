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
  name = <<"Alice">>,
  age =  30,
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
X              = 1,
Foo            = <<"bar">>,
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
-spec user(id()) -> {ok, user()} | {error, atom()}.
user(UserID) -> ...

% after (OTP-27 format)
-doc """
Returns the user record with the given ID.
""".
-spec user(id()) -> {ok, user()} | {error, atom()}.
user(UserID) -> ...
```

## Installation

### Requirements

- Erlang/OTP 24 or later
- rebar3 3.14+

### As a rebar3 plugin

Add to your `rebar.config`:

```erlang
{plugins, [
  {erlalign, {git, "https://github.com/saleyn/erlalign.git", {branch, "main"}}}
]}.
```

## Usage

### Formatting with rebar3

```bash
# Format all Erlang files in src/
rebar3 erlalign

# Format specific directory
rebar3 erlalign src/

# Use custom line length
rebar3 erlalign --line-length 120

# Check mode (fail if formatting needed)
rebar3 erlalign --check src/

# Dry run (preview changes)
rebar3 erlalign --dry-run src/mymodule.erl
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
rebar3 erlalign_docs

# Custom line length for wrapped docs
rebar3 erlalign_docs --line-length 100

# Keep separator lines (don't remove %%----)
rebar3 erlalign_docs --keep-separators

# Check mode
rebar3 erlalign_docs --check src/

# Dry run
rebar3 erlalign_docs --dry-run src/
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

### Programmatic usage

Use the modules directly from Erlang code:

```erlang
% Format code
{ok, Code} = file:read_file("src/mymodule.erl"),
Formatted = erlalign:format(Code, [{line_length, 100}]),
ok = file:write_file("src/mymodule.erl", Formatted).

% Convert documentation
erlalign_docs:process_file("src/mymodule.erl", [
  {line_length, 100},
  {remove_doc_separators, true}
]).

% Or with output to different file
erlalign_docs:process_file("src/mymodule.erl", [
  {output, "src/mymodule_formatted.erl"},
  {line_length, 80}
]).
```

#### Module functions

**erlalign module:**
- `format(Code)` - Format code with default options
- `format(Code, Options)` - Format code with options
- `load_global_config()` - Load global configuration from ~/.config/erlalign/.formatter.exs

**erlalign_docs module:**
- `format_code(Code)` - Convert doc blocks in code
- `format_code(Code, Options)` - Convert with options
- `process_file(Path)` - Convert a file in-place
- `process_file(Path, Options)` - Convert with options

#### Configuration

Global configuration file: `~/.config/erlalign/.formatter.exs`

```erlang
[
  {line_length, 120}
].
```

## Building

```bash
rebar3 compile
```

## Testing

```bash
rebar3 eunit
```

## License

MIT License - see LICENSE file

## See Also

- **ExAlign** - Column-aligning formatter for Elixir code: https://github.com/saleyn/exalign
