defmodule Predicated.Predicate do
  @moduledoc """
  Represents a predicate used for testing conditions against data.

  A predicate can contain either:
  - A single condition to evaluate
  - A group of nested predicates (for grouped expressions)
  
  Each predicate has an optional logical operator that determines how it
  combines with the next predicate in a list.

  ## Structure

  - `:condition` - A %Condition{} struct defining what to test
  - `:logical_operator` - Either :and or :or (applies to the NEXT predicate)
  - `:predicates` - List of nested predicates for grouped expressions

  ## Examples

      # Simple predicate
      %Predicate{
        condition: %Condition{
          identifier: "status",
          comparison_operator: "==",
          expression: "active"
        },
        logical_operator: :and
      }

      # Grouped predicates: (role == 'admin' OR role == 'moderator')
      %Predicate{
        predicates: [
          %Predicate{
            condition: %Condition{
              identifier: "role",
              comparison_operator: "==",
              expression: "admin"
            },
            logical_operator: :or
          },
          %Predicate{
            condition: %Condition{
              identifier: "role",
              comparison_operator: "==",
              expression: "moderator"
            }
          }
        ],
        logical_operator: :and
      }
  """
  
  defstruct condition: nil, logical_operator: nil, predicates: []

  @doc """
  Converts a predicate struct to its query string representation.

  Handles both simple predicates with conditions and grouped predicates
  with nested predicates. Grouped predicates are wrapped in parentheses.

  ## Parameters
    - `predicate` - A %Predicate{} struct

  ## Returns
    String representation of the predicate

  ## Examples

      iex> predicate = %Predicated.Predicate{
      ...>   condition: %Predicated.Condition{
      ...>     identifier: "age",
      ...>     comparison_operator: ">",
      ...>     expression: 21
      ...>   },
      ...>   logical_operator: :and
      ...> }
      iex> Predicated.Predicate.to_query(predicate)
      "age > 21 AND"
  """
  def to_query(%{predicates: predicates} = predicate) when length(predicates) > 0 do
    grouping =
      Enum.reduce(predicates, [], fn predicate, acc ->
        [to_query(predicate), acc]
      end)
      |> Enum.reverse()
      |> Enum.join(" ")

    ["(#{grouping})"]
    |> append_logical_operator(predicate.logical_operator)
    |> Enum.join(" ")
  end

  def to_query(%{condition: condition} = predicate) when not is_nil(condition) do
    parts =
      [
        condition.identifier,
        condition.comparison_operator,
        get_expression_value(condition.expression)
      ]
      |> append_logical_operator(predicate.logical_operator)

    Enum.join(parts, " ")
  end

  def to_query(_) do
    ""
  end

  def append_closing_paran(parts) do
    parts ++ [")"]
  end

  def append_logical_operator(parts, logical_operator) do
    if logical_operator do
      parts ++ [get_logical_operator(logical_operator)]
    else
      parts
    end
  end

  def get_logical_operator(:and), do: "AND"
  def get_logical_operator(:or), do: "OR"

  def get_expression_value(expression)
      when is_integer(expression) or is_float(expression) or is_boolean(expression) do
    expression
  end

  def get_expression_value(%DateTime{} = expression) do
    "'#{DateTime.to_iso8601(expression)}'::DATETIME"
  end

  def get_expression_value(%NaiveDateTime{} = expression) do
    "'#{DateTime.to_iso8601(expression)}'::DATETIME"
  end

  def get_expression_value(%Date{} = expression) do
    "'#{Date.to_iso8601(expression)}'::DATE"
  end

  def get_expression_value(expression) do
    "'#{expression}'"
  end
end
