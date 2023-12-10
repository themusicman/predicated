defmodule Predicated.QueryTest do
  use ExUnit.Case, async: true
  alias Predicated.Predicate
  alias Predicated.Condition
  alias Predicated.Query

  describe "new/1" do
    test "parses a query with an in comparison_operator" do
      {:ok, datetime, _offset} = DateTime.from_iso8601("2015-01-23T23:50:07Z")

      results =
        Query.new(
          "trace_id in ['test123', 'test456', 1, 3.3, '2015-01-23T23:50:07Z'::DATETIME] and profile_id == '123'"
        )

      assert {
               :ok,
               [
                 %Predicate{
                   condition: %Condition{
                     identifier: "trace_id",
                     comparison_operator: "in",
                     expression: ["test123", "test456", 1, 3.3, datetime]
                   },
                   logical_operator: :and,
                   predicates: []
                 },
                 %Predicate{
                   condition: %Condition{
                     identifier: "profile_id",
                     comparison_operator: "==",
                     expression: "123"
                   },
                   logical_operator: nil,
                   predicates: []
                 }
               ]
             } == results
    end

    test "parses a query with an in comparison_operator that has uuids" do
      results =
        Query.new(
          "trace_id in ['580fa97a-8c54-4174-90ab-2f7ce0e71e61', 'e811ba6a-c304-4ac8-87d7-5bc0e3bf5d95']"
        )

      assert {
               :ok,
               [
                 %Predicate{
                   condition: %Condition{
                     identifier: "trace_id",
                     comparison_operator: "in",
                     expression: [
                       "580fa97a-8c54-4174-90ab-2f7ce0e71e61",
                       "e811ba6a-c304-4ac8-87d7-5bc0e3bf5d95"
                     ]
                   },
                   logical_operator: nil,
                   predicates: []
                 }
               ]
             } == results
    end

    test "parses a query with a logical operator" do
      results = Query.new("trace_id == 'test123' and profile_id == '123'")

      assert {
               :ok,
               [
                 %Predicate{
                   condition: %Condition{
                     identifier: "trace_id",
                     comparison_operator: "==",
                     expression: "test123"
                   },
                   logical_operator: :and,
                   predicates: []
                 },
                 %Predicate{
                   condition: %Condition{
                     identifier: "profile_id",
                     comparison_operator: "==",
                     expression: "123"
                   },
                   logical_operator: nil,
                   predicates: []
                 }
               ]
             } == results
    end

    test "parses a query with a string that contains a period" do
      results = Query.new("name == 'user.created'")

      assert {
               :ok,
               [
                 %Predicate{
                   condition: %Condition{
                     identifier: "name",
                     comparison_operator: "==",
                     expression: "user.created"
                   },
                   logical_operator: nil,
                   predicates: []
                 }
               ]
             } == results
    end

    test "parses a query with an integer" do
      results = Query.new("user_id == 1")

      assert {
               :ok,
               [
                 %Predicate{
                   condition: %Condition{
                     identifier: "user_id",
                     comparison_operator: "==",
                     expression: 1
                   },
                   logical_operator: nil,
                   predicates: []
                 }
               ]
             } == results
    end

    test "parses a query with a value cast as a datetime" do
      results = Query.new("inserted_at > '2015-01-23T23:50:07Z'::DATETIME")

      {:ok, datetime, _offset} = DateTime.from_iso8601("2015-01-23T23:50:07Z")

      assert {
               :ok,
               [
                 %Predicate{
                   condition: %Condition{
                     identifier: "inserted_at",
                     comparison_operator: ">",
                     expression: datetime
                   },
                   logical_operator: nil,
                   predicates: []
                 }
               ]
             } == results
    end

    test "parses a query with a value cast as a date" do
      {:ok, predicates} = Query.new("dob > '2015-01-23'::DATE")

      {:ok, date} = Date.from_iso8601("2015-01-23")

      assert [
               %Predicate{
                 condition: %Condition{
                   identifier: "dob",
                   comparison_operator: ">",
                   expression: date
                 },
                 logical_operator: nil,
                 predicates: []
               }
             ] == predicates

      assert Predicated.test(predicates, %{dob: ~D[2016-01-01]})
    end

    test "parses a query with a boolean" do
      {:ok, predicates} = Query.new("verified == true")

      assert [
               %Predicate{
                 condition: %Condition{
                   identifier: "verified",
                   comparison_operator: "==",
                   expression: true
                 },
                 logical_operator: nil,
                 predicates: []
               }
             ] == predicates

      assert Predicated.test(predicates, %{
               verified: true
             })

      {:ok, predicates} = Query.new("verified == false")

      assert [
               %Predicate{
                 condition: %Condition{
                   identifier: "verified",
                   comparison_operator: "==",
                   expression: false
                 },
                 logical_operator: nil,
                 predicates: []
               }
             ] == predicates

      assert Predicated.test(predicates, %{
               verified: false
             })
    end

    test "parses a query with a float" do
      results = Query.new("cart.total > 100.50 AND cart.total < 1000")

      assert {
               :ok,
               [
                 %Predicate{
                   condition: %Condition{
                     identifier: "cart.total",
                     comparison_operator: ">",
                     expression: 100.50
                   },
                   logical_operator: :and,
                   predicates: []
                 },
                 %Predicate{
                   condition: %Condition{
                     identifier: "cart.total",
                     comparison_operator: "<",
                     expression: 1000
                   },
                   logical_operator: nil,
                   predicates: []
                 }
               ]
             } == results
    end

    test "parses a query with a negative float" do
      results = Query.new("cart.total > -100.50")

      assert {
               :ok,
               [
                 %Predicate{
                   condition: %Condition{
                     identifier: "cart.total",
                     comparison_operator: ">",
                     expression: -100.50
                   },
                   logical_operator: nil,
                   predicates: []
                 }
               ]
             } == results
    end

    test "parses a query with a multiple logical operator" do
      results = Query.new("trace_id == 'test123' and profile_id == '123' or user_id == '123'")

      assert {
               :ok,
               [
                 %Predicate{
                   condition: %Condition{
                     identifier: "trace_id",
                     comparison_operator: "==",
                     expression: "test123"
                   },
                   logical_operator: :and,
                   predicates: []
                 },
                 %Predicate{
                   condition: %Condition{
                     identifier: "profile_id",
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
                     expression: "123"
                   },
                   logical_operator: nil,
                   predicates: []
                 }
               ]
             } == results
    end

    test "parses a query without a logical operator" do
      results = Query.new("trace_id == 'test123'")

      assert {
               :ok,
               [
                 %Predicate{
                   condition: %Condition{
                     identifier: "trace_id",
                     comparison_operator: "==",
                     expression: "test123"
                   },
                   logical_operator: nil,
                   predicates: []
                 }
               ]
             } == results
    end

    test "parses a query with grouped predictes" do
      results = Query.new("trace_id == 'test123' OR (user_id == '123' OR user_id == '456')")

      assert {:ok,
              [
                %Predicated.Predicate{
                  condition: %Predicated.Condition{
                    identifier: "trace_id",
                    comparison_operator: "==",
                    expression: "test123"
                  },
                  logical_operator: :or,
                  predicates: []
                },
                %Predicated.Predicate{
                  condition: nil,
                  logical_operator: nil,
                  predicates: [
                    %Predicated.Predicate{
                      condition: %Predicated.Condition{
                        identifier: "user_id",
                        comparison_operator: "==",
                        expression: "123"
                      },
                      logical_operator: :or,
                      predicates: []
                    },
                    %Predicated.Predicate{
                      condition: %Predicated.Condition{
                        identifier: "user_id",
                        comparison_operator: "==",
                        expression: "456"
                      },
                      logical_operator: nil,
                      predicates: []
                    }
                  ]
                }
              ]} == results
    end

    test "parses a query with grouped predictes and a predicate that follows a grouped predicate" do
      {:ok, predicates} =
        Query.new(
          "trace_id == 'test123' AND (user_id == '123' OR user_id == '456') AND organization_id == 1 AND cart.total > 100"
        )

      assert [
               %Predicated.Predicate{
                 condition: %Predicated.Condition{
                   identifier: "trace_id",
                   comparison_operator: "==",
                   expression: "test123"
                 },
                 logical_operator: :and,
                 predicates: []
               },
               %Predicated.Predicate{
                 condition: nil,
                 logical_operator: :and,
                 predicates: [
                   %Predicated.Predicate{
                     condition: %Predicated.Condition{
                       identifier: "user_id",
                       comparison_operator: "==",
                       expression: "123"
                     },
                     logical_operator: :or,
                     predicates: []
                   },
                   %Predicated.Predicate{
                     condition: %Predicated.Condition{
                       identifier: "user_id",
                       comparison_operator: "==",
                       expression: "456"
                     },
                     logical_operator: nil,
                     predicates: []
                   }
                 ]
               },
               %Predicated.Predicate{
                 condition: %Predicated.Condition{
                   identifier: "organization_id",
                   comparison_operator: "==",
                   expression: 1
                 },
                 logical_operator: :and,
                 predicates: []
               },
               %Predicate{
                 condition: %Condition{
                   identifier: "cart.total",
                   comparison_operator: ">",
                   expression: 100
                 },
                 logical_operator: nil,
                 predicates: []
               }
             ] == predicates

      assert Predicated.test(predicates, %{
               trace_id: "test123",
               user_id: "123",
               organization_id: 1,
               cart: %{total: 101}
             })

      assert Predicated.test(predicates, %{
               trace_id: "test123",
               user_id: "456",
               organization_id: 1,
               cart: %{total: 101}
             })

      refute Predicated.test(predicates, %{
               trace_id: "test123",
               user_id: "444",
               organization_id: 1,
               cart: %{total: 101}
             })

      refute Predicated.test(predicates, %{
               trace_id: "test456",
               user_id: "123",
               organization_id: 1,
               cart: %{total: 101}
             })
    end

    test "parses a query with nested grouped predictes" do
      {:ok, predicates} =
        Query.new(
          "trace_id == 'test123' AND ( organization_id == '1' OR (user_id == '123' OR user_id == '456'))"
        )

      assert [
               %Predicated.Predicate{
                 condition: %Predicated.Condition{
                   identifier: "trace_id",
                   comparison_operator: "==",
                   expression: "test123"
                 },
                 logical_operator: :and,
                 predicates: []
               },
               %Predicated.Predicate{
                 condition: nil,
                 logical_operator: nil,
                 predicates: [
                   %Predicated.Predicate{
                     condition: %Predicated.Condition{
                       identifier: "organization_id",
                       comparison_operator: "==",
                       expression: "1"
                     },
                     logical_operator: :or,
                     predicates: []
                   },
                   %Predicated.Predicate{
                     condition: nil,
                     logical_operator: nil,
                     predicates: [
                       %Predicated.Predicate{
                         condition: %Predicated.Condition{
                           identifier: "user_id",
                           comparison_operator: "==",
                           expression: "123"
                         },
                         logical_operator: :or,
                         predicates: []
                       },
                       %Predicated.Predicate{
                         condition: %Predicated.Condition{
                           identifier: "user_id",
                           comparison_operator: "==",
                           expression: "456"
                         },
                         logical_operator: nil,
                         predicates: []
                       }
                     ]
                   }
                 ]
               }
             ] == predicates

      assert Predicated.test(predicates, %{
               trace_id: "test123",
               user_id: "555",
               organization_id: "1"
             })

      assert Predicated.test(predicates, %{
               trace_id: "test123",
               user_id: "123",
               organization_id: "5"
             })

      assert Predicated.test(predicates, %{
               trace_id: "test123",
               user_id: "456",
               organization_id: "5"
             })
    end

    test "handles an empty string" do
      results = Query.new("")

      assert {:error, _} = results
    end

    test "handles an invalid query string" do
      results = Query.new("lakjsdlkj")

      assert {:error, _} = results
    end
  end
end
