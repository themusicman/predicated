defmodule Predicated.Query do
  alias Predicated.Query.Parser
  alias Predicated.Predicate
  alias Predicated.Condition

  def new(string) when is_binary(string) do
    case Parser.parse(string) do
      {:ok, results, "", _, _, _} ->
        results =
          results
          |> chunk_results()
          |> compile_results([])
          |> Enum.reverse()

        {:ok, results}

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
  # Handle other types - dates, lists, etc
  def get_expression(result) do
    string = Keyword.get(result, :string_expression)
    number = Keyword.get(result, :number_expression)
    boolean = Keyword.get(result, :boolean_expression)

    {date, datetime} =
      cond do
        datetime?(string) ->
          {nil, String.split(string, "::") |> List.first()}

        date?(string) ->
          {String.split(string, "::") |> List.first(), nil}

        true ->
          {nil, nil}
      end

    case {string, number, boolean, datetime, date} do
      {_, nil, nil, _, date} when is_binary(date) -> cast_date(date)
      {_, nil, nil, datetime, _} when is_binary(datetime) -> cast_datetime(datetime)
      {nil, number, nil, nil, nil} -> cast_number(number)
      {string, nil, nil, nil, nil} -> string
      {nil, nil, boolean, nil, nil} -> cast_boolean(boolean)
    end
  end

  def date?(string) when is_binary(string), do: String.contains?(string, "::DATE")
  def date?(_), do: false

  def datetime?(string) when is_binary(string), do: String.contains?(string, "::DATETIME")
  def datetime?(_), do: false

  def cast_date(string) do
    case Date.from_iso8601(string) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  def cast_datetime(string) do
    case DateTime.from_iso8601(string) do
      {:ok, datetime, _} -> datetime
      _ -> nil
    end
  end

  def cast_boolean("TRUE"), do: true
  def cast_boolean("true"), do: true
  def cast_boolean("FALSE"), do: false
  def cast_boolean("false"), do: false

  def cast_number(string) do
    if String.contains?(string, ".") do
      case Float.parse(string) do
        {number, _remainder} -> number
        _ -> nil
      end
    else
      case Integer.parse(string) do
        {number, _remainder} -> number
        _ -> nil
      end
    end
  end

  def get_logical_operator([_, _, _, logical_operator]) when is_binary(logical_operator) do
    logical_operator
    |> String.downcase()
    |> String.to_existing_atom()
  end

  def get_logical_operator(_) do
    nil
  end
end
