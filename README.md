# Predicated

[![Elixir CI](https://github.com/themusicman/predicated/actions/workflows/elixir.yml/badge.svg)](https://github.com/themusicman/predicated/actions/workflows/elixir.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/predicated.svg)](https://hex.pm/packages/predicated)

A library for building and evaluating predicates against in-memory data structures in Elixir. Define conditions using query strings or structs, then test them against maps and structs with full support for nested fields, boolean logic, and type-safe comparisons.

## Installation

Add `predicated` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:predicated, "~> 1.1"}
  ]
end
```

## Quick Start

```elixir
# Simple equality check
Predicated.test("status == 'active'", %{status: "active"})
#=> true

# Multiple conditions with AND
Predicated.test("age >= 21 AND verified == true", %{age: 25, verified: true})
#=> true

# Nested field access with dot notation
Predicated.test("user.role == 'admin'", %{user: %{role: "admin"}})
#=> true
```

## Query String Syntax

Query strings are the primary way to define predicates. They follow the format:

```
identifier operator expression [logical_operator identifier operator expression ...]
```

### Identifiers

Identifiers reference fields in the subject data structure. Use dot notation for nested access:

```elixir
# Top-level field
Predicated.test("name == 'Alice'", %{name: "Alice"})
#=> true

# Nested field
Predicated.test("user.profile.email == 'alice@example.com'", %{
  user: %{profile: %{email: "alice@example.com"}}
})
#=> true

# Deeply nested
Predicated.test("config.database.pool.size > 5", %{
  config: %{database: %{pool: %{size: 10}}}
})
#=> true
```

### Comparison Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `==` | Equal to | `status == 'active'` |
| `!=` | Not equal to | `status != 'deleted'` |
| `>` | Greater than | `age > 18` |
| `>=` | Greater than or equal | `score >= 75` |
| `<` | Less than | `price < 100.00` |
| `<=` | Less than or equal | `quantity <= 10` |
| `contains` | List contains value | `tags contains 'featured'` |
| `not contains` | List does not contain value | `tags not contains 'archived'` |
| `in` | Value is in list | `status in ['active', 'pending']` |

### Logical Operators

Combine conditions with `AND` and `OR` (case-insensitive):

```elixir
# AND - both conditions must be true
Predicated.test("age >= 21 AND country == 'US'", %{age: 25, country: "US"})
#=> true

# OR - at least one condition must be true
Predicated.test("role == 'admin' OR role == 'moderator'", %{role: "moderator"})
#=> true

# Case-insensitive operators
Predicated.test("a == 1 and b == 2", %{a: 1, b: 2})
#=> true

Predicated.test("a == 1 or b == 2", %{a: 1, b: 99})
#=> true
```

### Operator Precedence

`AND` has higher precedence than `OR`. Use parentheses to override:

```elixir
# Without parentheses: AND binds tighter
# Evaluates as: a == 1 OR (b == 2 AND c == 3)
Predicated.test("a == 1 OR b == 2 AND c == 3", %{a: 1, b: 0, c: 0})
#=> true

# With parentheses: OR is evaluated first
# Evaluates as: (a == 1 OR b == 2) AND c == 3
Predicated.test("(a == 1 OR b == 2) AND c == 3", %{a: 1, b: 0, c: 3})
#=> true

Predicated.test("(a == 1 OR b == 2) AND c == 3", %{a: 1, b: 0, c: 0})
#=> false
```

### Grouping with Parentheses

Parentheses control evaluation order and can be nested to any depth:

```elixir
# Simple grouping
Predicated.test(
  "active == true AND (role == 'admin' OR role == 'editor')",
  %{active: true, role: "editor"}
)
#=> true

# Multi-level nesting
query = """
organization_id == '123' AND (
  role == 'admin' OR
  (role == 'user' AND permissions contains 'write') OR
  (department == 'engineering' AND level >= 3)
)
"""

Predicated.test(query, %{
  organization_id: "123",
  role: "user",
  permissions: ["read", "write"],
  department: "sales",
  level: 1
})
#=> true (matched: role == 'user' AND permissions contains 'write')
```

## Data Types

### Strings

Strings are enclosed in single quotes. They support special characters including `@`, `.`, `/`, `+`, `-`, and Unicode:

```elixir
Predicated.test("email == 'user@example.com'", %{email: "user@example.com"})
#=> true

