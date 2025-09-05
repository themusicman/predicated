defmodule Predicated.IntegrationTest do
  use ExUnit.Case, async: true
  alias Predicated

  describe "real-world e-commerce scenarios" do
    test "product filtering with multiple criteria" do
      products = [
        %{
          name: "Premium Laptop",
          price: 1299.99,
          category: "electronics",
          brand: "TechCorp",
          in_stock: true,
          rating: 4.5,
          tags: ["laptop", "premium", "business"],
          specs: %{ram: 16, storage: 512}
        },
        %{
          name: "Budget Laptop",
          price: 499.99,
          category: "electronics",
          brand: "ValueTech",
          in_stock: true,
          rating: 3.8,
          tags: ["laptop", "budget", "student"],
          specs: %{ram: 8, storage: 256}
        },
        %{
          name: "Gaming Laptop",
          price: 1899.99,
          category: "electronics",
          brand: "GameTech",
          in_stock: false,
          rating: 4.7,
          tags: ["laptop", "gaming", "high-performance"],
          specs: %{ram: 32, storage: 1024}
        }
      ]

      # Complex product search query
      query = """
        category == 'electronics' AND
        price >= 400 AND price <= 1500 AND
        in_stock == true AND
        (rating >= 4.0 OR tags contains 'business')
      """

      filtered = Enum.filter(products, &Predicated.test(query, &1))
      assert length(filtered) == 1
      assert hd(filtered).name == "Premium Laptop"
    end

    test "user permission system" do
      users = [
        %{
          id: 1,
          username: "admin_user",
          role: "admin",
          department: "IT",
          status: "active",
          permissions: ["read", "write", "delete", "admin"],
          last_login: ~U[2024-01-15 10:00:00Z],
          account_age_days: 365
        },
        %{
          id: 2,
          username: "regular_user",
          role: "user",
          department: "Sales",
          status: "active",
          permissions: ["read", "write"],
          last_login: ~U[2024-01-20 15:30:00Z],
          account_age_days: 180
        },
        %{
          id: 3,
          username: "new_user",
          role: "user",
          department: "Marketing",
          status: "pending",
          permissions: ["read"],
          last_login: nil,
          account_age_days: 5
        }
      ]

      # Admin or senior users with write permissions
      admin_query = """
        (role == 'admin' OR (role == 'user' AND account_age_days > 90)) AND
        permissions contains 'write' AND
        status == 'active'
      """

      authorized = Enum.filter(users, &Predicated.test(admin_query, &1))
      assert length(authorized) == 2
      assert Enum.all?(authorized, &(&1.status == "active"))
      assert Enum.all?(authorized, &("write" in &1.permissions))
    end

    test "event log filtering" do
      events = [
        %{
          timestamp: ~U[2024-01-15 09:00:00Z],
          level: "error",
          service: "api",
          message: "Connection timeout",
          metadata: %{
            endpoint: "/users",
            status_code: 504,
            duration_ms: 30000,
            user_id: "123"
          }
        },
        %{
          timestamp: ~U[2024-01-15 09:05:00Z],
          level: "warning",
          service: "api",
          message: "Slow query detected",
          metadata: %{
            endpoint: "/products",
            status_code: 200,
            duration_ms: 5000,
            user_id: "456"
          }
        },
        %{
          timestamp: ~U[2024-01-15 09:10:00Z],
          level: "error",
          service: "payment",
          message: "Payment failed",
          metadata: %{
            endpoint: "/checkout",
            status_code: 402,
            duration_ms: 2000,
            user_id: "789"
          }
        }
      ]

      # Find critical issues
      critical_query = """
        (level == 'error' OR 
         (level == 'warning' AND metadata.duration_ms > 4000)) AND
        timestamp >= '2024-01-15T09:00:00Z'::DATETIME
      """

      critical_events = Enum.filter(events, &Predicated.test(critical_query, &1))
      assert length(critical_events) == 3
    end
  end

  describe "complex business rules" do
    test "loan approval system" do
      applications = [
        %{
          applicant: %{
            age: 35,
            income: 75000,
            credit_score: 720,
            employment_months: 36,
            existing_loans: 1
          },
          loan: %{
            amount: 200000,
            term_years: 30,
            purpose: "home"
          }
        },
        %{
          applicant: %{
            age: 25,
            income: 45000,
            credit_score: 650,
            employment_months: 12,
            existing_loans: 2
          },
          loan: %{
            amount: 20000,
            term_years: 5,
            purpose: "auto"
          }
        },
        %{
          applicant: %{
            age: 45,
            income: 120000,
            credit_score: 800,
            employment_months: 120,
            existing_loans: 0
          },
          loan: %{
            amount: 50000,
            term_years: 10,
            purpose: "business"
          }
        }
      ]

      # Complex approval criteria
      approval_query = """
        applicant.age >= 21 AND applicant.age <= 65 AND
        (
          (applicant.credit_score >= 700 AND applicant.income >= 50000) OR
          (applicant.credit_score >= 650 AND applicant.income >= 75000 AND applicant.employment_months >= 24)
        ) AND
        applicant.existing_loans < 3 AND
        (
          (loan.purpose == 'home' AND loan.amount <= 500000) OR
          (loan.purpose == 'auto' AND loan.amount <= 50000) OR
          (loan.purpose == 'business' AND applicant.credit_score >= 750)
        )
      """

      approved = Enum.filter(applications, &Predicated.test(approval_query, &1))
      assert length(approved) == 2
      
      # Verify the business loan was approved due to high credit score
      business_loan = Enum.find(approved, &(&1.loan.purpose == "business"))
      assert business_loan.applicant.credit_score >= 750
    end

    test "subscription tier access control" do
      users = [
        %{
          id: 1,
          plan: "free",
          usage: %{
            api_calls: 950,
            storage_mb: 100,
            team_members: 1
          },
          created_at: ~D[2023-01-01],
          flags: []
        },
        %{
          id: 2,
          plan: "premium",
          usage: %{
            api_calls: 5000,
            storage_mb: 2048,
            team_members: 5
          },
          created_at: ~D[2023-06-01],
          flags: ["beta_features"]
        },
        %{
          id: 3,
          plan: "enterprise",
          usage: %{
            api_calls: 50000,
            storage_mb: 10240,
            team_members: 50
          },
          created_at: ~D[2022-01-01],
          flags: ["beta_features", "priority_support"]
        }
      ]

      # Check who needs upgrades or warnings
      needs_attention_query = """
        (
          (plan == 'free' AND usage.api_calls > 900) OR
          (plan == 'premium' AND (usage.api_calls > 9000 OR usage.storage_mb > 4096)) OR
          (plan in ['free', 'premium'] AND usage.team_members > 10)
        ) OR
        (
          created_at < '2023-01-01'::DATE AND 
          plan != 'enterprise' AND
          flags contains 'beta_features'
        )
      """

      needs_attention = Enum.filter(users, &Predicated.test(needs_attention_query, &1))
      assert length(needs_attention) == 1
      assert hd(needs_attention).id == 1
    end
  end

  describe "data validation scenarios" do
    test "form validation rules" do
      form_submissions = [
        %{
          email: "user@example.com",
          age: 25,
          country: "US",
          newsletter: true,
          interests: ["tech", "science"],
          referral_code: "FRIEND123"
        },
        %{
          email: "invalid-email",
          age: 16,
          country: "UK",
          newsletter: false,
          interests: [],
          referral_code: ""
        },
        %{
          email: "another@test.com",
          age: 30,
          country: "CA",
          newsletter: true,
          interests: ["sports"],
          referral_code: nil
        }
      ]

      # Validation rules
      valid_submission_query = """
        age >= 18 AND
        country in ['US', 'CA', 'UK', 'AU'] AND
        (newsletter == false OR interests != [])
      """

      valid = Enum.filter(form_submissions, &Predicated.test(valid_submission_query, &1))
      assert length(valid) == 2
      assert Enum.all?(valid, &(&1.age >= 18))
    end

    test "inventory management rules" do
      inventory = [
        %{
          sku: "LAPTOP-001",
          quantity: 5,
          location: "warehouse_a",
          last_restock: ~D[2024-01-10],
          category: "electronics",
          value: 6500.00,
          flags: ["high_value", "fragile"]
        },
        %{
          sku: "CABLE-042",
          quantity: 500,
          location: "warehouse_b",
          last_restock: ~D[2023-12-01],
          category: "accessories",
          value: 5.99,
          flags: []
        },
        %{
          sku: "PHONE-789",
          quantity: 0,
          location: "warehouse_a",
          last_restock: ~D[2023-11-15],
          category: "electronics",
          value: 899.99,
          flags: ["discontinued"]
        }
      ]

      # Find items needing attention
      restock_query = """
        (quantity < 10 AND flags contains 'high_value') OR
        (quantity == 0 AND category == 'electronics' AND flags not contains 'discontinued') OR
        (last_restock < '2023-12-15'::DATE AND quantity < 100 AND value > 10 AND flags not contains 'discontinued')
      """

      needs_restock = Enum.filter(inventory, &Predicated.test(restock_query, &1))
      assert length(needs_restock) == 1
      assert hd(needs_restock).sku == "LAPTOP-001"
    end
  end

  describe "performance with large datasets" do
    test "filtering large user list" do
      # Generate 10,000 users
      users = for i <- 1..10_000 do
        %{
          id: i,
          age: :rand.uniform(80) + 10,
          status: Enum.random(["active", "inactive", "pending"]),
          score: :rand.uniform(100),
          tags: Enum.take_random(["vip", "new", "verified", "premium"], :rand.uniform(3))
        }
      end

      query = """
        status == 'active' AND
        age >= 25 AND age <= 45 AND
        score > 70 AND
        (tags contains 'vip' OR tags contains 'premium')
      """

      # Should complete reasonably fast
      {time, results} = :timer.tc(fn ->
        Enum.filter(users, &Predicated.test(query, &1))
      end)

      # Should complete in under 500ms for 10k items
      assert time < 500_000
      assert length(results) > 0
    end
  end

  describe "error handling and edge cases" do
    test "graceful handling of missing fields" do
      incomplete_data = %{
        name: "John",
        # age is missing
        # status is missing
      }

      # Should handle missing fields as nil
      assert Predicated.test("age == nil", incomplete_data)
      assert Predicated.test("status == nil", incomplete_data)
      assert Predicated.test("name != nil", incomplete_data)
      
      # Comparisons with missing fields
      refute Predicated.test("age > 18", incomplete_data)
      refute Predicated.test("status == 'active'", incomplete_data)
    end

    test "deeply nested queries with mixed conditions" do
      complex_data = %{
        user: %{
          profile: %{
            personal: %{
              age: 30,
              location: %{
                country: "US",
                state: "CA",
                city: "San Francisco"
              }
            },
            professional: %{
              title: "Senior Engineer",
              years_experience: 8,
              skills: ["elixir", "ruby", "javascript"]
            }
          },
          account: %{
            type: "premium",
            created_at: ~D[2020-01-01],
            features: ["api_access", "priority_support"]
          }
        }
      }

      complex_query = """
        user.profile.personal.age >= 25 AND
        user.profile.personal.location.country == 'US' AND
        user.profile.professional.years_experience > 5 AND
        user.profile.professional.skills contains 'elixir' AND
        user.account.type in ['premium', 'enterprise'] AND
        user.account.features contains 'api_access'
      """

      assert Predicated.test(complex_query, complex_data)
    end

    test "unicode and special characters in real queries" do
      international_data = %{
        name: "José García",
        company: "Café ☕ Co.",
        description: "Software development & consulting",
        tags: ["españa", "café", "北京", "🚀"],
        email: "josé@café.com"
      }

      # Queries with unicode
      assert Predicated.test("name == 'José García'", international_data)
      assert Predicated.test("company == 'Café ☕ Co.'", international_data)
      assert Predicated.test("tags contains 'café'", international_data)
      assert Predicated.test("tags contains '🚀'", international_data)
    end
  end
end