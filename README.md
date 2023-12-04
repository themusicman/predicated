# Predicated

Predicated is a library that allows for building predicates to query an in-memory data structure in Elixir.

## Installation

If [available in Hex](https://hex.pm/packages/predicated), the package can be installed
by adding `predicated` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:predicated, "~> 1.0"}
  ]
end
```

## Examples

Using Structs

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

Using a query string

```elixir
assert Predicated.test("trace_id != 'test123' and profile_id == '123'", %{
  trace_id: "test123",
  profile_id: "123"
}) == false

```


## TODO

- [ ] Implemented nested predicates in the query parser
- [ ] Add a to_sql function that turns the predicate data structure into where clauses in an ecto query
- [ ] Better handle non-terminal conditions when predicates are malformed
- [ ] Add debugger that displays all the conditions and their results
- [ ] Update docs to include example of using Ecto to store the predicates
- [ ] More tests

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/predicated>.

