defmodule Predicated.Query.Parser do
  import NimbleParsec

  lparen = ascii_char([?(]) |> label("(")
  rparen = ascii_char([?)]) |> label(")")

  whitespace = ascii_char([32, ?\t, ?\n]) |> times(min: 1) |> label("whitespace")

  indentifier =
    utf8_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?.], min: 1)
    |> reduce({Enum, :join, [""]})
    |> unwrap_and_tag(:identifier)

  string_expression =
    ignore(whitespace)
    |> ignore(string("'"))
    |> utf8_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?=, ?>, ?<, ?\s, ?-, ?:], min: 1)
    |> ignore(string("'"))
    |> reduce({Enum, :join, [""]})
    |> unwrap_and_tag(:string_expression)

  number_expression =
    ignore(whitespace)
    |> integer(min: 1)
    |> reduce({Enum, :join, [""]})
    |> unwrap_and_tag(:number_expression)

  expression =
    choice([string_expression, number_expression])

  comparison_operator =
    ignore(whitespace)
    |> choice([
      string("=="),
      string("!="),
      string(">"),
      string("<"),
      string("=>"),
      string("<="),
      string("IN"),
      string("in")
    ])
    |> reduce({Enum, :join, [""]})
    |> unwrap_and_tag(:comparison_operator)

  comparison =
    ignore(optional(whitespace))
    |> concat(indentifier)
    |> concat(comparison_operator)
    |> concat(expression)

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
