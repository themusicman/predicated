defmodule Predicated do
  @moduledoc """
  Predicated is a library for building and evaluating predicates against in-memory data structures.

  It provides a flexible way to test complex conditions using either struct-based predicates
  or query strings with support for:
  
  - Logical operators (AND, OR)
  - Comparison operators (==, !=, >, >=, <, <=, contains, in)
  - Nested/grouped predicates
  - Type support for strings, numbers, booleans, dates, and datetimes
  - Dot notation for nested field access

  ## Examples

      # Using query strings
      Predicated.test("name == 'John' AND age > 21", %{name: "John", age: 25})
      #=> true

      # Using predicate structs
      predicates = [
        %Predicate{
          condition: %Condition{
            identifier: "status",
            comparison_operator: "==",
            expression: "active"
          },
          logical_operator: :and
        },
        %Predicate{
          condition: %Condition{
            identifier: "score",
            comparison_operator: ">",
            expression: 75
          }
        }
      ]
      
      Predicated.test(predicates, %{status: "active", score: 80})
      #=> true

      # Nested field access
      Predicated.test("user.profile.verified == true", %{
        user: %{profile: %{verified: true}}
      })
      #=> true
  """
  
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
        false
    end
  end

  @doc """
  Tests predicates against a subject data structure.

  Accepts either a query string or a list of predicate structs and evaluates
  them against the provided subject. Returns a boolean indicating whether
  all conditions are satisfied.

  ## Parameters
    - `predicates` - Either a query string or list of %Predicate{} structs
    - `subject` - The data structure to test against (map or struct)
    - `acc` - Accumulator for internal use (optional, defaults to [])

  ## Examples

      # Query string
      iex> Predicated.test("status == 'active'", %{status: "active"})
      true

      # Predicate structs  
      iex> predicates = [%Predicated.Predicate{condition: %Predicated.Condition{identifier: "age", comparison_operator: ">", expression: 18}}]
      iex> Predicated.test(predicates, %{age: 21})
      true

      # Grouped predicates
      iex> Predicated.test("(role == 'admin' OR role == 'moderator') AND active == true", %{role: "admin", active: true})
      true
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
  Compiles the final result of testing all predicates.

  Takes the accumulated test results and applies logical operators to determine
  the final boolean outcome. Processes results sequentially, respecting operator
  precedence (AND before OR).

  ## Parameters
    - `results` - List of tuples containing {operator, boolean_result, _}
    - `previous` - The previous result tuple for operator context
    - `acc` - The accumulated boolean result

  ## Returns
    Final boolean result after applying all logical operators
  """
  # first result to be compiled
  # New compilation that enforces AND precedence over OR.
  # Each tuple is {operator_to_next, bool, _} per current structure.
  def compile(results, _previous, _acc) do
    {groups, _current_and} =
      Enum.reduce(results, {[], true}, fn {op, bool, _}, {acc_groups, acc_and} ->
        new_and = acc_and && bool

        case op do
          :or -> {[new_and | acc_groups], true}
          nil -> {[new_and | acc_groups], true}
          :and -> {acc_groups, new_and}
          _ -> {acc_groups, new_and}
        end
      end)

    # OR across groups (any group true passes)
    Enum.any?(groups, & &1)
  end

  @doc """
  Evaluates a single condition against the subject.

  Supports multiple comparison operators and automatically handles type conversions
  for dates, datetimes, and other supported types.

  ## Supported Operators
    - `==` - Equality comparison
    - `!=` - Inequality comparison  
    - `>` - Greater than
    - `>=` - Greater than or equal
    - `<` - Less than
    - `<=` - Less than or equal
    - `contains` - Check if subject value contains expression (for lists)
    - `in` - Check if subject value is in expression list

  ## Type Support
    - Strings, numbers, booleans - Direct comparison
    - Dates - Uses Date.compare/2
    - DateTimes - Uses DateTime.compare/2
    - Lists - For contains/in operators

  ## Parameters
    - `condition` - Map with :identifier, :comparison_operator, :expression
    - `subject` - The data structure containing the value to test

  ## Returns
    Boolean result of the comparison, or nil if operator not supported
  """
  def eval(%{identifier: identifier, comparison_operator: "==", expression: expression}, subject) do
    {_path, subject_value} = path_and_value(identifier, subject)

    cond do
      date?(expression) ->
        if is_nil(subject_value), do: false, else: Date.compare(subject_value, expression) == :eq

      datetime?(expression) ->
        compare_datetimes(subject_value, expression) == :eq

      true ->
        subject_value == expression
    end
  end

  def eval(%{identifier: identifier, comparison_operator: "!=", expression: expression}, subject) do
    {_path, subject_value} = path_and_value(identifier, subject)

    cond do
      date?(expression) ->
        if is_nil(subject_value), do: true, else: Date.compare(subject_value, expression) != :eq

      datetime?(expression) ->
        compare_datetimes(subject_value, expression) != :eq

      true ->
        subject_value != expression
    end
  end

  def eval(%{identifier: identifier, comparison_operator: ">", expression: expression}, subject) do
    {_path, subject_value} = path_and_value(identifier, subject)

    cond do
      is_nil(subject_value) ->
        false

      date?(expression) ->
        Date.compare(subject_value, expression) == :gt

      datetime?(expression) ->
        compare_datetimes(subject_value, expression) == :gt

      is_number(subject_value) and is_number(expression) ->
        subject_value > expression

      true ->
        false
    end
  end

  def eval(%{identifier: identifier, comparison_operator: ">=", expression: expression}, subject) do
    {_path, subject_value} = path_and_value(identifier, subject)

    cond do
      is_nil(subject_value) ->
        false

      date?(expression) ->
        Date.compare(subject_value, expression) in [:eq, :gt]

      datetime?(expression) ->
        compare_datetimes(subject_value, expression) in [:eq, :gt]

      is_number(subject_value) and is_number(expression) ->
        subject_value >= expression

      true ->
        false
    end
  end

  def eval(%{identifier: identifier, comparison_operator: "<", expression: expression}, subject) do
    {_path, subject_value} = path_and_value(identifier, subject)

    cond do
      is_nil(subject_value) ->
        false

      date?(expression) ->
        Date.compare(subject_value, expression) == :lt

      datetime?(expression) ->
        compare_datetimes(subject_value, expression) == :lt

      is_number(subject_value) and is_number(expression) ->
        subject_value < expression

      true ->
        false
    end
  end

  def eval(%{identifier: identifier, comparison_operator: "<=", expression: expression}, subject) do
    {_path, subject_value} = path_and_value(identifier, subject)

    cond do
      is_nil(subject_value) ->
        false

      date?(expression) ->
        Date.compare(subject_value, expression) in [:eq, :lt]

      datetime?(expression) ->
        compare_datetimes(subject_value, expression) in [:eq, :lt]

      is_number(subject_value) and is_number(expression) ->
        subject_value <= expression

      true ->
        false
    end
  end

  def eval(
        %{identifier: identifier, comparison_operator: "contains", expression: expression},
        subject
      ) do
    {_path, subject_value} = path_and_value(identifier, subject)

    cond do
      is_nil(subject_value) -> false
      is_list(subject_value) -> Enum.member?(subject_value, expression)
      true -> false
    end
  end

  def eval(
        %{identifier: identifier, comparison_operator: "in", expression: expression},
        subject
      ) do
    {_path, subject_value} = path_and_value(identifier, subject)

    cond do
      is_nil(expression) -> false
      is_list(expression) -> Enum.member?(expression, subject_value)
      true -> false
    end
  end

  def eval(
        %{identifier: identifier, comparison_operator: "not contains", expression: expression},
        subject
      ) do
    {_path, subject_value} = path_and_value(identifier, subject)

    cond do
      is_nil(subject_value) -> false
      is_list(subject_value) -> not Enum.member?(subject_value, expression)
      true -> false
    end
  end

  # TODO: Add support for additional operators:
  # - `like` / `ilike` - Pattern matching with wildcards
  # - `starts_with` - String prefix matching
  # - `ends_with` - String suffix matching  
  # - `regex` / `=~` - Regular expression matching
  # - `is_nil` / `is_not_nil` - Null checks
  # - `between` - Range checks

  # fallback case if no other conditions match 
  def eval(_, _) do
    nil
  end

  @doc """
  Constructs the path used to query into the subject and extracts the value at that path.

  Supports dot notation for nested field access. The identifier is split by dots
  and converted to a list of atoms representing the path through the data structure.

  ## Parameters
    - `identifier` - String identifier, possibly with dot notation (e.g., "user.profile.name")
    - `subject` - The data structure to extract the value from

  ## Returns
    Tuple of {path_list, value} where:
    - `path_list` - List of atoms representing the path
    - `value` - The value found at that path, or nil if not found

  ## Examples

      iex> Predicated.path_and_value("person.first_name", %{person: %{first_name: "Bob"}})
      {[:person, :first_name], "Bob"}

      iex> Predicated.path_and_value("first_name", %{first_name: "Bob"})
      {[:first_name], "Bob"}

      iex> Predicated.path_and_value("user.settings.theme", %{user: %{settings: %{theme: "dark"}}})
      {[:user, :settings, :theme], "dark"}
  """
  def path_and_value(identifier, subject) do
    path = String.split(identifier, ".") |> Enum.map(&String.to_atom/1)

    value =
      Enum.reduce_while(path, subject, fn key, acc ->
        cond do
          is_map(acc) -> {:cont, Map.get(acc, key)}
          is_list(acc) and Keyword.keyword?(acc) -> {:cont, Keyword.get(acc, key)}
          true -> {:halt, nil}
        end
      end)

    {path, value}
  end

  def date?(%Date{} = _date), do: true
  def date?(_), do: false

  def datetime?(%DateTime{} = _datetime), do: true
  def datetime?(%NaiveDateTime{} = _datetime), do: true
  def datetime?(_), do: false

  defp compare_datetimes(subject_value, expression) do
    cond do
      is_nil(subject_value) -> :lt
      match?(%DateTime{}, subject_value) -> DateTime.compare(subject_value, expression)
      match?(%NaiveDateTime{}, subject_value) ->
        case DateTime.from_naive(subject_value, "Etc/UTC") do
          {:ok, dt} -> DateTime.compare(dt, expression)
          _ -> :lt
        end
      true -> :lt
    end
  end

  @doc """
  Converts a list of predicate structs back into a query string.

  Useful for debugging, logging, or serializing predicates. The generated
  query string can be parsed back into predicates using `Query.new/1`.

  ## Parameters
    - `predicates` - List of %Predicate{} structs

  ## Returns
    Query string representation of the predicates

  ## Examples

      iex> predicates = [
      ...>   %Predicated.Predicate{
      ...>     condition: %Predicated.Condition{
      ...>       identifier: "name",
      ...>       comparison_operator: "==",
      ...>       expression: "John"
      ...>     },
      ...>     logical_operator: :and
      ...>   },
      ...>   %Predicated.Predicate{
      ...>     condition: %Predicated.Condition{
      ...>       identifier: "age",
      ...>       comparison_operator: ">",
      ...>       expression: 21
      ...>     }
      ...>   }
      ...> ]
      iex> Predicated.to_query(predicates)
      "name == 'John' AND age > 21"
  """
  def to_query(predicates) do
    Enum.reduce(predicates, [], fn predicate, acc ->
      [Predicate.to_query(predicate), acc]
    end)
    |> Enum.reverse()
    |> Enum.join(" ")
  end
end
