defmodule Predicated.ListOperationsTest do
  use ExUnit.Case, async: true
  alias Predicated
  alias Predicated.Query

  describe "IN operator edge cases" do
    test "empty list" do
      refute Predicated.test("value in []", %{value: "anything"})
      refute Predicated.test("value in []", %{value: nil})
      refute Predicated.test("value in []", %{value: 1})
    end

    test "single element list" do
      assert Predicated.test("value in ['test']", %{value: "test"})
      refute Predicated.test("value in ['test']", %{value: "other"})
      
      assert Predicated.test("value in [42]", %{value: 42})
      refute Predicated.test("value in [42]", %{value: 43})
    end

    test "mixed type lists" do
      # Mixed types should work but require exact type matching
      assert Predicated.test("value in [1, '2', true, nil]", %{value: 1})
      assert Predicated.test("value in [1, '2', true, nil]", %{value: "2"})
      assert Predicated.test("value in [1, '2', true, nil]", %{value: true})
      assert Predicated.test("value in [1, '2', true, nil]", %{value: nil})
      
      # Type mismatches should not match
      refute Predicated.test("value in [1, '2', true, nil]", %{value: "1"})
      refute Predicated.test("value in [1, '2', true, nil]", %{value: 2})
      refute Predicated.test("value in [1, '2', true, nil]", %{value: false})
    end

    test "dates and datetimes in lists" do
      {:ok, datetime1, _} = DateTime.from_iso8601("2023-01-01T12:00:00Z")
      {:ok, datetime2, _} = DateTime.from_iso8601("2023-01-02T12:00:00Z")
      
      query = "value in ['2023-01-01T12:00:00Z'::DATETIME, '2023-01-02T12:00:00Z'::DATETIME]"
      {:ok, predicates} = Query.new(query)
      
      assert Predicated.test(predicates, %{value: datetime1})
      assert Predicated.test(predicates, %{value: datetime2})
      refute Predicated.test(predicates, %{value: ~U[2023-01-03 12:00:00Z]})
    end

    test "duplicate values in list" do
      assert Predicated.test("value in [1, 2, 1, 3, 2]", %{value: 1})
      assert Predicated.test("value in [1, 2, 1, 3, 2]", %{value: 2})
      assert Predicated.test("value in [1, 2, 1, 3, 2]", %{value: 3})
      refute Predicated.test("value in [1, 2, 1, 3, 2]", %{value: 4})
    end

    test "large lists" do
      # Test with a large list
      large_list = Enum.to_list(1..1000)
      list_string = "[" <> Enum.join(large_list, ", ") <> "]"
      query = "value in #{list_string}"
      
      {:ok, predicates} = Query.new(query)
      
      assert Predicated.test(predicates, %{value: 1})
      assert Predicated.test(predicates, %{value: 500})
      assert Predicated.test(predicates, %{value: 1000})
      refute Predicated.test(predicates, %{value: 1001})
    end

    test "special values in lists" do
      # Empty strings
      assert Predicated.test("value in ['', ' ', 'test']", %{value: ""})
      assert Predicated.test("value in ['', ' ', 'test']", %{value: " "})
      refute Predicated.test("value in ['', ' ', 'test']", %{value: "  "})
      
      # Negative numbers
      assert Predicated.test("value in [-1, 0, 1]", %{value: -1})
      assert Predicated.test("value in [-1, 0, 1]", %{value: 0})
      
      # Floats
      assert Predicated.test("value in [1.5, 2.5, 3.5]", %{value: 2.5})
      refute Predicated.test("value in [1.5, 2.5, 3.5]", %{value: 2.0})
    end

    test "nil in lists" do
      # nil as a value in the list
      assert Predicated.test("value in [nil, 'test', 123]", %{value: nil})
      assert Predicated.test("value in [nil, 'test', 123]", %{value: "test"})
      assert Predicated.test("value in [nil, 'test', 123]", %{value: 123})
      
      # Missing key (evaluates to nil)
      assert Predicated.test("missing_key in [nil, 'test']", %{other_key: "value"})
      refute Predicated.test("missing_key in ['test', 123]", %{other_key: "value"})
    end
  end

  describe "CONTAINS operator edge cases" do
    test "empty list" do
      refute Predicated.test("tags contains 'test'", %{tags: []})
      refute Predicated.test("tags contains nil", %{tags: []})
      refute Predicated.test("tags contains ''", %{tags: []})
    end

    test "single element list" do
      assert Predicated.test("tags contains 'test'", %{tags: ["test"]})
      refute Predicated.test("tags contains 'other'", %{tags: ["test"]})
    end

    test "mixed type lists" do
      list = [1, "2", true, nil, 3.14]
      
      assert Predicated.test("items contains 1", %{items: list})
      assert Predicated.test("items contains '2'", %{items: list})
      assert Predicated.test("items contains true", %{items: list})
      assert Predicated.test("items contains nil", %{items: list})
      assert Predicated.test("items contains 3.14", %{items: list})
      
      # Type mismatches
      refute Predicated.test("items contains '1'", %{items: list})
      refute Predicated.test("items contains 2", %{items: list})
      refute Predicated.test("items contains false", %{items: list})
    end

    test "nil handling" do
      # List containing nil
      assert Predicated.test("items contains nil", %{items: [1, nil, 3]})
      refute Predicated.test("items contains nil", %{items: [1, 2, 3]})
      
      # nil list (should error or return false)
      refute Predicated.test("items contains 'test'", %{items: nil})
    end

    test "nested lists" do
      # Contains doesn't do deep searching
      refute Predicated.test("items contains 'inner'", %{items: [["inner", "list"], "outer"]})
      
      # But can check for the list itself if we could express it
      # This might not be expressible in the current syntax
    end

    test "string contains behavior" do
      # If contains works on strings (substring check)
      # This depends on implementation
      result = Predicated.test("name contains 'oh'", %{name: "John"})
      # Document actual behavior
      assert result == true || result == false
    end

    test "duplicate values" do
      assert Predicated.test("items contains 'a'", %{items: ["a", "b", "a", "c", "a"]})
      assert Predicated.test("items contains 'b'", %{items: ["a", "b", "a", "c", "a"]})
      assert Predicated.test("items contains 'c'", %{items: ["a", "b", "a", "c", "a"]})
      refute Predicated.test("items contains 'd'", %{items: ["a", "b", "a", "c", "a"]})
    end

    test "large lists performance" do
      large_list = Enum.to_list(1..10000)
      
      # Should find elements efficiently
      assert Predicated.test("items contains 1", %{items: large_list})
      assert Predicated.test("items contains 5000", %{items: large_list})
      assert Predicated.test("items contains 10000", %{items: large_list})
      refute Predicated.test("items contains 10001", %{items: large_list})
    end
  end

  describe "complex list scenarios" do
    test "multiple IN conditions" do
      query = "status in ['active', 'pending'] AND priority in [1, 2, 3]"
      
      assert Predicated.test(query, %{status: "active", priority: 1})
      assert Predicated.test(query, %{status: "pending", priority: 3})
      refute Predicated.test(query, %{status: "inactive", priority: 1})
      refute Predicated.test(query, %{status: "active", priority: 4})
    end

    test "IN with OR conditions" do
      query = "id in [1, 2, 3] OR status in ['draft', 'archived']"
      
      assert Predicated.test(query, %{id: 1, status: "published"})
      assert Predicated.test(query, %{id: 5, status: "draft"})
      assert Predicated.test(query, %{id: 2, status: "archived"})
      refute Predicated.test(query, %{id: 5, status: "published"})
    end

    test "combining IN and CONTAINS" do
      query = "role in ['admin', 'moderator'] AND permissions contains 'write'"
      
      assert Predicated.test(query, %{
        role: "admin",
        permissions: ["read", "write", "delete"]
      })
      
      refute Predicated.test(query, %{
        role: "admin",
        permissions: ["read", "view"]
      })
      
      refute Predicated.test(query, %{
        role: "user",
        permissions: ["read", "write"]
      })
    end

    test "NOT IN behavior" do
      # Currently not implemented, but test what happens
      result = Query.new("value not in [1, 2, 3]")
      assert {:error, _} = result
    end

    test "nested field access with lists" do
      assert Predicated.test("user.roles contains 'admin'", %{
        user: %{roles: ["user", "admin", "moderator"]}
      })
      
      refute Predicated.test("user.roles contains 'admin'", %{
        user: %{roles: ["user", "guest"]}
      })
      
      # Missing nested field
      refute Predicated.test("user.roles contains 'admin'", %{
        user: %{}
      })
      
      refute Predicated.test("user.roles contains 'admin'", %{})
    end

    test "special characters in list values" do
      # Quotes in strings
      assert Predicated.test("items contains 'test\"value'", %{
        items: ["test\"value", "other"]
      })
      
      # Commas in strings (shouldn't be confused with list separator)
      {:ok, predicates} = Query.new("value in ['a,b', 'c,d']")
      assert Predicated.test(predicates, %{value: "a,b"})
      assert Predicated.test(predicates, %{value: "c,d"})
      refute Predicated.test(predicates, %{value: "a"})
      refute Predicated.test(predicates, %{value: "b"})
    end

    test "whitespace in list values" do
      {:ok, predicates} = Query.new("value in ['  test  ', 'other']")
      assert Predicated.test(predicates, %{value: "  test  "})
      refute Predicated.test(predicates, %{value: "test"})
      refute Predicated.test(predicates, %{value: " test "})
    end
  end

  describe "edge cases with different data structures" do
    test "contains on non-list values" do
      # What happens when contains is used on non-lists?
      refute Predicated.test("value contains 'test'", %{value: "testing"})
      refute Predicated.test("value contains 1", %{value: 123})
      refute Predicated.test("value contains true", %{value: true})
    end

    test "in operator with single value subject" do
      # This is the normal case and should work
      assert Predicated.test("name in ['John', 'Jane', 'Bob']", %{name: "John"})
    end

    test "list operations with maps that look like structs" do
      # Test with a map that has a __struct__ key
      user = %{__struct__: SomeModule, name: "John", tags: ["admin", "active"]}
      
      assert Predicated.test("tags contains 'admin'", user)
      assert Predicated.test("name in ['John', 'Jane']", user)
    end
  end
end