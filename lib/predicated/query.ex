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
              expression: Keyword.get(result, :expression)
            },
            logical_operator: get_logical_operator(result)
          }
          | acc
        ]
      end

    compile_results(results, acc)
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
