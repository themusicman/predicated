defmodule Predicated.PredicateTest do
  use ExUnit.Case, async: true
  alias Predicated.Predicate
  alias Predicated.Condition

  describe "to_query/1" do
    test "returns a query string for a predicate that has no nesting and a string" do
      predicate = %Predicate{
        condition: %Condition{
          identifier: "trace_id",
          comparison_operator: "==",
          expression: "test123"
        },
        logical_operator: nil,
        predicates: []
      }

      assert Predicate.to_query(predicate) == "trace_id == 'test123'"
    end

    test "returns a query string for a predicate that has no nesting and an integer" do
      predicate = %Predicate{
        condition: %Condition{
          identifier: "count",
          comparison_operator: "==",
          expression: 1
        },
        logical_operator: nil,
        predicates: []
      }

      assert Predicate.to_query(predicate) == "count == 1"
    end

    test "returns a query string for a predicate that has no nesting and an float" do
      predicate = %Predicate{
        condition: %Condition{
          identifier: "count",
          comparison_operator: "==",
          expression: 1.3
        },
        logical_operator: nil,
        predicates: []
      }

      assert Predicate.to_query(predicate) == "count == 1.3"
    end

    test "returns a query string for a predicate that has no nesting and an datetime" do
      datetime = ~U[2020-01-01 10:00:00Z]
      datetime_str = DateTime.to_iso8601(datetime)

      predicate = %Predicate{
        condition: %Condition{
          identifier: "inserted_at",
          comparison_operator: ">",
          expression: datetime
        },
        logical_operator: nil,
        predicates: []
      }

      assert Predicate.to_query(predicate) == "inserted_at > '#{datetime_str}'::DATETIME"
    end

    test "returns a query string for a predicate that has no nesting and an date" do
      date = ~D[2020-01-01]
      date_str = Date.to_iso8601(date)

      predicate = %Predicate{
        condition: %Condition{
          identifier: "dob",
          comparison_operator: ">",
          expression: date
        },
        logical_operator: nil,
        predicates: []
      }

      assert Predicate.to_query(predicate) == "dob > '#{date_str}'::DATE"
    end

    test "returns a query string for a predicate that has no nesting and a logical operator" do
      predicate = %Predicate{
        condition: %Condition{
          identifier: "trace_id",
          comparison_operator: "==",
          expression: "test123"
        },
        logical_operator: :and,
        predicates: []
      }

      assert Predicate.to_query(predicate) == "trace_id == 'test123' AND"
    end

    test "returns a query string for a predicate that has grouping" do
      predicate = %Predicate{
        condition: nil,
        logical_operator: nil,
        predicates: [
          %Predicate{
            condition: %Condition{
              identifier: "user_id",
              comparison_operator: "==",
              expression: "123"
            },
            logical_operator: :or,
            predicates: []
          },
          %Predicate{
            condition: %Condition{
              identifier: "user_id",
              comparison_operator: "==",
              expression: "456"
            },
            logical_operator: nil,
            predicates: []
          }
        ]
      }

      assert Predicate.to_query(predicate) == "(user_id == '123' OR user_id == '456')"
    end

    test "returns a query string for a predicate that has grouping and trailing logical operator" do
      predicate = %Predicate{
        condition: nil,
        logical_operator: :or,
        predicates: [
          %Predicate{
            condition: %Condition{
              identifier: "user_id",
              comparison_operator: "==",
              expression: "123"
            },
            logical_operator: :or,
            predicates: []
          },
          %Predicate{
            condition: %Condition{
              identifier: "user_id",
              comparison_operator: "==",
              expression: "456"
            },
            logical_operator: nil,
            predicates: []
          }
        ]
      }

      assert Predicate.to_query(predicate) == "(user_id == '123' OR user_id == '456') OR"
    end
  end
end
