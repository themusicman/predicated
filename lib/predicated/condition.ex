defmodule Predicated.Condition do
  @moduledoc """
  Represents a single condition to be evaluated in a predicate.

  A condition consists of three parts that form a comparison:
  - An identifier (the field to check)
  - A comparison operator
  - An expression (the value to compare against)

  ## Fields

  - `:identifier` - String representing the field path (supports dot notation)
  - `:comparison_operator` - String operator: "==", "!=", ">", ">=", "<", "<=", "contains", "in"
  - `:expression` - The value to compare against (any type)

  ## Examples

      # Simple equality check
      %Condition{
        identifier: "status",
        comparison_operator: "==",
        expression: "active"
      }

      # Numeric comparison
      %Condition{
        identifier: "age", 
        comparison_operator: ">=",
        expression: 18
      }

      # Nested field access
      %Condition{
        identifier: "user.profile.verified",
        comparison_operator: "==", 
        expression: true
      }

      # List operations
      %Condition{
        identifier: "tags",
        comparison_operator: "contains",
        expression: "important"
      }

      # Date comparison
      %Condition{
        identifier: "created_at",
        comparison_operator: ">",
        expression: ~D[2023-01-01]
      }
  """
  
  defstruct identifier: nil, comparison_operator: nil, expression: nil
end
