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

    test "handles an empty string" do
      results = Query.new("")

      assert {:ok, []} == results
    end

    test "handles an invalid query string" do
      results = Query.new("lakjsdlkj")

      assert {:error, "expected end of string"} == results
    end
  end
end
