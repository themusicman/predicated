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


## TODO

- [x] Implement grouped/nested predicates in the query parser
- [ ] Better handle non-terminal conditions when predicates are malformed
- [ ] Add debugger that displays all the conditions and their results
- [ ] Update docs to include example of using Ecto to store the predicates
- [ ] More tests

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/predicated>.

