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
  @spec new(String.t()) :: {:ok, [Predicated.Predicate.t()]} | {:error, any()}
  def new(string) when is_binary(string) do
    # Trim whitespace and normalize multiline queries
    normalized = String.trim(string)

    case Parser.parse(normalized) do
      {:ok, results, "", _, _, _} ->
        results =
          results
          |> chunk_results()
          |> compile_results([])

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

  @doc """
  Groups parser results into chunks separated by logical operators.
  """
  @spec chunk_results(list()) :: list()
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

  @doc """
  Compiles chunked parser results into a list of Predicate structs.
  """
  @spec compile_results(list(), [Predicated.Predicate.t()]) :: [Predicated.Predicate.t()]
  def compile_results([], acc) do
    # Return reversed acc since we build it backwards for efficiency
    Enum.reverse(acc)
  end

  def compile_results([result | results], acc) do
    new_predicate = compile_single_result(result)
    compile_results(results, [new_predicate | acc])
  end

  defp compile_single_result(result) do
    case Keyword.get(result, :grouping) do
      nil -> compile_condition(result)
      group -> compile_group(result, group)
    end
  end

  defp compile_group(result, group) do
    {logical_operator, _rest} = result |> Keyword.to_list() |> List.pop_at(1)

    predicates =
      group
      |> chunk_results()
      |> compile_results([])

    %Predicate{
      predicates: predicates,
      logical_operator: get_logical_operator([nil, nil, nil, logical_operator])
    }
  end

  defp compile_condition(result) do
    %Predicate{
      condition: %Condition{
        identifier: Keyword.get(result, :identifier),
        comparison_operator:
          normalize_comparison_operator(Keyword.get(result, :comparison_operator)),
        expression: get_expression(result)
      },
      logical_operator: get_logical_operator(result)
    }
  end

  @doc """
  Extracts and casts the expression value from a parsed result keyword list.
  """
  @spec get_expression(keyword()) :: any()
  def get_expression(result) do
    expression_casters()
    |> Enum.find_value(fn {key, caster} ->
      case Keyword.get(result, key) do
        nil -> nil
        value -> caster.(value)
      end
    end)
    |> Flamel.unwrap_ok_or_nil()
  end

  defp expression_casters do
    [
      {:string_expression, &(&1 |> cast_date() |> cast_datetime() |> cast_string())},
      {:number_expression, &cast_number/1},
      {:boolean_expression, &cast_boolean/1},
      {:list_expression, &cast_list/1},
      {:nil_expression, &cast_nil/1}
    ]
  end

  @doc """
  Returns true if the string value represents a list (enclosed in brackets).
  """
  @spec list?(String.t()) :: boolean()
  def list?(value) do
    String.match?(value, ~r/\[.*\]/)
  end

  @doc """
  Casts a string value through all type casters in order: nil, datetime, date, boolean, number, string.
  """
  @spec cast(any()) :: any()
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

  @doc """
  Casts a bracket-enclosed string into a list of typed values.
  """
  @spec cast_list(any()) :: {:ok, list()} | any()
  def cast_list(value) when is_binary(value) do
    if list?(value) do
      inner =
        value
        |> String.trim()
        |> String.trim_leading("[")
        |> String.trim_trailing("]")

      list =
        inner
        |> split_list_elements()
        |> Enum.map(&cast_list_element/1)

      {:ok, list}
    else
      value
    end
  end

  def cast_list(value), do: value

  defp cast_list_element(raw) do
    v = String.trim(raw)

    case Regex.run(~r/^'(.*)'(?:::(\w+))?$/us, v) do
      [_, content, cast_as] when not is_nil(cast_as) ->
        cast("#{content}::#{cast_as}")

      [_, content] ->
        content

      _ ->
        cast(v)
    end
  end

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

  @doc """
  Returns true if the string contains a `::DATE` type cast suffix.
  """
  @spec date?(any()) :: boolean()
  def date?(string) when is_binary(string), do: String.contains?(string, "::DATE")
  def date?(_), do: false

  @doc """
  Returns true if the string contains a `::DATETIME` type cast suffix.
  """
  @spec datetime?(any()) :: boolean()
  def datetime?(string) when is_binary(string), do: String.contains?(string, "::DATETIME")
  def datetime?(_), do: false

  @doc """
  Casts a string with `::DATE` suffix to a `Date` struct.
  """
  @spec cast_date(any()) :: {:ok, Date.t()} | any()
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

  @doc """
  Casts a string with `::DATETIME` suffix to a `DateTime` struct.
  """
  @spec cast_datetime(any()) :: {:ok, DateTime.t()} | any()
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

  @doc """
  Validates parsed predicates for security issues like invalid casts and unsupported features.
  """
  @spec validate_results([Predicated.Predicate.t()]) :: :ok | {:error, atom()}
  def validate_results(results) do
    cond do
      Enum.any?(results, &invalid_in_predicate?/1) -> {:error, :invalid_cast}
      Enum.any?(results, &unsupported_length_size?/1) -> {:error, :unsupported_length_size}
      true -> :ok
    end
  end

  defp unsupported_length_size?(%Predicate{condition: %Condition{identifier: id}})
       when is_binary(id) do
    String.contains?(id, ".length") or String.contains?(id, ".size")
  end

  defp unsupported_length_size?(%Predicate{predicates: predicates}) when is_list(predicates) do
    Enum.any?(predicates, &unsupported_length_size?/1)
  end

  defp unsupported_length_size?(_), do: false

  defp invalid_in_predicate?(%Predicate{condition: %Condition{expression: expr}}),
    do: invalid_cast?(expr)

  defp invalid_in_predicate?(%Predicate{predicates: predicates}) when is_list(predicates) do
    Enum.any?(predicates, &invalid_in_predicate?/1)
  end

  defp invalid_in_predicate?(_), do: false

  @doc """
  Casts a boolean string ("true", "false", case-insensitive) to a boolean value.
  """
  @spec cast_boolean(any()) :: {:ok, boolean()} | any()
  def cast_boolean("TRUE"), do: {:ok, true}
  def cast_boolean("True"), do: {:ok, true}
  def cast_boolean("true"), do: {:ok, true}
  def cast_boolean("FALSE"), do: {:ok, false}
  def cast_boolean("False"), do: {:ok, false}
  def cast_boolean("false"), do: {:ok, false}
  def cast_boolean(value), do: value

  @doc """
  Casts nil/null string variants to nil.
  """
  @spec cast_nil(any()) :: {:ok, nil} | any()
  def cast_nil("nil"), do: {:ok, nil}
  def cast_nil("NIL"), do: {:ok, nil}
  def cast_nil("Nil"), do: {:ok, nil}
  def cast_nil("null"), do: {:ok, nil}
  def cast_nil("NULL"), do: {:ok, nil}
  def cast_nil("Null"), do: {:ok, nil}
  def cast_nil(value), do: value

  @doc """
  Returns true if the value is or represents a number (integer, float, or numeric string).
  """
  @spec number?(any()) :: boolean()
  def number?(value) when is_binary(value) do
    # Allow scientific notation (e.g., 1.23e10, 1.23E-5)
    String.match?(value, ~r/^-?[0-9]*\.?[0-9]+([eE][+-]?[0-9]+)?$/)
  end

  def number?(value) when is_integer(value), do: true
  def number?(value) when is_float(value), do: true
  def number?(_), do: false

  @doc """
  Casts a numeric string to an integer or float value.
  """
  @spec cast_number(any()) :: {:ok, number()} | any()
  def cast_number(value) when is_binary(value) do
    cond do
      not number?(value) -> value
      float_string?(value) -> parse_float(value)
      true -> parse_integer(value)
    end
  end

  def cast_number(value), do: value

  defp float_string?(value) do
    String.contains?(value, ".") or String.contains?(value, "e") or String.contains?(value, "E")
  end

  defp parse_float(value) do
    normalized = if String.starts_with?(value, "."), do: "0" <> value, else: value

    case Float.parse(normalized) do
      {number, _remainder} -> {:ok, number}
      _ -> value
    end
  end

  defp parse_integer(value) do
    case Integer.parse(value) do
      {number, _remainder} -> {:ok, number}
      _ -> value
    end
  end

  @doc """
  Wraps a string value in an ok tuple, unescaping backslashes.
  """
  @spec cast_string(any()) :: {:ok, any()}
  def cast_string({:ok, _} = value), do: value

  def cast_string(value) when is_binary(value) do
    # Unescape backslashes
    unescaped = String.replace(value, "\\\\", "\\")
    {:ok, unescaped}
  end

  def cast_string(value), do: {:ok, value}

  @doc """
  Extracts the logical operator from a parsed result list.
  """
  @spec get_logical_operator(list()) :: :and | :or | nil
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