Predicated.test("name == 'O\\'Brien'", %{name: "O'Brien"})
#=> true

Predicated.test("id == '550e8400-e29b-41d4-a716-446655440000'", %{
  id: "550e8400-e29b-41d4-a716-446655440000"
})
#=> true
```

### Numbers

Integers, floats, negative numbers, and scientific notation:

```elixir
# Integers
Predicated.test("count == 42", %{count: 42})
#=> true

# Floats
Predicated.test("price < 19.99", %{price: 15.50})
#=> true

# Negative numbers
Predicated.test("temperature > -10", %{temperature: 5})
#=> true

# Scientific notation
Predicated.test("distance > 1.5e6", %{distance: 2_000_000})
#=> true
```

### Booleans

`true` and `false` (case-insensitive):

```elixir
Predicated.test("verified == true", %{verified: true})
#=> true

Predicated.test("deleted == FALSE", %{deleted: false})
#=> true

Predicated.test("active == TRUE AND admin == false", %{active: true, admin: false})
#=> true
```

### Nil / Null

Check for nil values using `nil`, `NIL`, `null`, or `NULL`:

```elixir
Predicated.test("deleted_at == nil", %{deleted_at: nil})
#=> true

Predicated.test("email != null", %{email: "user@example.com"})
#=> true

# Missing fields are treated as nil
Predicated.test("nickname == nil", %{name: "Alice"})
#=> true
```

### Dates

Date values use the `::DATE` type cast with ISO 8601 format:

```elixir
Predicated.test("birthday >= '2000-01-01'::DATE", %{birthday: ~D[2000-06-15]})
#=> true

Predicated.test("expiry < '2025-12-31'::DATE", %{expiry: ~D[2025-06-01]})
#=> true

# Date range check
Predicated.test(
  "start_date >= '2024-01-01'::DATE AND start_date <= '2024-12-31'::DATE",
  %{start_date: ~D[2024-07-04]}
)
#=> true
```

### DateTimes

DateTime values use the `::DATETIME` type cast with ISO 8601 format:

```elixir
Predicated.test(
  "created_at >= '2024-01-01T00:00:00Z'::DATETIME",
  %{created_at: ~U[2024-06-15 10:30:00Z]}
)
#=> true

# NaiveDateTime values are automatically converted to UTC for comparison
Predicated.test(
  "updated_at > '2024-01-01T00:00:00Z'::DATETIME",
  %{updated_at: ~N[2024-06-15 10:30:00]}
)
#=> true
```

### Lists

Lists use bracket notation and work with the `in`, `contains`, and `not contains` operators:

```elixir
# Check if a value is in a predefined list
Predicated.test("status in ['active', 'pending', 'review']", %{status: "pending"})
#=> true

# Check if a list field contains a value
Predicated.test("tags contains 'elixir'", %{tags: ["elixir", "phoenix", "otp"]})
#=> true

# Negated contains
Predicated.test("roles not contains 'banned'", %{roles: ["user", "contributor"]})
#=> true

# Numeric lists
Predicated.test("score in [85, 90, 95, 100]", %{score: 90})
#=> true

# Mixed type lists
Predicated.test("value in [1, 'two', 3]", %{value: "two"})
#=> true
```

## Real-World Examples

### User Authorization

```elixir
# Check if a user has access to a resource
access_rule = """
organization_id == 'org_123' AND (
  role == 'admin' OR
  role == 'owner' OR
  (role == 'member' AND permissions contains 'read')
)
"""

user = %{
  organization_id: "org_123",
  role: "member",
  permissions: ["read", "comment"]
}

Predicated.test(access_rule, user)
#=> true
```

### E-Commerce Product Filtering

```elixir
filter = "category == 'electronics' AND price <= 500 AND in_stock == true AND rating >= 4.0"

products = [
  %{name: "Laptop", category: "electronics", price: 450, in_stock: true, rating: 4.5},
  %{name: "Phone", category: "electronics", price: 800, in_stock: true, rating: 4.8},
  %{name: "Mouse", category: "electronics", price: 25, in_stock: false, rating: 4.2},
  %{name: "Tablet", category: "electronics", price: 350, in_stock: true, rating: 3.9}
]

