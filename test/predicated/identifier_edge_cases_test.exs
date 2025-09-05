defmodule Predicated.IdentifierEdgeCasesTest do
  use ExUnit.Case, async: true
  alias Predicated
  alias Predicated.Query

  describe "identifier naming edge cases" do
    test "identifiers with underscores" do
      assert Predicated.test("user_name == 'John'", %{user_name: "John"})
      assert Predicated.test("_private == true", %{_private: true})
      assert Predicated.test("__meta__ == 'data'", %{__meta__: "data"})
    end

    test "identifiers with numbers" do
      assert Predicated.test("field1 == 'value'", %{field1: "value"})
      assert Predicated.test("test123 == true", %{test123: true})
      assert Predicated.test("value_2_test == 42", %{value_2_test: 42})
    end

    test "identifiers starting with numbers" do
      # Most parsers don't allow this
      assert {:error, _} = Query.new("123field == 'value'")
      assert {:error, _} = Query.new("1st == 'first'")
    end

    test "reserved word-like identifiers" do
      # These might work depending on parser implementation
      {:ok, predicates} = Query.new("order == 1")
      assert Predicated.test(predicates, %{order: 1})
      
      {:ok, predicates} = Query.new("and_field == 'test'")
      assert Predicated.test(predicates, %{and_field: "test"})
      
      {:ok, predicates} = Query.new("or_value == true")
      assert Predicated.test(predicates, %{or_value: true})
    end

    test "identifiers with special characters" do
      # Most of these should fail
      assert {:error, _} = Query.new("user-name == 'John'")
      assert {:error, _} = Query.new("user@email == 'test'")
      assert {:error, _} = Query.new("price$ == 100")
      assert {:error, _} = Query.new("value% == 50")
    end

    test "very long identifiers" do
      # Test with extremely long identifier names
      long_name = "very_long_field_name_that_exceeds_normal_length_" <> String.duplicate("x", 200)
      query = "#{long_name} == 'test'"
      
      {:ok, predicates} = Query.new(query)
      # Use atom key since identifiers are converted to atoms
      long_atom = String.to_atom(long_name)
      assert Predicated.test(predicates, %{long_atom => "test"})
    end
  end

  describe "dot notation edge cases" do
    test "single dot" do
      assert {:error, _} = Query.new(". == 'value'")
      assert {:error, _} = Query.new("a. == 'value'")
      assert {:error, _} = Query.new(".b == 'value'")
    end

    test "multiple consecutive dots" do
      assert {:error, _} = Query.new("a..b == 'value'")
      assert {:error, _} = Query.new("a...b == 'value'")
      assert {:error, _} = Query.new("a.b..c == 'value'")
    end

    test "deeply nested paths" do
      # Normal deep nesting
      deep_data = %{
        level1: %{
          level2: %{
            level3: %{
              level4: %{
                level5: "deep_value"
              }
            }
          }
        }
      }
      
      assert Predicated.test(
        "level1.level2.level3.level4.level5 == 'deep_value'",
        deep_data
      )
      
      # Very deep nesting
      path_parts = Enum.map(1..20, &"level#{&1}")
      path = Enum.join(path_parts, ".")
      query = "#{path} == 'value'"
      
      {:ok, predicates} = Query.new(query)
      # This will return nil for the missing path, which won't equal 'value'
      refute Predicated.test(predicates, %{})
    end

    test "numeric keys in paths" do
      # Keys that include numbers (but start with valid identifier characters)
      assert Predicated.test("data.item123 == 'value'", %{data: %{item123: "value"}})
      assert Predicated.test("data._123 == 'test'", %{data: %{_123: "test"}})
      
      # Atom keys that include numbers
      assert Predicated.test("step1.step2 == 'done'", %{step1: %{step2: "done"}})
      
      # Pure numeric keys are not valid identifiers
      assert {:error, _} = Query.new("data.123 == 'value'")
    end

    test "paths with underscores and mixed case" do
      data = %{
        user_profile: %{
          first_name: "John",
          LAST_NAME: "Doe",
          _internal_id: 123
        }
      }
      
      assert Predicated.test("user_profile.first_name == 'John'", data)
      assert Predicated.test("user_profile.LAST_NAME == 'Doe'", data)
      assert Predicated.test("user_profile._internal_id == 123", data)
    end
  end

  describe "non-existent path handling" do
    test "missing top-level keys" do
      assert Predicated.test("missing == nil", %{other: "value"})
      refute Predicated.test("missing == 'value'", %{other: "value"})
      assert Predicated.test("missing != 'value'", %{other: "value"})
    end

    test "missing nested keys" do
      data = %{user: %{name: "John"}}
      
      assert Predicated.test("user.age == nil", data)
      refute Predicated.test("user.age == 25", data)
      assert Predicated.test("user.age != 25", data)
    end

    test "partially missing paths" do
      # Path exists partially
      assert Predicated.test("user.profile.settings == nil", %{user: %{profile: %{}}})
      assert Predicated.test("user.profile.settings == nil", %{user: %{}})
      assert Predicated.test("user.profile.settings == nil", %{})
    end

    test "nil values vs missing keys" do
      # Explicit nil
      assert Predicated.test("value == nil", %{value: nil})
      
      # Missing key (implicitly nil)
      assert Predicated.test("missing == nil", %{})
      
      # Both should behave the same in comparisons
      assert Predicated.test("value != 'test'", %{value: nil})
      assert Predicated.test("missing != 'test'", %{})
    end
  end

  describe "path resolution with different data structures" do
    test "maps with string keys" do
      data = %{"user" => %{"name" => "John"}}
      
      # Should not work with atom-based paths by default
      refute Predicated.test("user.name == 'John'", data)
      
      # Would need string-based path resolution
      # This depends on implementation
    end

    test "mixed key types" do
      # Mix of atom and string keys
      data = %{
        :user => %{
          "name" => "John",
          age: 25
        }
      }
      
      # Atom path should work for atom keys
      assert Predicated.test("user.age == 25", data)
      
      # But not for string keys within
      refute Predicated.test("user.name == 'John'", data)
    end

    test "lists in paths" do
      # Accessing list elements by index (if supported)
      data = %{items: ["first", "second", "third"]}
      
      # This probably won't work with current implementation
      result = Predicated.test("items.0 == 'first'", data)
      assert result == false
      
      # Lists are typically accessed with contains/in operators
      assert Predicated.test("items contains 'first'", data)
    end

    test "maps with struct-like structure in paths" do
      # Maps with __struct__ key (but not actual structs)
      user = %{
        __struct__: "UserStruct",
        id: 123,
        profile: %{
          __struct__: "ProfileStruct",
          name: "John",
          age: 25
        }
      }
      
      assert Predicated.test("id == 123", user)
      assert Predicated.test("profile.name == 'John'", user)
      assert Predicated.test("profile.age == 25", user)
      
      # Can also access the __struct__ field
      assert Predicated.test("__struct__ == 'UserStruct'", user)
      assert Predicated.test("profile.__struct__ == 'ProfileStruct'", user)
    end

    test "keyword lists" do
      # Keyword lists work with get_in/2 just like maps
      data = [user: [name: "John", age: 25]]
      
      # This works because get_in/2 supports keyword lists
      assert Predicated.test("user.name == 'John'", data)
      assert Predicated.test("user.age == 25", data)
    end
  end

  describe "special path access patterns" do
    test "accessing map keys that conflict with atom names" do
      # Keys that might cause issues
      data = %{
        nil: "not nil",
        true: "not true",
        false: "not false",
        and: "operator",
        or: "operator"
      }
      
      assert Predicated.test("nil == 'not nil'", data)
      assert Predicated.test("true == 'not true'", data)
      assert Predicated.test("false == 'not false'", data)
      assert Predicated.test("and == 'operator'", data)
      assert Predicated.test("or == 'operator'", data)
    end

    test "paths through nil values" do
      # When intermediate value is nil
      data = %{user: nil}
      
      # Accessing through nil should return nil
      assert Predicated.test("user.name == nil", data)
      assert Predicated.test("user.profile.settings == nil", data)
    end

    test "circular reference handling" do
      # Note: Actually creating circular refs in Elixir is non-trivial
      # This tests the concept
      data = %{a: %{b: %{c: "value"}}}
      
      # Normal access should work
      assert Predicated.test("a.b.c == 'value'", data)
    end

    test "computed property names" do
      # Properties that might be computed or dynamic
      data = %{
        "user:123" => %{name: "John"},
        "item[0]" => "first",
        "data{key}" => "value"
      }
      
      # These won't work with dot notation
      # Would need special syntax for dynamic keys
      refute Predicated.test("user:123.name == 'John'", data)
    end
  end

  describe "error handling for invalid paths" do
    test "accessing properties on non-map values" do
      # Trying to access nested property on a string
      refute Predicated.test("name.length == 4", %{name: "John"})
      
      # Trying to access nested property on a number
      refute Predicated.test("age.value == 25", %{age: 25})
      
      # Trying to access nested property on a boolean
      refute Predicated.test("active.status == true", %{active: true})
    end

    test "type errors don't crash" do
      # These should all handle gracefully without raising
      assert Predicated.test("value.nested == nil", %{value: "string"})
      assert Predicated.test("value.nested == nil", %{value: 123})
      assert Predicated.test("value.nested == nil", %{value: true})
      assert Predicated.test("value.nested == nil", %{value: []})
    end
  end
end