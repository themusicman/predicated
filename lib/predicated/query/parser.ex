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

  # Identifier must be one or more dot-separated segments.
  # Each segment must start with a letter or underscore, followed by letters, digits, or underscores.
  identifier_segment =
    utf8_string([?a..?z, ?A..?Z, ?_], 1)
    |> optional(utf8_string([?a..?z, ?A..?Z, ?0..?9, ?_], min: 0))
    |> reduce({Enum, :join, [""]})

  identifier =
    identifier_segment
    |> repeat(ignore(string(".")) |> concat(identifier_segment))
    |> reduce({Enum, :join, ["."]})
    |> unwrap_and_tag(:identifier)

  boolean_expression =
    ignore(optional(whitespace))
    |> choice([
      string("true"),
      string("TRUE"),
      string("True"),
      string("false"),
      string("FALSE"),
      string("False")
    ])
    |> reduce({Enum, :join, [""]})
    |> unwrap_and_tag(:boolean_expression)

  nil_expression =
    ignore(optional(whitespace))
    |> choice([
      string("nil"),
      string("NIL"),
      string("Nil"),
      string("null"),
      string("NULL"),
      string("Null")
    ])
    |> reduce({Enum, :join, [""]})
    |> unwrap_and_tag(:nil_expression)

  cast =
    empty()
    |> string("::")
    |> utf8_string([?a..?z, ?A..?Z], min: 1)

  string_expression =
    ignore(optional(whitespace))
    |> ignore(string("'"))
    |> utf8_string([{:not, ?'}], min: 0)
    |> ignore(string("'"))
    |> optional(cast)
    |> reduce({Enum, :join, [""]})
    |> unwrap_and_tag(:string_expression)

  # Support integers, floats, and scientific notation (e.g., 1.23e10, .5, -1e-9)
  number_expression =
    ignore(optional(whitespace))
    |> optional(string("-"))
    |> utf8_string([?0..?9, ?., ?e, ?E, ?+, ?-], min: 1)
    |> reduce({Enum, :join, [""]})
    |> unwrap_and_tag(:number_expression)

  list_expression =
    ignore(optional(whitespace))
    |> string("[")
    |> utf8_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?=, ?>, ?<, ?\s, ?-, ?:, ?., ?\,, ?'], min: 0)
    |> string("]")
    |> reduce({Enum, :join, [""]})
    |> unwrap_and_tag(:list_expression)

  expression =
    choice([list_expression, boolean_expression, nil_expression, string_expression, number_expression])

  comparison_operator =
    ignore(optional(whitespace))
    |> choice([
      string("=="),
      string("!="),
      string(">="),
      string("<="),
      string(">"),
      string("<"),
      string("NOT CONTAINS"),
      string("not contains"),
      string("IN"),
      string("in"),
      string("In"),
      string("CONTAINS"),
      string("contains")
    ])
    |> reduce({Enum, :join, [""]})
    |> unwrap_and_tag(:comparison_operator)

  comparison =
    ignore(optional(whitespace))
    |> concat(identifier)
    |> concat(comparison_operator)
    |> concat(expression)
    |> ignore(optional(whitespace))

  grouping =
    empty()
    |> choice([
      ignore(lparen)
      |> ignore(optional(whitespace))
      |> concat(parsec(:expr))
      |> ignore(optional(whitespace))
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
      |> choice([string("AND"), string("and"), string("And")])
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
      |> choice([string("OR"), string("or"), string("Or")])
      |> ignore(optional(whitespace))
      |> concat(parsec(:expr)),
      parsec(:term)
    ])
  )

  defparsec(:parse, parsec(:expr), export_metadata: true)
end
