defmodule Predicated.Query do
  alias Predicated.Query.Parser
  alias Predicated.Predicate
  alias Predicated.Condition

  def new(string) when is_binary(string) do
    case Parser.parse(string) do
      {:ok, results, "", _, _, _} ->
        results =
          results
          |> Enum.chunk_every(4)
          |> Enum.reduce([], fn result, acc ->
            # IO.inspect(result: result)

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
          end)
          |> Enum.reverse()

        {:ok, results}

      {:error, reason, _rest, _, _, _} ->
        {:error, reason}
    end
  end

  def get_logical_operator(result) do
    logical_operator = Keyword.get(result, :logical_operator, "")

    if logical_operator == "" do
      nil
    else
      String.to_existing_atom(logical_operator)
    end
  end
end
