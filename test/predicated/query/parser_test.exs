defmodule Predicated.QueryTest do
  use ExUnit.Case, async: true
  alias Predicated.Predicate
  alias Predicated.Condition
  alias Predicated.Query

  describe "new/1" do
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
      results =
        Query.new(
          "trace_id == 'test123' AND (user_id == '123' OR user_id == '456') OR organization_id == '1'"
        )

      assert {:ok,
              [
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
                  logical_operator: :or,
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
                    expression: "1"
                  },
                  logical_operator: nil,
                  predicates: []
                }
              ]} == results
    end

    test "parses a query with nested grouped predictes" do
      results =
        Query.new(
          "trace_id == 'test123' AND ( organization_id == '1' OR (user_id == '123' OR user_id == '456'))"
        )

      assert {:ok,
              [
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
              ]} == results
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
