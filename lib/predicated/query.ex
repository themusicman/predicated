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
    case Parser.parse(string) do
      {:ok, results, "", _, _, _} ->
        results =
          results
          |> chunk_results()
          |> compile_results([])
          |> Enum.reverse()

        {:ok, results}

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
          |> Enum.chunk_every(4)
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
              comparison_operator: Keyword.get(result, :comparison_operator),
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

    case {string, number, boolean, list} do
      {value, nil, nil, nil} -> value |> cast_date() |> cast_datetime() |> cast_string()
      {nil, value, nil, nil} -> cast_number(value)
      {nil, nil, value, nil} -> cast_boolean(value)
      {nil, nil, nil, value} -> cast_list(value)
    end
    |> Flamel.unwrap_ok_or_nil()
  end

  def list?(value) do
    String.match?(value, ~r/\[.*\]/)
  end

  def cast(value) do
    value
    |> cast_datetime()
    |> cast_date()
    |> cast_boolean()
    |> cast_number()
    |> cast_string()
    |> Flamel.unwrap_ok_or_nil()
  end

  def cast_list(value) when is_binary(value) do
    if list?(value) do
      list =
        value
        |> String.replace_prefix("[", "")
        |> String.replace_suffix("]", "")
        |> String.split(",", trim: true)
        |> Enum.map(fn i ->
          v = String.trim(i)

          # this is a bad idea
          case Regex.run(~r/'(.*)'(::(.*))?/, v) do
            [_ | rest] ->
              case rest do
                [date, cast_as, _] ->
                  v = "#{date}#{cast_as}"
                  cast(v)

                [v] ->
                  cast(v)
              end

            _ ->
              cast(v)
          end
        end)

      {:ok, list}
    else
      value
    end
  end

  def cast_list(value), do: value

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

  def cast_boolean("TRUE"), do: {:ok, true}
  def cast_boolean("true"), do: {:ok, true}
  def cast_boolean("FALSE"), do: {:ok, false}
  def cast_boolean("false"), do: {:ok, false}
  def cast_boolean(value), do: value

  def number?(value) when is_binary(value), do: !String.match?(value, ~r/[a-zA-Z]+/)
  def number?(value) when is_integer(value), do: true
  def number?(value) when is_float(value), do: true
  def number?(_), do: false

  def cast_number(value) when is_binary(value) do
    if number?(value) do
      if String.contains?(value, ".") do
        case Float.parse(value) do
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
  def cast_string(value), do: {:ok, value}

  def get_logical_operator([_, _, _, logical_operator]) when is_binary(logical_operator) do
    logical_operator
    |> String.downcase()
    |> String.to_existing_atom()
  end

  def get_logical_operator(_) do
    nil
  end
end
