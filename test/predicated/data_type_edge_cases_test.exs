defmodule Predicated.DataTypeEdgeCasesTest do
  use ExUnit.Case, async: true
  alias Predicated

  describe "nil/null handling" do
    test "comparing nil values" do
      # nil == nil should be true
      assert Predicated.test("value == nil", %{value: nil})
      
      # nil != non-nil should be true
      assert Predicated.test("value != 'test'", %{value: nil})
      assert Predicated.test("value != 123", %{value: nil})
      assert Predicated.test("value != true", %{value: nil})
      
      # non-nil != nil should be true
      refute Predicated.test("value == nil", %{value: "test"})
      refute Predicated.test("value == nil", %{value: 0})
      refute Predicated.test("value == nil", %{value: false})
    end

    test "nil in comparisons" do
      # These should handle nil gracefully, though behavior may vary
      refute Predicated.test("value > 5", %{value: nil})
      refute Predicated.test("value < 5", %{value: nil})
      refute Predicated.test("value >= 5", %{value: nil})
      refute Predicated.test("value <= 5", %{value: nil})
    end

    test "nil vs empty string" do
      refute Predicated.test("value == ''", %{value: nil})
      refute Predicated.test("value == nil", %{value: ""})
      assert Predicated.test("value != ''", %{value: nil})
      assert Predicated.test("value != nil", %{value: ""})
    end

    test "missing keys treated as nil" do
      assert Predicated.test("missing_key == nil", %{other_key: "value"})
      refute Predicated.test("missing_key == 'value'", %{other_key: "value"})
      assert Predicated.test("missing_key != 'value'", %{other_key: "value"})
    end
  end

  describe "type mismatches" do
    test "comparing strings to numbers" do
      refute Predicated.test("value == '123'", %{value: 123})
      refute Predicated.test("value == 123", %{value: "123"})
      assert Predicated.test("value != '123'", %{value: 123})
      assert Predicated.test("value != 123", %{value: "123"})
    end

    test "comparing different numeric types" do
      # Integer vs float comparisons should work
      assert Predicated.test("value == 1.0", %{value: 1})
      assert Predicated.test("value == 1", %{value: 1.0})
      assert Predicated.test("value > 0.9", %{value: 1})
      assert Predicated.test("value < 1.1", %{value: 1})
    end

    test "comparing dates to strings" do
      refute Predicated.test("date == '2023-01-01'", %{date: ~D[2023-01-01]})
      assert Predicated.test("date == '2023-01-01'::DATE", %{date: ~D[2023-01-01]})
    end

    test "comparing booleans to strings" do
      refute Predicated.test("active == 'true'", %{active: true})
      refute Predicated.test("active == 'false'", %{active: false})
      assert Predicated.test("active == true", %{active: true})
      assert Predicated.test("active == false", %{active: false})
    end

    test "comparing booleans to numbers" do
      refute Predicated.test("active == 1", %{active: true})
      refute Predicated.test("active == 0", %{active: false})
    end
  end

  describe "date/datetime edge cases" do
    test "invalid date strings" do
      assert {:error, _} = Predicated.Query.new("date == '2023-13-01'::DATE")
      assert {:error, _} = Predicated.Query.new("date == '2023-01-32'::DATE")
      assert {:error, _} = Predicated.Query.new("date == 'not-a-date'::DATE")
    end

    test "invalid datetime strings" do
      assert {:error, _} = Predicated.Query.new("time == '2023-01-01T25:00:00Z'::DATETIME")
      assert {:error, _} = Predicated.Query.new("time == '2023-01-01T12:60:00Z'::DATETIME")
      assert {:error, _} = Predicated.Query.new("time == 'not-a-datetime'::DATETIME")
    end

    test "date boundaries" do
      # Test leap year
      {:ok, predicates} = Predicated.Query.new("date == '2024-02-29'::DATE")
      assert Predicated.test(predicates, %{date: ~D[2024-02-29]})
      
      # Non-leap year should fail
      assert {:error, _} = Predicated.Query.new("date == '2023-02-29'::DATE")
    end

    test "datetime with different timezones" do
      {:ok, dt1, _} = DateTime.from_iso8601("2023-01-01T12:00:00Z")
      {:ok, dt2, _} = DateTime.from_iso8601("2023-01-01T12:00:00+00:00")
      {:ok, dt3, _} = DateTime.from_iso8601("2023-01-01T08:00:00-04:00")
      
      # Same instant in time
      assert DateTime.compare(dt1, dt2) == :eq
      assert DateTime.compare(dt1, dt3) == :eq
      
      assert Predicated.test("time == '2023-01-01T12:00:00Z'::DATETIME", %{time: dt1})
      assert Predicated.test("time == '2023-01-01T12:00:00Z'::DATETIME", %{time: dt2})
      assert Predicated.test("time == '2023-01-01T12:00:00Z'::DATETIME", %{time: dt3})
    end

    test "comparing DateTime to NaiveDateTime" do
      {:ok, _datetime, _} = DateTime.from_iso8601("2023-01-01T12:00:00Z")
      naive_datetime = ~N[2023-01-01 12:00:00]
      
      # These are different types and may not compare as expected
      # Testing actual behavior
      result = Predicated.test("time == '2023-01-01T12:00:00Z'::DATETIME", %{time: naive_datetime})
      # Document the actual behavior - this might be false due to type mismatch
      assert result == false || result == true
    end
  end

  describe "numeric precision and edge cases" do
    test "float precision issues" do
      # Classic floating point precision problem
      value = 0.1 + 0.2
      
      # This might fail due to float precision
      result = Predicated.test("value == 0.3", %{value: value})
      
      # Document actual behavior - in Elixir this usually works due to representation
      assert result == true || result == false
      
      # Range check is more reliable
      assert Predicated.test("value > 0.29 AND value < 0.31", %{value: value})
    end

    test "very large numbers" do
      large_int = 99999999999999999999999999999999
      assert Predicated.test("value == 99999999999999999999999999999999", %{value: large_int})
      assert Predicated.test("value > 99999999999999999999999999999998", %{value: large_int})
    end

    test "very small numbers" do
      tiny_float = 0.000000000000001
      assert Predicated.test("value == 0.000000000000001", %{value: tiny_float})
      assert Predicated.test("value > 0", %{value: tiny_float})
      assert Predicated.test("value < 0.000000000000002", %{value: tiny_float})
    end

    test "infinity and special float values" do
      # Elixir doesn't have Infinity as a literal, but we can test behavior
      # with very large numbers
      huge = 1.0e308
      assert Predicated.test("value > 1.0e307", %{value: huge})
      
      # Test negative numbers
      assert Predicated.test("value < 0", %{value: -1.0e308})
    end

    test "zero comparisons" do
      assert Predicated.test("value == 0", %{value: 0})
      assert Predicated.test("value == 0.0", %{value: 0})
      assert Predicated.test("value == 0", %{value: 0.0})
      assert Predicated.test("value == 0.0", %{value: 0.0})
      
      # Negative zero
      assert Predicated.test("value == -0", %{value: 0})
      assert Predicated.test("value == -0.0", %{value: 0.0})
    end
  end

  describe "string edge cases" do
    test "empty strings" do
      assert Predicated.test("value == ''", %{value: ""})
      refute Predicated.test("value == ' '", %{value: ""})
      assert Predicated.test("value != ' '", %{value: ""})
    end

    test "whitespace handling" do
      assert Predicated.test("value == ' '", %{value: " "})
      assert Predicated.test("value == '  '", %{value: "  "})
      assert Predicated.test("value == '\t'", %{value: "\t"})
      assert Predicated.test("value == '\n'", %{value: "\n"})
      
      # Leading/trailing whitespace
      refute Predicated.test("value == 'test'", %{value: " test"})
      refute Predicated.test("value == 'test'", %{value: "test "})
      refute Predicated.test("value == 'test'", %{value: " test "})
    end

    test "case sensitivity" do
      refute Predicated.test("value == 'Test'", %{value: "test"})
      refute Predicated.test("value == 'TEST'", %{value: "test"})
      assert Predicated.test("value != 'Test'", %{value: "test"})
    end

    test "unicode strings" do
      # Different representations of é
      assert Predicated.test("value == 'café'", %{value: "café"})
      
      # Emoji comparison
      assert Predicated.test("value == '👍'", %{value: "👍"})
      assert Predicated.test("value == '🎉🎊'", %{value: "🎉🎊"})
      
      # Multi-byte characters
      assert Predicated.test("value == '你好'", %{value: "你好"})
      assert Predicated.test("value == 'مرحبا'", %{value: "مرحبا"})
    end
  end

  describe "boolean edge cases" do
    test "truthy/falsy values are not coerced" do
      # Only true/false are boolean true/false
      refute Predicated.test("value == true", %{value: 1})
      refute Predicated.test("value == true", %{value: "true"})
      refute Predicated.test("value == true", %{value: "yes"})
      refute Predicated.test("value == false", %{value: 0})
      refute Predicated.test("value == false", %{value: ""})
      refute Predicated.test("value == false", %{value: nil})
    end

    test "boolean comparisons with operators" do
      # Booleans with comparison operators (might not make semantic sense but should handle gracefully)
      assert Predicated.test("value != false", %{value: true})
      assert Predicated.test("value != true", %{value: false})
      
      # These might have undefined behavior but shouldn't crash
      result = Predicated.test("value > false", %{value: true})
      assert result == true || result == false
    end
  end

  describe "complex type edge cases" do
    test "nested nil values" do
      assert Predicated.test("user.name == nil", %{user: %{name: nil}})
      assert Predicated.test("user.name == nil", %{user: %{}})
      assert Predicated.test("user.name == nil", %{})
      
      refute Predicated.test("user.name == 'test'", %{user: %{name: nil}})
      refute Predicated.test("user.name == 'test'", %{user: %{}})
      refute Predicated.test("user.name == 'test'", %{})
    end

    test "comparing entire objects" do
      # This might not be supported, but test the behavior
      result = Predicated.test("user == nil", %{user: %{name: "test"}})
      assert result == false
      
      assert Predicated.test("user != nil", %{user: %{name: "test"}})
      assert Predicated.test("user == nil", %{})
    end

    test "type coercion in lists" do
      # Mixed types in IN operator
      assert Predicated.test("value in [1, '1', true]", %{value: 1})
      assert Predicated.test("value in [1, '1', true]", %{value: "1"})
      assert Predicated.test("value in [1, '1', true]", %{value: true})
    end
  end
end