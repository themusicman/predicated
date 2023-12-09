defmodule Predicated do
  require Logger
  alias Predicated.Query
  alias Predicated.Predicate

  def test(predicates, subject, acc \\ [])

  def test(query, subject, acc) when is_binary(query) do
    case Query.new(query) do
      {:ok, predicates} ->
        test(predicates, subject, acc)

      error ->
        IO.inspect(error: error)
        Logger.error("Could not parse the query")
    end
  end

  @doc """
  Tests a predicate
  """
  # This handles the case when there are group predicates.
  # ex. (b == 1 || b == 2) && c == 3
  def test([%{condition: nil, predicates: predicates} = predicate | rest], subject, acc)
      when length(predicates) > 0 do
    result = {predicate.logical_operator, test(predicates, subject, []), nil}
    test(rest, subject, [result | acc])
  end

  # This handles the case when there are non-grouped predicates.
  # ex. b == 1 || b == 2 && c == 3
  def test(
        [%{condition: condition, predicates: predicates} = predicate | rest],
        subject,
        acc
      )
      when not is_nil(condition) and length(predicates) == 0 do
    result = {predicate.logical_operator, eval(predicate.condition, subject), nil}
    test(rest, subject, [result | acc])
  end

  # This handles the case when we have tested all predicates and we need to compile the final result
  def test([], _subject, acc) do
    compile(Enum.reverse(acc), nil, true)
  end

  @doc """
  Compiles the final result of testing all the predicates
  """
  # first result to be compiled
  def compile([{_operator, bool, _} = result | rest], nil, acc) do
    compile(rest, result, acc && bool)
  end

  # if the previous result was an and
  def compile([{_operator, bool, _} = result | rest], {:and, _result, _}, acc) do
    compile(rest, result, acc && bool)
  end

  # if the previous result was an or
  def compile([{_operator, bool, _} = result | rest], {:or, _result, _}, acc) do
    compile(rest, result, acc || bool)
  end

  # no more to results to compile
  def compile([], _previous, acc) do
    acc
  end

  @doc """
  Evaluates a predicate's condition
  """
  def eval(%{identifier: identifier, comparison_operator: "==", expression: expression}, subject) do
    {_path, subject_value} = path_and_value(identifier, subject)

    cond do
      date?(expression) ->
        Date.compare(subject_value, expression) == :eq

      datetime?(expression) ->
        DateTime.compare(subject_value, expression) == :eq

      true ->
        subject_value == expression
    end
  end

  def eval(%{identifier: identifier, comparison_operator: "!=", expression: expression}, subject) do
    {_path, subject_value} = path_and_value(identifier, subject)

    cond do
      date?(expression) ->
        Date.compare(subject_value, expression) != :eq

      datetime?(expression) ->
        DateTime.compare(subject_value, expression) != :eq

      true ->
        subject_value != expression
    end
  end

  def eval(%{identifier: identifier, comparison_operator: ">", expression: expression}, subject) do
    {_path, subject_value} = path_and_value(identifier, subject)

    cond do
      date?(expression) ->
        Date.compare(subject_value, expression) == :gt

      datetime?(expression) ->
        DateTime.compare(subject_value, expression) == :gt

      true ->
        subject_value > expression
    end
  end

  def eval(%{identifier: identifier, comparison_operator: ">=", expression: expression}, subject) do
    {_path, subject_value} = path_and_value(identifier, subject)

    cond do
      date?(expression) ->
        Date.compare(subject_value, expression) in [:eq, :gt]

      datetime?(expression) ->
        DateTime.compare(subject_value, expression) in [:eq, :gt]

      true ->
        subject_value >= expression
    end
  end

  def eval(%{identifier: identifier, comparison_operator: "<", expression: expression}, subject) do
    {_path, subject_value} = path_and_value(identifier, subject)

    cond do
      date?(expression) ->
        Date.compare(subject_value, expression) == :lt

      datetime?(expression) ->
        DateTime.compare(subject_value, expression) == :lt

      true ->
        subject_value < expression
    end
  end

  def eval(%{identifier: identifier, comparison_operator: "<=", expression: expression}, subject) do
    {_path, subject_value} = path_and_value(identifier, subject)

    cond do
      date?(expression) ->
        Date.compare(subject_value, expression) in [:eq, :lt]

      datetime?(expression) ->
        DateTime.compare(subject_value, expression) in [:eq, :lt]

      true ->
        subject_value <= expression
    end
  end

  def eval(
        %{identifier: identifier, comparison_operator: "contains", expression: expression},
        subject
      ) do
    {_path, subject_value} = path_and_value(identifier, subject)
    expression in subject_value
  end

  def eval(
        %{identifier: identifier, comparison_operator: "in", expression: expression},
        subject
      ) do
    {_path, subject_value} = path_and_value(identifier, subject)
    subject_value in expression
  end

  # TODO add other operators like like, contains, in, starts_with etc

  # fallback case if no other conditions match 
  def eval(_, _) do
    nil
  end

  @doc """
  Constructs the path used to query into the subject and extracts the expression from the subject based on that path.

      iex> Predicated.path_and_value("person.first_name", %{person: %{first_name: "Bob"}})
      {[:person, :first_name], "Bob"}

      iex> Predicated.path_and_value("first_name", %{first_name: "Bob"})
      {[:first_name], "Bob"}
    
  """
  def path_and_value(identifier, subject) do
    path = String.split(identifier, ".") |> Enum.map(&String.to_atom/1)
    {path, get_in(subject, path)}
  end

  def date?(%Date{} = _date), do: true
  def date?(_), do: false

  def datetime?(%DateTime{} = _datetime), do: true
  def datetime?(%NaiveDateTime{} = _datetime), do: true
  def datetime?(_), do: false

  def to_query(predicates) do
    Enum.reduce(predicates, [], fn predicate, acc ->
      [Predicate.to_query(predicate), acc]
    end)
    |> Enum.reverse()
    |> Enum.join(" ")
  end
end
