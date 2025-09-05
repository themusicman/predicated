defmodule Predicated.Query.NestedGroupingTest do
  use ExUnit.Case, async: true
  alias Predicated.Query
  alias Predicated.Predicate
  alias Predicated.Condition

  describe "deep nesting" do
    test "handles 3 levels of nested parentheses" do
      {:ok, predicates} = Query.new("a == 1 AND (b == 2 OR (c == 3 AND (d == 4 OR e == 5)))")
      
      # Verify the structure is correctly nested
      assert [
        %Predicate{
          condition: %Condition{identifier: "a", expression: 1},
          logical_operator: :and
        },
        %Predicate{
          condition: nil,
          predicates: [
            %Predicate{
              condition: %Condition{identifier: "b", expression: 2},
              logical_operator: :or
            },
            %Predicate{
              condition: nil,
              predicates: [
                %Predicate{
                  condition: %Condition{identifier: "c", expression: 3},
                  logical_operator: :and
                },
                %Predicate{
                  condition: nil,
                  predicates: [
                    %Predicate{
                      condition: %Condition{identifier: "d", expression: 4},
                      logical_operator: :or
                    },
                    %Predicate{
                      condition: %Condition{identifier: "e", expression: 5}
                    }
                  ]
                }
              ]
            }
          ]
        }
      ] = predicates
    end

    test "handles 5 levels of nested parentheses" do
      query = "a == 1 OR (b == 2 AND (c == 3 OR (d == 4 AND (e == 5 OR (f == 6)))))"
      {:ok, predicates} = Query.new(query)
      
      # Should successfully parse without error
      assert length(predicates) == 2
      assert Predicated.test(predicates, %{a: 1})
      assert Predicated.test(predicates, %{b: 2, c: 3})
      assert Predicated.test(predicates, %{b: 2, d: 4, e: 5})
      assert Predicated.test(predicates, %{b: 2, d: 4, f: 6})
    end

    test "handles deeply nested groups at the beginning" do
      {:ok, predicates} = Query.new("(((((a == 1))))) AND b == 2")
      assert length(predicates) == 2
      
      assert Predicated.test(predicates, %{a: 1, b: 2})
      refute Predicated.test(predicates, %{a: 1, b: 3})
      refute Predicated.test(predicates, %{a: 2, b: 2})
    end
  end

  describe "empty and single-item groups" do
    test "handles single condition in parentheses" do
      {:ok, predicates1} = Query.new("(a == 1)")
      {:ok, predicates2} = Query.new("a == 1")
      
      # Both should produce equivalent results
      assert Predicated.test(predicates1, %{a: 1})
      assert Predicated.test(predicates2, %{a: 1})
    end

    test "handles redundant nested parentheses" do
      {:ok, predicates} = Query.new("((a == 1)) AND ((b == 2))")
      assert length(predicates) == 2
      assert Predicated.test(predicates, %{a: 1, b: 2})
    end

    test "returns error for empty parentheses" do
      assert {:error, _} = Query.new("()")
      assert {:error, _} = Query.new("a == 1 AND ()")
      assert {:error, _} = Query.new("() OR b == 2")
    end

    test "returns error for nested empty parentheses" do
      assert {:error, _} = Query.new("(())")
      assert {:error, _} = Query.new("a == 1 AND (())")
    end
  end

  describe "mixed precedence without explicit grouping" do
    test "verifies AND has higher precedence than OR" do
      {:ok, predicates} = Query.new("a == 1 OR b == 2 AND c == 3")
      
      # Should evaluate as: a == 1 OR (b == 2 AND c == 3)
      assert Predicated.test(predicates, %{a: 1, b: 0, c: 0})
      assert Predicated.test(predicates, %{a: 0, b: 2, c: 3})
      refute Predicated.test(predicates, %{a: 0, b: 2, c: 0})
    end

    test "handles multiple ANDs and ORs" do
      {:ok, predicates} = Query.new("a == 1 AND b == 2 OR c == 3 AND d == 4")
      
      # Should evaluate as: (a == 1 AND b == 2) OR (c == 3 AND d == 4)
      assert Predicated.test(predicates, %{a: 1, b: 2, c: 0, d: 0})
      assert Predicated.test(predicates, %{a: 0, b: 0, c: 3, d: 4})
      assert Predicated.test(predicates, %{a: 1, b: 0, c: 3, d: 4})
    end

    test "handles chain of ORs" do
      {:ok, predicates} = Query.new("a == 1 OR b == 2 OR c == 3 OR d == 4")
      
      assert Predicated.test(predicates, %{a: 1, b: 0, c: 0, d: 0})
      assert Predicated.test(predicates, %{a: 0, b: 2, c: 0, d: 0})
      assert Predicated.test(predicates, %{a: 0, b: 0, c: 3, d: 0})
      assert Predicated.test(predicates, %{a: 0, b: 0, c: 0, d: 4})
      refute Predicated.test(predicates, %{a: 0, b: 0, c: 0, d: 0})
    end

    test "handles chain of ANDs" do
      {:ok, predicates} = Query.new("a == 1 AND b == 2 AND c == 3 AND d == 4")
      
      assert Predicated.test(predicates, %{a: 1, b: 2, c: 3, d: 4})
      refute Predicated.test(predicates, %{a: 1, b: 2, c: 3, d: 0})
      refute Predicated.test(predicates, %{a: 0, b: 2, c: 3, d: 4})
    end
  end

  describe "complex real-world grouping scenarios" do
    test "handles user permission check pattern" do
      query = "(role == 'admin' OR role == 'moderator') AND (status == 'active' AND verified == true)"
      {:ok, predicates} = Query.new(query)
      
      assert Predicated.test(predicates, %{role: "admin", status: "active", verified: true})
      assert Predicated.test(predicates, %{role: "moderator", status: "active", verified: true})
      refute Predicated.test(predicates, %{role: "user", status: "active", verified: true})
      refute Predicated.test(predicates, %{role: "admin", status: "inactive", verified: true})
      refute Predicated.test(predicates, %{role: "admin", status: "active", verified: false})
    end

    test "handles date range with status check" do
      query = "(created_at >= '2023-01-01'::DATE AND created_at <= '2023-12-31'::DATE) AND (status == 'published' OR (status == 'draft' AND author_id == '123'))"
      {:ok, predicates} = Query.new(query)
      
      assert Predicated.test(predicates, %{
        created_at: ~D[2023-06-15],
        status: "published",
        author_id: "456"
      })
      
      assert Predicated.test(predicates, %{
        created_at: ~D[2023-06-15],
        status: "draft",
        author_id: "123"
      })
      
      refute Predicated.test(predicates, %{
        created_at: ~D[2023-06-15],
        status: "draft",
        author_id: "456"
      })
      
      refute Predicated.test(predicates, %{
        created_at: ~D[2024-01-01],
        status: "published",
        author_id: "123"
      })
    end

    test "handles complex business rule" do
      query = """
      (plan == 'premium' OR plan == 'enterprise') AND 
      (
        (usage < 1000 AND status == 'active') OR 
        (usage >= 1000 AND usage < 5000 AND (status == 'active' OR status == 'warning')) OR
        (usage >= 5000 AND admin_approved == true)
      )
      """
      
      {:ok, predicates} = Query.new(query)
      
      # Premium user under limit
      assert Predicated.test(predicates, %{
        plan: "premium",
        usage: 500,
        status: "active"
      })
      
      # Enterprise user in warning range
      assert Predicated.test(predicates, %{
        plan: "enterprise",
        usage: 3000,
        status: "warning"
      })
      
      # Premium user over hard limit but approved
      assert Predicated.test(predicates, %{
        plan: "premium",
        usage: 10000,
        admin_approved: true
      })
      
      # Basic plan should fail
      refute Predicated.test(predicates, %{
        plan: "basic",
        usage: 100,
        status: "active"
      })
      
      # Over limit without approval should fail
      refute Predicated.test(predicates, %{
        plan: "premium",
        usage: 10000,
        admin_approved: false
      })
    end
  end

  describe "grouping with all operators" do
    test "handles groups with IN operator" do
      query = "(status in ['active', 'pending']) AND (role == 'admin' OR department in ['IT', 'Security'])"
      {:ok, predicates} = Query.new(query)
      
      assert Predicated.test(predicates, %{
        status: "active",
        role: "admin",
        department: "Sales"
      })
      
      assert Predicated.test(predicates, %{
        status: "pending",
        role: "user",
        department: "IT"
      })
      
      refute Predicated.test(predicates, %{
        status: "inactive",
        role: "admin",
        department: "IT"
      })
    end

    test "handles groups with all comparison operators" do
      query = """
      (age >= 18 AND age <= 65) AND 
      (
        (income > 50000 AND credit_score >= 700) OR 
        (income > 100000 AND credit_score >= 600)
      )
      """
      
      {:ok, predicates} = Query.new(query)
      
      assert Predicated.test(predicates, %{
        age: 30,
        income: 60000,
        credit_score: 750
      })
      
      assert Predicated.test(predicates, %{
        age: 45,
        income: 120000,
        credit_score: 650
      })
      
      refute Predicated.test(predicates, %{
        age: 17,
        income: 60000,
        credit_score: 750
      })
      
      refute Predicated.test(predicates, %{
        age: 30,
        income: 40000,
        credit_score: 800
      })
    end
  end

  describe "edge cases in grouping" do
    test "handles groups at the end of expression" do
      {:ok, predicates} = Query.new("a == 1 AND (b == 2 OR c == 3)")
      assert Predicated.test(predicates, %{a: 1, b: 2, c: 0})
      assert Predicated.test(predicates, %{a: 1, b: 0, c: 3})
      refute Predicated.test(predicates, %{a: 0, b: 2, c: 3})
    end

    test "handles groups at the beginning of expression" do
      {:ok, predicates} = Query.new("(a == 1 OR b == 2) AND c == 3")
      assert Predicated.test(predicates, %{a: 1, b: 0, c: 3})
      assert Predicated.test(predicates, %{a: 0, b: 2, c: 3})
      refute Predicated.test(predicates, %{a: 1, b: 2, c: 0})
    end

    test "handles adjacent groups" do
      {:ok, predicates} = Query.new("(a == 1 OR b == 2) AND (c == 3 OR d == 4)")
      assert Predicated.test(predicates, %{a: 1, b: 0, c: 3, d: 0})
      assert Predicated.test(predicates, %{a: 0, b: 2, c: 0, d: 4})
      refute Predicated.test(predicates, %{a: 0, b: 0, c: 3, d: 4})
    end

    test "handles groups with single logical operator" do
      {:ok, predicates} = Query.new("(a == 1) AND b == 2")
      assert Predicated.test(predicates, %{a: 1, b: 2})
      
      {:ok, predicates} = Query.new("a == 1 AND (b == 2)")
      assert Predicated.test(predicates, %{a: 1, b: 2})
    end
  end
end