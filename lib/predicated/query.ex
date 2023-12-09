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

                [value] ->
                  cast(value)
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

  def cast_number(value) when is_binary(value) do
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
