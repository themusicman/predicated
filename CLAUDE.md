# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Predicated is an Elixir library for building and evaluating predicates against in-memory data structures. It provides a query language parsed via NimbleParsec that supports comparison operators, logical operators (AND/OR), grouped expressions with parentheses, dot-notation field access, and type casting.

## Common Commands

- `mix check` — runs the full quality pipeline: format check, compile (warnings-as-errors), credo, doctor, tests
- `mix test` — run all tests
- `mix test test/predicated/query/parser_test.exs` — run a single test file
- `mix test test/predicated_test.exs:42` — run a specific test by line number
- `mix format` — format code
- `mix credo list --format=oneline` — static analysis
- `mix doctor` — documentation coverage report

The `check` alias runs in the `:test` environment (configured via `cli/0`).

## Architecture

### Core Data Flow

```
Query string → Parser (NimbleParsec) → [%Predicate{}] → test/3 evaluates against data
```

1. **`Predicated.Query.new/1`** parses a query string into a list of `%Predicate{}` structs
2. **`Predicated.test/2,3`** evaluates predicates against a map/keyword list subject

### Module Responsibilities

- **`Predicated`** (`lib/predicated.ex`) — Public API. Contains `test/2,3` for evaluation, `eval/2` clauses for each comparison operator, and `path_and_value/2` for dot-notation field traversal.
- **`Predicated.Query`** (`lib/predicated/query.ex`) — Orchestrates parsing: tokenizes via Parser, chunks by logical operators, compiles into Predicate structs, validates for security issues.
- **`Predicated.Query.Parser`** (`lib/predicated/query/parser.ex`) — NimbleParsec grammar definition. Implements recursive descent with AND binding tighter than OR. `term` handles AND-connected conditions; `expr` handles OR-connected terms.
- **`Predicated.Predicate`** (`lib/predicated/predicate.ex`) — Struct with `condition`, `logical_operator` (:and/:or), and `predicates` (for grouped/nested expressions). The `logical_operator` applies to the **next** predicate in sequence.
- **`Predicated.Condition`** (`lib/predicated/condition.ex`) — Struct with `identifier`, `comparison_operator`, and `expression`.

### Key Design Decisions

- **Logical operator placement**: A predicate's `logical_operator` connects it to the *next* predicate, not the current one. This matches natural left-to-right query reading.
- **Grouped predicates**: When `condition: nil`, the predicate contains nested `predicates` list — enables recursive evaluation.
- **AND-before-OR precedence**: `compile/3` in `Predicated` groups AND-connected results first, then ORs across groups.
- **Atom exhaustion prevention**: `path_and_value/2` uses `String.to_existing_atom/1` and falls back to string keys. Never creates atoms from user input.

### Supported Query Syntax

Operators: `==`, `!=`, `>`, `>=`, `<`, `<=`, `contains`, `not contains`, `in`

Expressions: strings (`'value'`), numbers (int/float/scientific), booleans, nil/null, lists (`[1, 2, 3]`), type casts (`'2023-01-01'::DATE`, `'...'::DATETIME`)

Identifiers support dot notation: `user.profile.name`

## Dependencies

- **nimble_parsec** — parser combinator library used for grammar definition
- **flamel** — utility library (used for `unwrap_ok_or_nil/1` in type casting)
