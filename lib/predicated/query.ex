defmodule Predicated.Query do
  @moduledoc """
  Handles parsing and compilation of query strings into predicate structures.

  This module provides the main interface for converting query strings into
  predicate structs that can be evaluated by the Predicated module. It handles
  type casting, operator precedence, and nested expressions.

  ## Query String Syntax

  ### Basic Syntax
  - Identifiers can contain letters, numbers, underscores, and dots
  - String values must be wrapped in single quotes: `'value'`
  - Numbers can be integers or floats: `42`, `3.14`, `-10`
  - Booleans: `true`, `TRUE`, `false`, `FALSE`
  - Lists: `[1, 2, 3]` or `['a', 'b', 'c']`

  ### Operators
  - Comparison: `==`, `!=`, `>`, `>=`, `<`, `<=`, `in`, `IN`, `contains`, `CONTAINS`
  - Logical: `AND`, `and`, `OR`, `or`
  - Grouping: `(` and `)` for precedence

  ### Type Casting
  - Dates: `'2023-01-01'::DATE`
  - DateTimes: `'2023-01-01T10:00:00Z'::DATETIME`

  ## Examples

      # Simple query
      Query.new("status == 'active'")

      # Compound query with AND/OR
      Query.new("status == 'active' AND (role == 'admin' OR role == 'moderator')")

      # Numeric comparisons
      Query.new("age >= 18 AND score > 75.5")

      # Date comparisons
      Query.new("created_at > '2023-01-01'::DATE")

      # List operations
      Query.new("user_id in [123, 456, 789]")
      Query.new("tags contains 'important'")

      # Nested field access
      Query.new("user.profile.verified == true")
  """
  
  alias Predicated.Query.Parser
  alias Predicated.Predicate
  alias Predicated.Condition

  @doc """
  Parses a query string into a list of predicate structs.

  Takes a query string and returns either a success tuple with the parsed
  predicates or an error tuple with the reason for failure.

  ## Parameters
    - `string` - The query string to parse

  ## Returns
    - `{:ok, predicates}` - Success with list of %Predicate{} structs
    - `{:error, reason}` - Error with the reason (e.g., {:error, unparsed: "remaining text"})

  ## Examples

      iex> {:ok, predicates} = Query.new("name == 'John' AND age > 21")
      iex> length(predicates)
      2

      iex> Query.new("invalid syntax")
      {:error, "expected string while processing..."}
  """
  def new(string) when is_binary(string) do
    # Trim whitespace and normalize multiline queries
    normalized = String.trim(string)

    case Parser.parse(normalized) do
      {:ok, results, "", _, _, _} ->
        results =
          results
          |> chunk_results()
          |> compile_results([])
          |> Enum.reverse()

        case validate_results(results) do
          :ok -> {:ok, results}
          {:error, reason} -> {:error, reason}
        end

      {:ok, _results, rest, _, _, _} ->
        {:error, unparsed: rest}

      {:error, reason, _rest, _, _, _} ->
        {:error, reason}
    end
  end

  def chunk_results(results) do
    chunk_fun = fn
      element, acc when is_binary(element) ->
        {:cont, Enum.reverse([element | acc]), []}

      element, acc ->
        {:cont, [element | acc]}
    end

    after_fun = fn
      [] -> {:cont, []}
      acc -> {:cont, Enum.reverse(acc), []}
    end

    Enum.chunk_while(results, [], chunk_fun, after_fun)
  end

  def compile_results([], acc) do
    acc
  end

  def compile_results([result | results], acc) do
    group = Keyword.get(result, :grouping, nil)

    acc =
      if group do
        result |> Keyword.to_list()

        {logical_operator, _rest} = result |> Keyword.to_list() |> List.pop_at(1)

        predicates =
          group
          |> chunk_results()
          |> compile_results([])
          |> Enum.reverse()

        [
          %Predicate{
            predicates: predicates,
            logical_operator: get_logical_operator([nil, nil, nil, logical_operator])
          }
          | acc
        ]
      else
        [
          %Predicate{
            condition: %Condition{
              identifier: Keyword.get(result, :identifier),
              comparison_operator: normalize_comparison_operator(Keyword.get(result, :comparison_operator)),
              expression: get_expression(result)
            },
            logical_operator: get_logical_operator(result)
          }
          | acc
        ]
      end

    compile_results(results, acc)
  end

  # TODO refactor
  def get_expression(result) do
    string = Keyword.get(result, :string_expression)
    number = Keyword.get(result, :number_expression)
    boolean = Keyword.get(result, :boolean_expression)
    list = Keyword.get(result, :list_expression)
    nil_expr = Keyword.get(result, :nil_expression)

    case {string, number, boolean, list, nil_expr} do
      {value, nil, nil, nil, nil} -> value |> cast_date() |> cast_datetime() |> cast_string()
      {nil, value, nil, nil, nil} -> cast_number(value)
      {nil, nil, value, nil, nil} -> cast_boolean(value)
      {nil, nil, nil, value, nil} -> cast_list(value)
      {nil, nil, nil, nil, value} -> cast_nil(value)
    end
    |> Flamel.unwrap_ok_or_nil()
  end

  def list?(value) do
    String.match?(value, ~r/\[.*\]/)
  end

  def cast(value) do
    value
    |> cast_nil()
    |> cast_datetime()
    |> cast_date()
    |> cast_boolean()
    |> cast_number()
    |> cast_string()
    |> Flamel.unwrap_ok_or_nil()
  end

  def cast_list(value) when is_binary(value) do
    if list?(value) do
      inner =
        value
        |> String.trim()
        |> String.trim_leading("[")
        |> String.trim_trailing("]")

      items = split_list_elements(inner)

      list =
        items
        |> Enum.map(fn raw ->
          v = String.trim(raw)

          # If quoted string with optional ::CAST, preserve inner content and cast
          case Regex.run(~r/^'(.*)'(?:::(\w+))?$/us, v) do
            [_, content, cast_as] when not is_nil(cast_as) ->
              # Only support explicit casts for quoted strings (e.g., '2023-01-01'::DATE)
              cast("#{content}::#{cast_as}")

            [_, content] ->
              # Preserve quoted strings as plain strings
              content

            _ ->
              # Unquoted values should be cast normally
              cast(v)
          end
        end)

      {:ok, list}
    else
      value
    end
  end

  def cast_list(value), do: value

  defp split_list_elements("") do
    []
  end

  defp split_list_elements(string) do
    # Split by commas that are not inside single-quoted strings
    graphemes = String.graphemes(string)

    {parts, current, _in_string} =
      Enum.reduce(graphemes, {[], [], false}, fn ch, {acc, cur, in_str} ->
        cond do
          ch == "'" ->
            {acc, [ch | cur], not in_str}

          ch == "," and not in_str ->
            {[Enum.reverse(cur) |> Enum.join("") | acc], [], in_str}

          true ->
            {acc, [ch | cur], in_str}
        end
      end)

    parts = [Enum.reverse(current) |> Enum.join("") | parts]
    parts |> Enum.reverse() |> Enum.map(& &1)
  end

  
  def date?(string) when is_binary(string), do: String.contains?(string, "::DATE")
  def date?(_), do: false

  def datetime?(string) when is_binary(string), do: String.contains?(string, "::DATETIME")
  def datetime?(_), do: false

  def cast_date(value) when is_binary(value) do
    if date?(value) do
      String.split(value, "::")
      |> List.first()
      |> Date.from_iso8601()
      |> case do
        {:ok, date} -> {:ok, date}
        _ -> value
      end
    else
      value
    end
  end

  def cast_date(value), do: value

  def cast_datetime(value) when is_binary(value) do
    if datetime?(value) do
      String.split(value, "::")
      |> List.first()
      |> DateTime.from_iso8601()
      |> case do
        {:ok, datetime, _} -> {:ok, datetime}
        _ -> value
      end
    else
      value
    end
  end

  def cast_datetime(value), do: value

  defp contains_cast_suffix?(value) when is_binary(value) do
    String.contains?(value, "::DATE") or String.contains?(value, "::DATETIME")
  end
  defp contains_cast_suffix?(_), do: false

  defp invalid_cast?(value) when is_list(value) do
    Enum.any?(value, &invalid_cast?/1)
  end

  defp invalid_cast?(value) do
    is_binary(value) and contains_cast_suffix?(value)
  end

  def validate_results(results) do
    cond do
      Enum.any?(results, &invalid_in_predicate?/1) -> {:error, :invalid_cast}
      Enum.any?(results, &unsupported_length_size?/1) -> {:error, :unsupported_length_size}
      true -> :ok
    end
  end

  defp unsupported_length_size?(%Predicate{condition: %Condition{identifier: id}}) when is_binary(id) do
    String.contains?(id, ".length") or String.contains?(id, ".size")
  end
  defp unsupported_length_size?(%Predicate{predicates: predicates}) when is_list(predicates) do
    Enum.any?(predicates, &unsupported_length_size?/1)
  end
  defp unsupported_length_size?(_), do: false

  defp invalid_in_predicate?(%Predicate{condition: %Condition{expression: expr}}), do: invalid_cast?(expr)
  defp invalid_in_predicate?(%Predicate{predicates: predicates}) when is_list(predicates) do
    Enum.any?(predicates, &invalid_in_predicate?/1)
  end
  defp invalid_in_predicate?(_), do: false

  def cast_boolean("TRUE"), do: {:ok, true}
  def cast_boolean("True"), do: {:ok, true}
  def cast_boolean("true"), do: {:ok, true}
  def cast_boolean("FALSE"), do: {:ok, false}
  def cast_boolean("False"), do: {:ok, false}
  def cast_boolean("false"), do: {:ok, false}
  def cast_boolean(value), do: value

  def cast_nil("nil"), do: {:ok, nil}
  def cast_nil("NIL"), do: {:ok, nil}
  def cast_nil("Nil"), do: {:ok, nil}
  def cast_nil("null"), do: {:ok, nil}
  def cast_nil("NULL"), do: {:ok, nil}
  def cast_nil("Null"), do: {:ok, nil}
  def cast_nil(value), do: value

  def number?(value) when is_binary(value) do
    # Allow scientific notation (e.g., 1.23e10, 1.23E-5)
    String.match?(value, ~r/^-?[0-9]*\.?[0-9]+([eE][+-]?[0-9]+)?$/)
  end
  def number?(value) when is_integer(value), do: true
  def number?(value) when is_float(value), do: true
  def number?(_), do: false

  def cast_number(value) when is_binary(value) do
    if number?(value) do
      if String.contains?(value, ".") or String.contains?(value, "e") or String.contains?(value, "E") do
        # Handle leading decimal like .5 by prepending "0"
        normalized_value = if String.starts_with?(value, "."), do: "0" <> value, else: value
        case Float.parse(normalized_value) do
          {number, _remainder} -> {:ok, number}
          _ -> value
        end
      else
        case Integer.parse(value) do
          {number, _remainder} -> {:ok, number}
          _ -> value
        end
      end
    else
      value
    end
  end

  def cast_number(value), do: value

  def cast_string({:ok, _} = value), do: value
  def cast_string(value) when is_binary(value) do
    # Unescape backslashes
    unescaped = String.replace(value, "\\\\", "\\")
    {:ok, unescaped}
  end
  def cast_string(value), do: {:ok, value}

  def get_logical_operator([_, _, _, logical_operator]) when is_binary(logical_operator) do
    logical_operator
    |> String.downcase()
    |> String.to_existing_atom()
  end

  def get_logical_operator(_) do
    nil
  end

  defp normalize_comparison_operator(op) when is_binary(op) do
    String.downcase(op)
  end

  defp normalize_comparison_operator(op), do: op
end
