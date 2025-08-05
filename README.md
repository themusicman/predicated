# Predicated

[![Elixir CI](https://github.com/themusicman/predicated/actions/workflows/elixir.yml/badge.svg)](https://github.com/themusicman/predicated/actions/workflows/elixir.yml)

Predicated is a library that allows for building predicates to query an in-memory data structure in Elixir.

## Installation

If [available in Hex](https://hex.pm/packages/predicated), the package can be installed
by adding `predicated` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:predicated, "~> 1.1"}
  ]
end
```

## Examples

Using Structs.

```elixir
predicates = [
    %Predicate{
      condition: %Condition{
        identifier: "last_name",
        comparison_operator: "==",
        expression: "Armstrong"
      },
      logical_operator: :and
    },
    %Predicate{
      predicates: [
        %Predicate{
          condition: %Condition{
            identifier: "first_name",
            comparison_operator: "==",
            expression: "Joe"
          },
          logical_operator: :or
        },
        %Predicate{
          predicates: [
            %Predicate{
              condition: %Condition{
                identifier: "first_name",
                comparison_operator: "==",
                expression: "Jill"
              },
              logical_operator: :and
            },
            %Predicate{
              condition: %Condition{
                identifier: "first_name",
                comparison_operator: "==",
                expression: "Joe"
              }
            }
          ]
        }
      ],
      logical_operator: :and
    },
    %Predicate{
      condition: %Condition{
        identifier: "last_name",
        comparison_operator: "==",
        expression: "Beaver"
      }
    }
]

# true && (true || (false && true)) && false
assert Predicated.test(predicates, %{first_name: "Joe", last_name: "Armstrong"}) == false
```

The example above could also be written with just plain maps or embedded schema as long as the data shape is the same. 

For example

```elixir
%Predicate{
  condition: %Condition{
    identifier: "last_name",
    comparison_operator: "==",
    expression: "Beaver"
  }
}
```

converted to a map would be

```elixir
%{
  condition: %{
    identifier: "last_name",
    comparison_operator: "==",
    expression: "Beaver"
  }
}
```

Using a query string:

```elixir
assert Predicated.test("trace_id != 'test123' and profile_id == '123'", %{
  trace_id: "test123",
  profile_id: "123"
}) == false

```

Support for grouped and nested predicates:

```elixir
assert Predicated.test("organization_id == '123' AND (user_id == '123' OR user_id == '456' OR (user_type == 'admin' OR user_type == 'editor'))", %{
  organization_id: "123",
  user_id: "767",
  user_type: "admin"
}) == true

```

Support for boolean and integers:

```elixir
assert Predicated.test("verified == TRUE AND post.count > 100", %{
  verified: true,
  post: %{ count: 123 }
}) == true

```

Support for dates and datetimes:

```elixir
assert Predicated.test("dob >= '2020-01-01'::DATE", %{
  dob: ~D[2023-02-11]
}) == true
```

```elixir
assert Predicated.test("inserted_at >= '2020-01-01T01:50:07Z'::DATETIME", %{
  inserted_at: ~U[2020-01-01 10:00:00Z] 
}) == true
```

## Ecto Integration

Integrating with Ecto it a bit of a manual process at the moment. My hopes are to write some macros that make this less tedious. 

The first snippet here constructs a query and then applies the predicates to the query. See the next snippet for how to apply the predicates to the Ecto query.

```elixir
def list_events_for_topic(
        offset: offset,
        batch_size: batch_size,
        topic_name: topic_name,
        topic_identifier: topic_identifier,
        predicates: predicates
      ) do
  query =
    from_events_for_topic(topic_name: topic_name)
    |> where(as(:events).topic_name == ^topic_name)
    |> apply_ordering(predicates)
    |> where(not is_nil(as(:events).occurred_at))
    |> where_available()

  query =
    unless ER.empty?(topic_identifier) do
      where(query, as(:events).topic_identifier == ^topic_identifier)
    else
      query
    end

  query =
    if Flamel.present?(predicates) do
      conditions = apply_predicates(predicates, nil, nil)
      from query, where: ^conditions
    else
      query
    end

  ER.BatchedResults.new(query, %{"offset" => offset, "batch_size" => batch_size})
end
```

Below is a snippet from a [module](https://github.com/eventrelay/eventrelay/blob/main/lib/event_relay/events/predicates.ex) that takes in predicates and applies them to an Ecto query.

```elixir

 def apply_predicates([predicate | predicates], nil, nil) do
    # first iteration
    conditions = apply_predicate(predicate, dynamic(true), nil)
    apply_predicates(predicates, conditions, predicate)
  end

  def apply_predicates([predicate | predicates], conditions, previous_predicate) do
    conditions = apply_predicate(predicate, conditions, previous_predicate)
    apply_predicates(predicates, conditions, predicate)
  end

  def apply_predicates([], conditions, _previous_predicate) do
    conditions
  end

  def apply_predicate(%{predicates: predicates}, conditions, previous_predicate)
      when length(predicates) > 0 do
    nested_conditions = apply_predicates(predicates, dynamic(true), previous_predicate)

    case previous_predicate do
      nil ->
        dynamic([events: events], ^conditions and ^nested_conditions)

      %{logical_operator: :and} ->
        dynamic([events: events], ^conditions and ^nested_conditions)

      %{logical_operator: :or} ->
        dynamic([events: events], ^conditions or ^nested_conditions)
    end
  end

  def apply_predicate(
        %{
          condition: %{identifier: "data." <> path, comparison_operator: "==", expression: value}
        },
        conditions,
        previous_predicate
      ) do
    path = parse_path(path)

    case previous_predicate do
      nil ->
        dynamic([events: events], ^conditions and json_extract_path(events.data, ^path) == ^value)

      %{logical_operator: :and} ->
        dynamic([events: events], ^conditions and json_extract_path(events.data, ^path) == ^value)

      %{logical_operator: :or} ->
        dynamic([events: events], ^conditions or json_extract_path(events.data, ^path) == ^value)

      _ ->
        conditions
    end
  end

  def apply_predicate(
        %{
          condition: %{
            identifier: "context." <> path,
            comparison_operator: "==",
            expression: value
          }
        },
        conditions,
        previous_predicate
      ) do
    path = parse_path(path)

    case previous_predicate do
      nil ->
        dynamic(
          [events: events],
          ^conditions and json_extract_path(events.context, ^path) == ^value
        )

      %{logical_operator: :and} ->
        dynamic(
          [events: events],
          ^conditions and json_extract_path(events.context, ^path) == ^value
        )

      %{logical_operator: :or} ->
        dynamic(
          [events: events],
          ^conditions or json_extract_path(events.context, ^path) == ^value
        )

      _ ->
        conditions
    end
  end

  def apply_predicate(
        %{
          condition: %{identifier: field, comparison_operator: "==", expression: value}
        },
        conditions,
        previous_predicate
      ) do
    field = String.to_atom(field)

    case previous_predicate do
      nil ->
        dynamic([events: events], ^conditions and field(events, ^field) == ^value)

      %{logical_operator: :and} ->
        dynamic([events: events], ^conditions and field(events, ^field) == ^value)

      %{logical_operator: :or} ->
        dynamic([events: events], ^conditions or field(events, ^field) == ^value)

      _ ->
        conditions
    end
  end
```


## API Reference

### Core Functions

#### `Predicated.test/3`
Tests predicates against a subject data structure.

```elixir
# With query string
Predicated.test("status == 'active'", %{status: "active"})
#=> true

# With predicate structs
predicates = [%Predicate{condition: %Condition{...}}]
Predicated.test(predicates, %{...})
#=> true
```

#### `Predicated.Query.new/1`
Parses a query string into predicate structs.

```elixir
{:ok, predicates} = Predicated.Query.new("age > 18 AND verified == true")
```

#### `Predicated.to_query/1`
Converts predicate structs back to a query string.

```elixir
query_string = Predicated.to_query(predicates)
#=> "age > 18 AND verified == true"
```

### Supported Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `==` | Equality | `status == 'active'` |
| `!=` | Inequality | `status != 'deleted'` |
| `>` | Greater than | `age > 18` |
| `>=` | Greater than or equal | `score >= 75` |
| `<` | Less than | `price < 100.00` |
| `<=` | Less than or equal | `quantity <= 10` |
| `contains` | List contains value | `tags contains 'featured'` |
| `in` | Value in list | `status in ['active', 'pending']` |

### Type Support

#### Strings
```elixir
Predicated.test("name == 'John Doe'", %{name: "John Doe"})
```

#### Numbers (Integer and Float)
```elixir
Predicated.test("age >= 21 AND score > 85.5", %{age: 25, score: 90.0})
```

#### Booleans
```elixir
Predicated.test("verified == true AND active == FALSE", %{verified: true, active: false})
```

#### Dates
```elixir
Predicated.test("birth_date < '2000-01-01'::DATE", %{birth_date: ~D[1995-05-15]})
```

#### DateTimes
```elixir
Predicated.test("created_at >= '2023-01-01T00:00:00Z'::DATETIME", %{
  created_at: ~U[2023-06-15 10:30:00Z]
})
```

#### Lists
```elixir
# Check if list contains value
Predicated.test("tags contains 'elixir'", %{tags: ["elixir", "phoenix", "nerves"]})

# Check if value is in list
Predicated.test("role in ['admin', 'moderator']", %{role: "admin"})
```

### Nested Field Access

Access nested fields using dot notation:

```elixir
data = %{
  user: %{
    profile: %{
      settings: %{
        theme: "dark",
        notifications: true
      }
    }
  }
}

Predicated.test("user.profile.settings.theme == 'dark'", data)
#=> true
```

### Complex Queries

#### Combining Conditions
```elixir
# AND has higher precedence than OR
Predicated.test("a == 1 OR b == 2 AND c == 3", %{a: 1, b: 5, c: 3})
#=> true (evaluates as: a == 1 OR (b == 2 AND c == 3))
```

#### Grouping with Parentheses
```elixir
# Use parentheses to control precedence
Predicated.test("(a == 1 OR b == 2) AND c == 3", %{a: 5, b: 2, c: 3})
#=> true
```

#### Multi-level Nesting
```elixir
query = """
organization_id == '123' AND (
  role == 'admin' OR 
  (role == 'user' AND permissions contains 'write') OR
  (department == 'IT' AND level >= 3)
)
"""

Predicated.test(query, %{
  organization_id: "123",
  role: "user", 
  permissions: ["read", "write"],
  department: "Sales",
  level: 2
})
#=> true
```

## Error Handling

Query parsing errors return error tuples:

```elixir
case Predicated.Query.new("invalid == ") do
  {:ok, predicates} -> 
    # Use predicates
  {:error, reason} ->
    # Handle error
    IO.puts("Parse error: #{inspect(reason)}")
end
```

Common error types:
- `{:error, unparsed: "remaining text"}` - Query has unparsed remainder
- `{:error, "expected..."}` - Syntax error with expectation

## Performance Considerations

- Predicates are evaluated in-memory, suitable for filtering small to medium datasets
- For large datasets, consider using the Ecto integration to push filtering to the database
- Query string parsing has a one-time cost; reuse parsed predicates when possible

## TODO

- [x] Implement grouped/nested predicates in the query parser
- [x] Update docs to include example of using it with Ecto
- [x] Better handle non-terminal conditions when predicates are malformed
- [ ] More tests
- [ ] Write some macros that make integrating with Ecto nicer and drier
- [ ] Add debugger that displays all the conditions and their results
- [ ] Support for additional operators (like, starts_with, ends_with, regex)
- [ ] Support for nil/null checks
- [ ] Support for custom operators

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/predicated>.

