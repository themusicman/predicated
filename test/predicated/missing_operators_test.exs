defmodule Predicated.MissingOperatorsTest do
  use ExUnit.Case, async: true
  alias Predicated
  alias Predicated.Query

  describe "operators that should be implemented" do
    test "NOT IN operator" do
      # Test current behavior - likely returns error
      assert {:error, _} = Query.new("status not in ['inactive', 'deleted']")
      
      # Document desired behavior
      # Should work like: !(status in ['inactive', 'deleted'])
    end

    test "NOT CONTAINS operator" do
      # NOT CONTAINS is already implemented
      assert {:ok, predicates} = Query.new("tags not contains 'deprecated'")
      assert [%{condition: %{comparison_operator: "not contains"}}] = predicates
      
      # Test actual behavior
      assert Predicated.test("tags not contains 'deprecated'", %{tags: ["active", "new"]})
      refute Predicated.test("tags not contains 'deprecated'", %{tags: ["deprecated", "old"]})
    end

    test "LIKE operator for pattern matching" do
      # Test current behavior - likely returns error
      assert {:error, _} = Query.new("email like '%@example.com'")
      assert {:error, _} = Query.new("name like 'John%'")
      assert {:error, _} = Query.new("code like 'PRD_%_2023'")
      
      # Document desired behavior
      # % should match any sequence of characters
      # _ should match exactly one character
    end

    test "ILIKE operator for case-insensitive pattern matching" do
      # Test current behavior - likely returns error
      assert {:error, _} = Query.new("email ilike '%@EXAMPLE.COM'")
      assert {:error, _} = Query.new("name ilike 'john%'")
      
      # Document desired behavior
      # Should work like LIKE but case-insensitive
    end

    test "STARTS_WITH operator" do
      # Test current behavior - likely returns error
      assert {:error, _} = Query.new("email starts_with 'admin@'")
      assert {:error, _} = Query.new("code starts_with 'PRD'")
      
      # Alternative syntax possibilities
      assert {:error, _} = Query.new("email startswith 'admin@'")
      assert {:error, _} = Query.new("email ^= 'admin@'")
    end

    test "ENDS_WITH operator" do
      # Test current behavior - likely returns error
      assert {:error, _} = Query.new("email ends_with '@example.com'")
      assert {:error, _} = Query.new("filename ends_with '.pdf'")
      
      # Alternative syntax possibilities
      assert {:error, _} = Query.new("email endswith '@example.com'")
      assert {:error, _} = Query.new("email $= '@example.com'")
    end

    test "REGEX/MATCHES operator" do
      # Test current behavior - likely returns error
      assert {:error, _} = Query.new("email ~ '^[a-z]+@[a-z]+\\.[a-z]+$'")
      assert {:error, _} = Query.new("phone matches '^\\d{3}-\\d{3}-\\d{4}$'")
      assert {:error, _} = Query.new("code =~ '^[A-Z]{3}\\d{3}$'")
      
      # Document desired behavior
      # Should support standard regex patterns
    end

    test "IS_NULL/IS_NOT_NULL operators" do
      # Test current behavior - currently must use == nil
      assert Predicated.test("value == nil", %{value: nil})
      assert Predicated.test("value != nil", %{value: "test"})
      
      # Test if IS_NULL syntax works - likely returns error
      assert {:error, _} = Query.new("value is null")
      assert {:error, _} = Query.new("value is not null")
      assert {:error, _} = Query.new("value is_null")
      assert {:error, _} = Query.new("value is_not_null")
    end

    test "BETWEEN operator for ranges" do
      # Test current behavior - likely returns error
      assert {:error, _} = Query.new("age between 18 and 65")
      assert {:error, _} = Query.new("price between 10.0 and 99.99")
      assert {:error, _} = Query.new("date between '2023-01-01'::DATE and '2023-12-31'::DATE")
      
      # Currently must use composite conditions
      assert Predicated.test("age >= 18 AND age <= 65", %{age: 25})
    end

    test "EXISTS operator for checking field presence" do
      # Test current behavior - likely returns error
      assert {:error, _} = Query.new("optional_field exists")
      assert {:error, _} = Query.new("user.profile exists")
      
      # Alternative syntax possibilities
      assert {:error, _} = Query.new("has(optional_field)")
      assert {:error, _} = Query.new("exists(user.profile)")
    end

    test "LENGTH/SIZE operators" do
      # Test current behavior - likely returns error
      assert {:error, _} = Query.new("length(name) > 3")
      assert {:error, _} = Query.new("size(tags) >= 2")
      assert {:error, _} = Query.new("name.length > 3")
      assert {:error, _} = Query.new("tags.size >= 2")
      
      # Document desired behavior
      # Should work on strings (character count) and lists (element count)
    end

    test "EMPTY/NOT_EMPTY operators" do
      # Test current behavior - likely returns error
      assert {:error, _} = Query.new("tags is empty")
      assert {:error, _} = Query.new("tags is not empty")
      assert {:error, _} = Query.new("name is_empty")
      assert {:error, _} = Query.new("name is_not_empty")
      
      # Currently must check against empty string or empty list
      assert Predicated.test("name == ''", %{name: ""})
      assert Predicated.test("name != ''", %{name: "John"})
    end
  end

  describe "operator combinations that should work" do
    test "NOT operator with grouping" do
      # Test current behavior - likely returns error
      assert {:error, _} = Query.new("NOT (status == 'active' OR status == 'pending')")
      assert {:error, _} = Query.new("!(role == 'admin' AND department == 'IT')")
      
      # Currently must use De Morgan's laws manually
      assert Predicated.test(
        "status != 'active' AND status != 'pending'",
        %{status: "inactive"}
      )
    end

    test "CASE-insensitive equality" do
      # Test current behavior - likely returns error
      assert {:error, _} = Query.new("name ==i 'john'")
      assert {:error, _} = Query.new("name ~= 'JOHN'")
      assert {:error, _} = Query.new("lower(name) == 'john'")
      assert {:error, _} = Query.new("upper(name) == 'JOHN'")
      
      # Currently case-sensitive only
      refute Predicated.test("name == 'john'", %{name: "John"})
    end

    test "ANY/ALL with lists" do
      # Test current behavior - likely returns error
      assert {:error, _} = Query.new("any(tags) == 'important'")
      assert {:error, _} = Query.new("all(scores) > 70")
      assert {:error, _} = Query.new("tags any == 'important'")
      assert {:error, _} = Query.new("scores all > 70")
      
      # Currently must use contains for ANY behavior
      assert Predicated.test("tags contains 'important'", %{tags: ["urgent", "important"]})
    end
  end

  describe "type casting operators" do
    test "string to number casting" do
      # Test current behavior - likely no auto-casting
      refute Predicated.test("value > 10", %{value: "20"})
      
      # Test if casting syntax works - likely returns error
      assert {:error, _} = Query.new("value::INT > 10")
      assert {:error, _} = Query.new("value::FLOAT > 10.5")
      assert {:error, _} = Query.new("int(value) > 10")
      assert {:error, _} = Query.new("float(value) > 10.5")
    end

    test "string to boolean casting" do
      # Test current behavior - likely no auto-casting
      refute Predicated.test("active == true", %{active: "true"})
      
      # Test if casting syntax works - likely returns error
      assert {:error, _} = Query.new("active::BOOL == true")
      assert {:error, _} = Query.new("bool(active) == true")
    end
  end

  describe "mathematical operators" do
    test "arithmetic in expressions" do
      # Test current behavior - likely returns error
      assert {:error, _} = Query.new("age + 5 > 25")
      assert {:error, _} = Query.new("price * 1.1 <= 100")
      assert {:error, _} = Query.new("count - 1 >= 0")
      assert {:error, _} = Query.new("total / 2 == 50")
      
      # Currently must pre-calculate values
      assert Predicated.test("age > 20", %{age: 25})
    end

    test "modulo operator" do
      # Test current behavior - likely returns error
      assert {:error, _} = Query.new("value % 2 == 0")
      assert {:error, _} = Query.new("id mod 10 == 5")
    end

    test "power operator" do
      # Test current behavior - likely returns error
      assert {:error, _} = Query.new("value ^ 2 > 100")
      assert {:error, _} = Query.new("value ** 2 > 100")
      assert {:error, _} = Query.new("pow(value, 2) > 100")
    end
  end

  describe "suggested operator aliases" do
    test "alternative logical operators" do
      # Some systems support these
      assert {:error, _} = Query.new("status = 'active'")  # Single =
      assert {:error, _} = Query.new("status eq 'active'") # Named operator
      assert {:error, _} = Query.new("status equals 'active'")

      # Allow lowercase logical operators
      assert {:ok, predicates} = Query.new("a == 1 and b == 2")
      assert Enum.map(predicates, & &1.logical_operator) == [:and, nil]

      assert {:ok, predicates} = Query.new("a == 1 or b == 2")
      assert Enum.map(predicates, & &1.logical_operator) == [:or, nil]
    end

    test "alternative inequality operators" do
      assert {:error, _} = Query.new("status <> 'active'")  # SQL style
      assert {:error, _} = Query.new("status ne 'active'")  # Named operator
      assert {:error, _} = Query.new("status not_equals 'active'")
    end

  end

  describe "complex operator scenarios" do
    test "combining multiple missing operators" do
      # Example of query that would be useful but doesn't work
      assert {:error, _} = Query.new("""
        email like '%@example.com' AND 
        created_at between '2023-01-01'::DATE and '2023-12-31'::DATE AND
        tags not contains 'archived' AND
        description is not null
      """)
      
      # Currently would need complex workaround
      {:ok, _predicates} = Query.new("""
        created_at >= '2023-01-01'::DATE AND 
        created_at <= '2023-12-31'::DATE
      """)
      
      # And would need to handle other conditions in application code
    end
  end
end