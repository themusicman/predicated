defmodule Predicated.Predicate do
  # patient_id == 1 AND (provider_id == 2 OR provider_id == 3) 
  defstruct condition: nil, logical_operator: nil, predicates: []

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