Enum.filter(products, &Predicated.test(filter, &1))
#=> [%{name: "Laptop", ...}]
```

### Event Log Filtering

```elixir
query = "level == 'error' AND source == 'payments' AND timestamp >= '2024-06-01T00:00:00Z'::DATETIME"

events = [
  %{level: "error", source: "payments", message: "timeout", timestamp: ~U[2024-06-15 10:00:00Z]},
  %{level: "info", source: "payments", message: "success", timestamp: ~U[2024-06-15 10:01:00Z]},
  %{level: "error", source: "auth", message: "failed", timestamp: ~U[2024-06-15 10:02:00Z]}
]

Enum.filter(events, &Predicated.test(query, &1))
#=> [%{level: "error", source: "payments", message: "timeout", ...}]
```

### Feature Flags

```elixir
# Define feature flag rules
flag_rule = "plan in ['pro', 'enterprise'] OR (plan == 'free' AND beta_tester == true)"

# Check if a user qualifies
Predicated.test(flag_rule, %{plan: "free", beta_tester: true})
#=> true

Predicated.test(flag_rule, %{plan: "free", beta_tester: false})
#=> false

Predicated.test(flag_rule, %{plan: "pro", beta_tester: false})
#=> true
```

### Form Validation Rules

```elixir
rules = [
  {"age >= 18", "Must be 18 or older"},
  {"email != nil", "Email is required"},
  {"password_length >= 8", "Password must be at least 8 characters"}
]

form_data = %{age: 16, email: "test@example.com", password_length: 6}

errors =
  rules
  |> Enum.reject(fn {rule, _msg} -> Predicated.test(rule, form_data) end)
  |> Enum.map(fn {_rule, msg} -> msg end)
#=> ["Must be 18 or older", "Password must be at least 8 characters"]
```

## Working with Predicate Structs

For programmatic construction, you can build predicates using structs directly:

```elixir
alias Predicated.Predicate
alias Predicated.Condition

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
      identifier: "age",
      comparison_operator: ">=",
      expression: 21
    }
  }
]

Predicated.test(predicates, %{status: "active", age: 25})
#=> true
```

### Grouped Predicates with Structs

Nested logic is represented by putting predicates inside the `predicates` field:

```elixir
predicates = [
  %Predicate{
    condition: %Condition{
      identifier: "org_id",
      comparison_operator: "==",
      expression: "123"
    },
    logical_operator: :and
  },
  %Predicate{
    predicates: [
      %Predicate{
        condition: %Condition{
          identifier: "role",
          comparison_operator: "==",
          expression: "admin"
        },
        logical_operator: :or
      },
      %Predicate{
        condition: %Condition{
          identifier: "role",
          comparison_operator: "==",
          expression: "editor"
        }
      }
    ]
  }
]

# Equivalent to: org_id == '123' AND (role == 'admin' OR role == 'editor')
Predicated.test(predicates, %{org_id: "123", role: "editor"})
#=> true
```

### Plain Maps

Structs are not required. Plain maps with the same shape work too:

```elixir
predicates = [
  %{
    condition: %{
      identifier: "name",
      comparison_operator: "==",
      expression: "Alice"
    },
    logical_operator: :and,
    predicates: []
  },
  %{
    condition: %{
      identifier: "active",
      comparison_operator: "==",
      expression: true
    },
    predicates: []
  }
]

Predicated.test(predicates, %{name: "Alice", active: true})
#=> true
```

## Parsing Query Strings

Use `Predicated.Query.new/1` to parse a query string into predicate structs:

```elixir
{:ok, predicates} = Predicated.Query.new("status == 'active' AND age > 21")

# Inspect the parsed result
predicates
#=> [
#   %Predicated.Predicate{
#     condition: %Predicated.Condition{
#       identifier: "status",
#       comparison_operator: "==",
#       expression: "active"
#     },
#     logical_operator: :and,
#     predicates: []
#   },
#   %Predicated.Predicate{
#     condition: %Predicated.Condition{
#       identifier: "age",
#       comparison_operator: ">",
#       expression: 21
#     },
#     logical_operator: nil,
#     predicates: []
#   }
# ]
```

### Converting Back to Query Strings

```elixir
{:ok, predicates} = Predicated.Query.new("name == 'John' AND age > 21")

