defmodule Predicated.Query.Parser do
  @moduledoc """
  Parser for converting query strings into structured predicate data.

  Built using NimbleParsec, this module defines the grammar for parsing
  predicate query strings. It handles operator precedence (AND before OR),
  grouping with parentheses, and various expression types.

  ## Grammar Overview

  The parser implements a recursive descent grammar with the following precedence:
  1. Parentheses (highest)
  2. Comparison operators (==, !=, >, etc.)
  3. AND operator
  4. OR operator (lowest)

  ## Expression Types

  - **Identifiers**: Letters, numbers, underscores, dots (e.g., `user.name`, `count_1`)
  - **Strings**: Single-quoted with optional type casting (e.g., `'hello'`, `'2023-01-01'::DATE`)
  - **Numbers**: Integers and floats, including negative (e.g., `42`, `-3.14`)
  - **Booleans**: `true`, `TRUE`, `false`, `FALSE`
  - **Lists**: Comma-separated values in brackets (e.g., `[1, 2, 3]`, `['a', 'b']`)

  ## Parsing Process

  1. The input string is tokenized according to the grammar rules
  2. Expressions are grouped by operator precedence
  3. The result is a nested structure ready for compilation into predicates

  ## Examples

      # Simple comparison
      Parser.parse("age > 18")
      
      # Grouped expression with OR
      Parser.parse("(status == 'active' OR status == 'pending') AND verified == true")
      
      # Complex nested query
      Parser.parse("org_id == '123' AND (role == 'admin' OR (role == 'user' AND permissions contains 'read'))")

  Note: This module is primarily used internally by `Predicated.Query.new/1`.
  Direct usage is not recommended unless you need low-level parsing control.
  """
  
  import NimbleParsec

  lparen = ascii_char([?(]) |> label("(")
  rparen = ascii_char([?)]) |> label(")")

  whitespace = ascii_char([32, ?\t, ?\n]) |> times(min: 1) |> label("whitespace")

  indentifier =
    utf8_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?.], min: 1)
    |> reduce({Enum, :join, [""]})
    |> unwrap_and_tag(:identifier)

  boolean_expression =
    ignore(whitespace)
    |> choice([
      string("true"),
      string("TRUE"),
      string("false"),
      string("FALSE")
    ])
    |> reduce({Enum, :join, [""]})
    |> unwrap_and_tag(:boolean_expression)

  cast =
    empty()
    |> string("::")
    |> utf8_string([?a..?z, ?A..?Z], min: 1)

  string_expression =
    ignore(whitespace)
    |> ignore(string("'"))
    |> utf8_string([{:not, ?'}], min: 1)
    |> ignore(string("'"))
    |> optional(cast)
    |> reduce({Enum, :join, [""]})
    |> unwrap_and_tag(:string_expression)

  number_expression =
    ignore(whitespace)
    |> optional(string("-"))
    |> choice([utf8_string([?0..?9, ?.], min: 1), integer(min: 1)])
    |> reduce({Enum, :join, [""]})
    |> unwrap_and_tag(:number_expression)

  list_expression =
    ignore(whitespace)
    |> string("[")
    |> utf8_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?=, ?>, ?<, ?\s, ?-, ?:, ?., ?\,, ?'], min: 1)
    |> string("]")
    |> reduce({Enum, :join, [""]})
    |> unwrap_and_tag(:list_expression)

  expression =
    choice([list_expression, boolean_expression, string_expression, number_expression])

  comparison_operator =
    ignore(whitespace)
    |> choice([
      string("=="),
      string("!="),
      string(">="),
      string("<="),
      string(">"),
      string("<"),
      string("IN"),
      string("in"),
      string("CONTAINS"),
      string("contains")
    ])
    |> reduce({Enum, :join, [""]})
    |> unwrap_and_tag(:comparison_operator)

  comparison =
    ignore(optional(whitespace))
    |> concat(indentifier)
    |> concat(comparison_operator)
    |> concat(expression)
    |> ignore(optional(whitespace))

  grouping =
    empty()
    |> choice([
      ignore(lparen)
      |> concat(parsec(:expr))
      |> ignore(rparen)
      |> tag(:grouping),
      comparison
    ])

  defcombinatorp(
    :term,
    empty()
    |> choice([
      grouping
      |> ignore(optional(whitespace))
      |> choice([string("AND"), string("and")])
      |> ignore(optional(whitespace))
      |> concat(parsec(:term)),
      grouping
    ])
  )

  defcombinatorp(
    :expr,
    empty()
    |> choice([
      parsec(:term)
      |> ignore(optional(whitespace))
      |> choice([string("OR"), string("or")])
      |> ignore(optional(whitespace))
      |> concat(parsec(:expr)),
      parsec(:term)
    ])
  )

  defparsec(:parse, parsec(:expr), export_metadata: true)
end
