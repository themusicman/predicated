defmodule Predicated.Query.ParserEdgeCasesTest do
  use ExUnit.Case, async: true
  alias Predicated.Query

  describe "malformed queries" do
    test "returns error for unclosed parentheses" do
      assert {:error, _} = Query.new("(user_id == '123'")
      assert {:error, _} = Query.new("user_id == '123')")
      assert {:error, _} = Query.new("((user_id == '123')")
    end

    test "returns error for mismatched parentheses" do
      assert {:error, _} = Query.new("(user_id == '123'))")
      assert {:error, _} = Query.new("((user_id == '123')")
    end

    test "returns error for invalid operators" do
      assert {:error, _} = Query.new("user_id === '123'")
      assert {:error, _} = Query.new("user_id <> '123'")
      assert {:error, _} = Query.new("user_id ~ '123'")
    end

    test "returns error for missing operands" do
      assert {:error, _} = Query.new("user_id ==")
      assert {:error, _} = Query.new("== '123'")
      assert {:error, _} = Query.new("user_id")
    end

    test "returns error for consecutive operators" do
      assert {:error, _} = Query.new("user_id == == '123'")
      assert {:error, _} = Query.new("user_id > < 5")
    end

    test "returns error for invalid logical operators" do
      assert {:error, _} = Query.new("user_id == '123' && profile_id == '456'")
      assert {:error, _} = Query.new("user_id == '123' || profile_id == '456'")
      assert {:error, _} = Query.new("user_id == '123' XOR profile_id == '456'")
    end
  end

  describe "special characters in strings" do
    test "handles strings with escaped quotes" do
      # Single quotes within single-quoted strings need escaping
      assert {:error, _} = Query.new("name == 'John's'")
      
      # Test with properly escaped quotes if supported
      # This might need adjustment based on the parser's escaping rules
    end

    test "handles strings with backslashes" do
      {:ok, predicates} = Query.new("path == 'C:\\\\Users\\\\John'")
      assert [%{condition: %{expression: "C:\\Users\\John"}}] = predicates
    end

    test "handles strings with newlines and tabs" do
      {:ok, predicates} = Query.new("description == 'Line 1\\nLine 2'")
      assert [%{condition: %{expression: "Line 1\\nLine 2"}}] = predicates
      
      {:ok, predicates} = Query.new("description == 'Column1\\tColumn2'")
      assert [%{condition: %{expression: "Column1\\tColumn2"}}] = predicates
    end

    test "handles empty strings" do
      {:ok, predicates} = Query.new("name == ''")
      assert [%{condition: %{identifier: "name", expression: ""}}] = predicates
    end

    test "handles strings with special characters" do
      {:ok, predicates} = Query.new("email == 'user+tag@example.com'")
      assert [%{condition: %{expression: "user+tag@example.com"}}] = predicates

      {:ok, predicates} = Query.new("regex == '^[a-z]+$'")
      assert [%{condition: %{expression: "^[a-z]+$"}}] = predicates
    end
  end

  describe "unicode support" do
    test "handles unicode in strings" do
      {:ok, predicates} = Query.new("name == '你好世界'")
      assert [%{condition: %{expression: "你好世界"}}] = predicates

      {:ok, predicates} = Query.new("emoji == '😀🎉'")
      assert [%{condition: %{expression: "😀🎉"}}] = predicates
    end

    test "handles unicode in identifiers" do
      # Most parsers don't support unicode in identifiers, but test the behavior
      assert {:error, _} = Query.new("用户名 == 'test'")
    end
  end

  describe "whitespace handling" do
    test "handles queries with only whitespace" do
      assert {:error, _} = Query.new("")
      assert {:error, _} = Query.new("   ")
      assert {:error, _} = Query.new("\t\n")
    end

    test "handles excessive whitespace" do
      {:ok, predicates} = Query.new("  user_id    ==    '123'   ")
      assert [%{condition: %{identifier: "user_id", expression: "123"}}] = predicates
    end

    test "handles newlines in queries" do
      query = """
      user_id == '123'
      AND
      profile_id == '456'
      """
      {:ok, predicates} = Query.new(query)
      assert length(predicates) == 2
    end

    test "handles tabs in queries" do
      {:ok, predicates} = Query.new("user_id\t==\t'123'")
      assert [%{condition: %{identifier: "user_id", expression: "123"}}] = predicates
    end
  end

  describe "operator spacing" do
    test "handles operators without spaces" do
      {:ok, predicates} = Query.new("age>18")
      assert [%{condition: %{comparison_operator: ">"}}] = predicates

      {:ok, predicates} = Query.new("age>=18")
      assert [%{condition: %{comparison_operator: ">="}}] = predicates

      {:ok, predicates} = Query.new("age<=65")
      assert [%{condition: %{comparison_operator: "<="}}] = predicates

      {:ok, predicates} = Query.new("status!='inactive'")
      assert [%{condition: %{comparison_operator: "!="}}] = predicates
    end

    test "handles logical operators without spaces" do
      # Parser allows logical operators without spaces after numbers
      # since numbers can't be part of identifiers
      assert {:ok, predicates} = Query.new("a==1andb==2")
      assert length(predicates) == 2
      
      assert {:ok, predicates} = Query.new("a==1orb==2")
      assert length(predicates) == 2
    end
  end

  describe "case sensitivity" do
    test "handles logical operators in different cases" do
      {:ok, predicates} = Query.new("a == 1 AND b == 2")
      assert length(predicates) == 2

      {:ok, predicates} = Query.new("a == 1 and b == 2")
      assert length(predicates) == 2

      {:ok, predicates} = Query.new("a == 1 And b == 2")
      assert length(predicates) == 2

      {:ok, predicates} = Query.new("a == 1 OR b == 2")
      assert length(predicates) == 2

      {:ok, predicates} = Query.new("a == 1 or b == 2")
      assert length(predicates) == 2

      {:ok, predicates} = Query.new("a == 1 Or b == 2")
      assert length(predicates) == 2
    end

    test "handles boolean values in different cases" do
      {:ok, predicates} = Query.new("active == true")
      assert [%{condition: %{expression: true}}] = predicates

      {:ok, predicates} = Query.new("active == TRUE")
      assert [%{condition: %{expression: true}}] = predicates

      {:ok, predicates} = Query.new("active == True")
      assert [%{condition: %{expression: true}}] = predicates

      {:ok, predicates} = Query.new("active == false")
      assert [%{condition: %{expression: false}}] = predicates

      {:ok, predicates} = Query.new("active == FALSE")
      assert [%{condition: %{expression: false}}] = predicates

      {:ok, predicates} = Query.new("active == False")
      assert [%{condition: %{expression: false}}] = predicates
    end

    test "handles IN operator in different cases" do
      {:ok, predicates} = Query.new("status in ['active', 'pending']")
      assert [%{condition: %{comparison_operator: "in"}}] = predicates

      {:ok, predicates} = Query.new("status IN ['active', 'pending']")
      assert [%{condition: %{comparison_operator: "in"}}] = predicates

      {:ok, predicates} = Query.new("status In ['active', 'pending']")
      assert [%{condition: %{comparison_operator: "in"}}] = predicates
    end
  end

  describe "boundary conditions" do
    test "handles very long identifiers" do
      long_identifier = String.duplicate("a", 1000)
      {:ok, predicates} = Query.new("#{long_identifier} == 'test'")
      assert [%{condition: %{identifier: ^long_identifier}}] = predicates
    end

    test "handles very long strings" do
      long_string = String.duplicate("x", 10000)
      {:ok, predicates} = Query.new("data == '#{long_string}'")
      assert [%{condition: %{expression: ^long_string}}] = predicates
    end

    test "handles deeply nested dot notation" do
      deep_path = Enum.join(1..50 |> Enum.map(&"level#{&1}"), ".")
      {:ok, predicates} = Query.new("#{deep_path} == 'value'")
      assert [%{condition: %{identifier: ^deep_path}}] = predicates
    end
  end

  describe "numeric edge cases" do
    test "handles various numeric formats" do
      # Scientific notation
      {:ok, predicates} = Query.new("value == 1.23e10")
      assert [%{condition: %{expression: 1.23e10}}] = predicates

      {:ok, predicates} = Query.new("value == 1.23E-5")
      assert [%{condition: %{expression: 1.23e-5}}] = predicates

      # Leading zeros
      {:ok, predicates} = Query.new("value == 007")
      assert [%{condition: %{expression: 7}}] = predicates

      # Decimal without leading digit
      {:ok, predicates} = Query.new("value == .5")
      assert [%{condition: %{expression: 0.5}}] = predicates

      # Negative zero
      {:ok, predicates} = Query.new("value == -0")
      assert [%{condition: %{expression: 0}}] = predicates

      {:ok, predicates} = Query.new("value == -0.0")
      assert [%{condition: %{expression: value}}] = predicates
      assert value == 0.0
    end

    test "handles extreme numeric values" do
      # Very large integers
      {:ok, predicates} = Query.new("value == 999999999999999999999")
      assert [%{condition: %{expression: 999999999999999999999}}] = predicates

      # Very small floats
      {:ok, predicates} = Query.new("value == 0.000000000001")
      assert [%{condition: %{expression: 0.000000000001}}] = predicates
    end
  end

  describe "operator precedence edge cases" do
    test "handles complex precedence without parentheses" do
      # AND has higher precedence than OR
      {:ok, predicates} = Query.new("a == 1 OR b == 2 AND c == 3")
      # Should parse as: a == 1 OR (b == 2 AND c == 3)
      assert length(predicates) == 3
    end

    test "handles multiple consecutive ANDs and ORs" do
      {:ok, predicates} = Query.new("a == 1 AND b == 2 AND c == 3 OR d == 4 OR e == 5")
      assert length(predicates) == 5
    end
  end
end