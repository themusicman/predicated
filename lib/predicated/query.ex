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
  # https://github.com/taxjar/date_time_parser
  def get_expression(result) do
    string = Keyword.get(result, :string_expression)
    number = Keyword.get(result, :number_expression)
    boolean = Keyword.get(result, :boolean_expression)

    case {string, number, boolean} do
      {nil, number, nil} -> cast_number(number)
      {string, nil, nil} -> string
      {nil, nil, boolean} -> cast_boolean(boolean)
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