Predicated.to_query(predicates)
#=> "name == 'John' AND age > 21"
```

This is useful for logging, debugging, or serializing predicates for storage.

## Error Handling

### Parse Errors

`Predicated.Query.new/1` returns error tuples for invalid queries:

```elixir
case Predicated.Query.new("invalid query ==") do
  {:ok, predicates} ->
    Predicated.test(predicates, data)

  {:error, reason} ->
    Logger.warning("Invalid query: #{inspect(reason)}")
    false
end
```

### Graceful Degradation

When `Predicated.test/2` receives an unparseable query string, it logs the error and returns `false` instead of raising:

```elixir
# Bad query - logs error, returns false
Predicated.test("not a valid query !!!", %{foo: "bar"})
#=> false (logs: "Could not parse the query: ...")
```

### Missing Fields

Missing fields are treated as `nil`. Comparisons with nil return `false` for ordering operators:

```elixir
# Field doesn't exist - treated as nil
Predicated.test("missing_field == nil", %{other: "value"})
#=> true

Predicated.test("missing_field > 10", %{other: "value"})
#=> false
```

## Ecto Integration

Predicates can be translated to Ecto dynamic queries. While there isn't built-in automatic support yet, you can recursively walk the predicate structs to build `dynamic/1` expressions.

Here's a pattern used in production (from [EventRelay](https://github.com/eventrelay/eventrelay)):

```elixir
import Ecto.Query

def apply_predicates([predicate | predicates], nil, nil) do
  conditions = apply_predicate(predicate, dynamic(true), nil)
  apply_predicates(predicates, conditions, predicate)
end

def apply_predicates([predicate | predicates], conditions, previous_predicate) do
  conditions = apply_predicate(predicate, conditions, previous_predicate)
  apply_predicates(predicates, conditions, predicate)
end

def apply_predicates([], conditions, _previous_predicate), do: conditions

def apply_predicate(
      %{condition: %{identifier: field, comparison_operator: "==", expression: value}},
      conditions,
      previous_predicate
    ) do
  field = String.to_atom(field)

  case previous_predicate do
    nil ->
      dynamic([r], ^conditions and field(r, ^field) == ^value)

    %{logical_operator: :and} ->
      dynamic([r], ^conditions and field(r, ^field) == ^value)

    %{logical_operator: :or} ->
      dynamic([r], ^conditions or field(r, ^field) == ^value)
  end
end
```

Then use it in your queries:

```elixir
{:ok, predicates} = Predicated.Query.new("status == 'active' AND role == 'admin'")
conditions = apply_predicates(predicates, nil, nil)

from(u in User, where: ^conditions)
|> Repo.all()
```

## Performance

- Predicates are evaluated in-memory, suitable for filtering small to medium datasets
- For large datasets, push filtering to the database using the Ecto integration pattern above
- Query string parsing has a one-time cost; parse once and reuse predicates when evaluating against multiple subjects:

```elixir
# Parse once
{:ok, predicates} = Predicated.Query.new("status == 'active' AND score > 80")

# Reuse against many subjects
results = Enum.filter(large_list, &Predicated.test(predicates, &1))
```

## Security

- **Atom exhaustion prevention**: Identifiers are converted using `String.to_existing_atom/1` to prevent denial-of-service via unbounded atom creation from user input
- **Input validation**: Type casts and field names are validated during parsing
- **Safe type handling**: Type mismatches and nil values are handled gracefully without raising exceptions

## TODO

- [x] Grouped/nested predicates in the query parser
- [x] Ecto integration example
- [x] Better handling of malformed predicates
- [ ] Macros for cleaner Ecto integration
- [ ] Debugger for condition visualization
- [ ] Additional operators (`like`, `starts_with`, `ends_with`, `regex`)
- [ ] `NOT` operator for negating groups
- [ ] Custom operator support

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/predicated](https://hexdocs.pm/predicated).
