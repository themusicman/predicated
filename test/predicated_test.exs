defmodule PredicatedTest do
  use ExUnit.Case
  doctest Predicated

  alias Predicated.Predicate
  alias Predicated.Condition

  describe "eval/2" do
    test "identifier in expression returns true" do
      assert Predicated.eval(
               %Condition{identifier: "name", comparison_operator: "in", expression: ["Bob"]},
               %{
                 name: "Bob"
               }
             ) == true
    end

    test "identifier in= expression returns false" do
      assert Predicated.eval(
               %Condition{identifier: "name", comparison_operator: "in", expression: ["Bill"]},
               %{
                 name: "Bob"
               }
             ) == false
    end

    test "identifier == expression returns true" do
      assert Predicated.eval(
               %Condition{identifier: "name", comparison_operator: "==", expression: "Bob"},
               %{
                 name: "Bob"
               }
             ) == true
    end

    test "identifier == expression returns false" do
      assert Predicated.eval(
               %Condition{identifier: "name", comparison_operator: "==", expression: "Bill"},
               %{
                 name: "Bob"
               }
             ) == false
    end

    test "identifier != expression returns true" do
      assert Predicated.eval(
               %Condition{identifier: "name", comparison_operator: "!=", expression: "Bill"},
               %{
                 name: "Bob"
               }
             ) == true
    end

    test "identifier != expression returns false" do
      assert Predicated.eval(
               %Condition{identifier: "name", comparison_operator: "!=", expression: "Bob"},
               %{
                 name: "Bob"
               }
             ) == false
    end

    test "identifier > expression returns true" do
      assert Predicated.eval(
               %Condition{identifier: "age", comparison_operator: ">", expression: 12},
               %{
                 age: 13
               }
             ) == true
    end

    test "identifier > expression returns false" do
      assert Predicated.eval(
               %Condition{identifier: "age", comparison_operator: ">", expression: 3},
               %{
                 age: 2
               }
             ) == false
    end

    test "identifier >= expression when values are equal returns true" do
      assert Predicated.eval(
               %Condition{identifier: "age", comparison_operator: ">=", expression: 2},
               %{
                 age: 2
               }
             ) == true
    end

    test "identifier >= expression returns true" do
      assert Predicated.eval(
               %Condition{identifier: "age", comparison_operator: ">=", expression: 12},
               %{
                 age: 13
               }
             ) == true
    end

    test "identifier >= expression returns false" do
      assert Predicated.eval(
               %Condition{identifier: "age", comparison_operator: ">=", expression: 3},
               %{
                 age: 2
               }
             ) == false
    end

    test "identifier < expression returns true" do
      assert Predicated.eval(
               %Condition{identifier: "age", comparison_operator: "<", expression: 3},
               %{
                 age: 2
               }
             ) == true
    end

    test "identifier < expression returns false" do
      assert Predicated.eval(
               %Condition{identifier: "age", comparison_operator: "<", expression: 12},
               %{
                 age: 13
               }
             ) == false
    end

    test "identifier <= expression when values are equal returns true" do
      assert Predicated.eval(
               %Condition{identifier: "age", comparison_operator: "<=", expression: 2},
               %{
                 age: 2
               }
             ) == true
    end

    test "identifier <= expression returns true" do
      assert Predicated.eval(
               %Condition{identifier: "age", comparison_operator: "<=", expression: 3},
               %{
                 age: 2
               }
             ) == true
    end

    test "identifier <= expression returns false" do
      assert Predicated.eval(
               %Condition{identifier: "age", comparison_operator: "<=", expression: 12},
               %{
                 age: 13
               }
             ) == false
    end

    test "identifier == date expression returns true" do
      assert Predicated.eval(
               %Condition{
                 identifier: "dob",
                 comparison_operator: "==",
                 expression: ~D[2020-01-01]
               },
               %{
                 dob: ~D[2020-01-01]
               }
             ) == true
    end

    test "identifier == date expression returns false" do
      assert Predicated.eval(
               %Condition{
                 identifier: "dob",
                 comparison_operator: "==",
                 expression: ~D[2020-01-01]
               },
               %{
                 dob: ~D[2020-01-03]
               }
             ) == false
    end

    test "identifier != date expression returns true" do
      assert Predicated.eval(
               %Condition{
                 identifier: "dob",
                 comparison_operator: "!=",
                 expression: ~D[2020-01-01]
               },
               %{
                 dob: ~D[2020-01-03]
               }
             ) == true
    end

    test "identifier != date expression returns false" do
      assert Predicated.eval(
               %Condition{
                 identifier: "dob",
                 comparison_operator: "!=",
                 expression: ~D[2020-01-01]
               },
               %{
                 dob: ~D[2020-01-01]
               }
             ) == false
    end

    test "identifier > date expression returns true" do
      assert Predicated.eval(
               %Condition{
                 identifier: "dob",
                 comparison_operator: ">",
                 expression: ~D[2020-01-01]
               },
               %{
                 dob: ~D[2020-01-02]
               }
             ) == true
    end

    test "identifier > date expression returns false" do
      assert Predicated.eval(
               %Condition{
                 identifier: "dob",
                 comparison_operator: ">",
                 expression: ~D[2020-01-07]
               },
               %{
                 dob: ~D[2020-01-02]
               }
             ) == false
    end

    test "identifier >= date expression when values are equal returns true" do
      assert Predicated.eval(
               %Condition{
                 identifier: "dob",
                 comparison_operator: ">=",
                 expression: ~D[2020-01-02]
               },
               %{
                 dob: ~D[2020-01-02]
               }
             ) == true
    end

    test "identifier >= date expression returns true" do
      assert Predicated.eval(
               %Condition{
                 identifier: "dob",
                 comparison_operator: ">=",
                 expression: ~D[2020-01-02]
               },
               %{
                 dob: ~D[2020-01-03]
               }
             ) == true
    end

    test "identifier >= date expression returns false" do
      assert Predicated.eval(
               %Condition{
                 identifier: "dob",
                 comparison_operator: ">=",
                 expression: ~D[2020-01-02]
               },
               %{
                 dob: ~D[2019-01-02]
               }
             ) == false
    end

    test "identifier < date expression returns true" do
      assert Predicated.eval(
               %Condition{
                 identifier: "dob",
                 comparison_operator: "<",
                 expression: ~D[2020-01-02]
               },
               %{
                 dob: ~D[2019-01-01]
               }
             ) == true
    end

    test "identifier < date expression returns false" do
      assert Predicated.eval(
               %Condition{
                 identifier: "dob",
                 comparison_operator: "<",
                 expression: ~D[2020-01-02]
               },
               %{
                 dob: ~D[2023-01-01]
               }
             ) == false
    end

    test "identifier <= date expression when values are equal returns true" do
      assert Predicated.eval(
               %Condition{
                 identifier: "dob",
                 comparison_operator: "<=",
                 expression: ~D[2020-01-02]
               },
               %{
                 dob: ~D[2020-01-02]
               }
             ) == true
    end

    test "identifier <= date expression returns true" do
      assert Predicated.eval(
               %Condition{
                 identifier: "dob",
                 comparison_operator: "<=",
                 expression: ~D[2020-01-02]
               },
               %{
                 dob: ~D[2019-01-02]
               }
             ) == true
    end

    test "identifier <= date expression returns false" do
      assert Predicated.eval(
               %Condition{
                 identifier: "dob",
                 comparison_operator: "<=",
                 expression: ~D[2020-01-02]
               },
               %{
                 dob: ~D[2023-01-02]
               }
             ) == false
    end
  end

  describe "test/3" do
    setup do
      subject = %{first_name: "Joe", last_name: "Armstrong"}
      {:ok, subject: subject}
    end

    test "returns false when true && false", %{subject: subject} do
      predicates = [
        %Predicate{
          condition: %Condition{
            identifier: "last_name",
            comparison_operator: "==",
            expression: "Armstrong"
          },
          logical_operator: :and
        },
        %Predicate{
          condition: %Condition{
            identifier: "first_name",
            comparison_operator: "==",
            expression: "Ben"
          }
        }
      ]

      assert Predicated.test(predicates, subject) == false
    end

    test "returns false when false && true", %{subject: subject} do
      predicates = [
        %Predicate{
          condition: %Condition{
            identifier: "last_name",
            comparison_operator: "==",
            expression: "Beaver"
          },
          logical_operator: :and
        },
        %Predicate{
          condition: %Condition{
            identifier: "first_name",
            comparison_operator: "==",
            expression: "Joe"
          }
        }
      ]

      assert Predicated.test(predicates, subject) == false
    end

    test "returns false when false || false", %{subject: subject} do
      predicates = [
        %Predicate{
          condition: %Condition{
            identifier: "last_name",
            comparison_operator: "==",
            expression: "Beaver"
          },
          logical_operator: :or
        },
        %Predicate{
          condition: %Condition{
            identifier: "first_name",
            comparison_operator: "==",
            expression: "Ted"
          }
        }
      ]

      assert Predicated.test(predicates, subject) == false
    end

    test "returns true when false || true", %{subject: subject} do
      predicates = [
        %Predicate{
          condition: %Condition{
            identifier: "last_name",
            comparison_operator: "==",
            expression: "Beaver"
          },
          logical_operator: :or
        },
        %Predicate{
          condition: %Condition{
            identifier: "first_name",
            comparison_operator: "==",
            expression: "Joe"
          }
        }
      ]

      assert Predicated.test(predicates, subject) == true
    end

    test "returns true when true || false", %{subject: subject} do
      predicates = [
        %Predicate{
          condition: %Condition{
            identifier: "last_name",
            comparison_operator: "==",
            expression: "Armstrong"
          },
          logical_operator: :or
        },
        %Predicate{
          condition: %Condition{
            identifier: "first_name",
            comparison_operator: "==",
            expression: "Bill"
          }
        }
      ]

      assert Predicated.test(predicates, subject) == true
    end

    test "returns true when true || true", %{subject: subject} do
      predicates = [
        %Predicate{
          condition: %Condition{
            identifier: "last_name",
            comparison_operator: "==",
            expression: "Armstrong"
          },
          logical_operator: :or
        },
        %Predicate{
          condition: %Condition{
            identifier: "first_name",
            comparison_operator: "==",
            expression: "Joe"
          }
        }
      ]

      assert Predicated.test(predicates, subject) == true
    end

    test "returns true when true && true", %{subject: subject} do
      predicates = [
        %Predicate{
          condition: %Condition{
            identifier: "last_name",
            comparison_operator: "==",
            expression: "Armstrong"
          },
          logical_operator: :and
        },
        %Predicate{
          condition: %Condition{
            identifier: "first_name",
            comparison_operator: "==",
            expression: "Joe"
          }
        }
      ]

      assert Predicated.test(predicates, subject) == true
    end

    test "returns true when true && (true || false)", %{subject: subject} do
      predicates = [
        %Predicate{
          condition: %Condition{
            identifier: "last_name",
            comparison_operator: "==",
            expression: "Armstrong"
          },
          logical_operator: :and
        },
        %Predicate{
          predicates: [
            %Predicate{
              condition: %Condition{
                identifier: "first_name",
                comparison_operator: "==",
                expression: "Joe"
              },
              logical_operator: :or
            },
            %Predicate{
              condition: %Condition{
                identifier: "first_name",
                comparison_operator: "==",
                expression: "Bill"
              }
            }
          ]
        }
      ]

      assert Predicated.test(predicates, subject) == true
    end

    test "returns true when true && (true || (false && true))", %{subject: subject} do
      predicates = [
        %Predicate{
          condition: %Condition{
            identifier: "last_name",
            comparison_operator: "==",
            expression: "Armstrong"
          },
          logical_operator: :and
        },
        %Predicate{
          predicates: [
            %Predicate{
              condition: %Condition{
                identifier: "first_name",
                comparison_operator: "==",
                expression: "Joe"
              },
              logical_operator: :or
            },
            %Predicate{
              predicates: [
                %Predicate{
                  condition: %Condition{
                    identifier: "first_name",
                    comparison_operator: "==",
                    expression: "Jill"
                  },
                  logical_operator: :and
                },
                %Predicate{
                  condition: %Condition{
                    identifier: "first_name",
                    comparison_operator: "==",
                    expression: "Joe"
                  }
                }
              ]
            }
          ]
        }
      ]

      assert Predicated.test(predicates, subject) == true
    end

    test "returns true when true && (true || (false && true)) || true", %{subject: subject} do
      predicates = [
        %Predicate{
          condition: %Condition{
            identifier: "last_name",
            comparison_operator: "==",
            expression: "Armstrong"
          },
          logical_operator: :and
        },
        %Predicate{
          logical_operator: :or,
          predicates: [
            %Predicate{
              condition: %Condition{
                identifier: "first_name",
                comparison_operator: "==",
                expression: "Joe"
              },
              logical_operator: :and
            },
            %Predicate{
              predicates: [
                %Predicate{
                  condition: %Condition{
                    identifier: "first_name",
                    comparison_operator: "==",
                    expression: "Jill"
                  },
                  logical_operator: :or
                },
                %Predicate{
                  condition: %Condition{
                    identifier: "first_name",
                    comparison_operator: "==",
                    expression: "Joe"
                  }
                }
              ]
            }
          ]
        },
        %Predicate{
          condition: %Condition{
            identifier: "last_name",
            comparison_operator: "==",
            expression: "Armstrong"
          }
        }
      ]

      assert Predicated.test(predicates, subject) == true
    end

    test "returns false when true && (true || (false && true)) && false", %{subject: subject} do
      predicates = [
        %Predicate{
          condition: %Condition{
            identifier: "last_name",
            comparison_operator: "==",
            expression: "Armstrong"
          },
          logical_operator: :and
        },
        %Predicate{
          logical_operator: :and,
          predicates: [
            %Predicate{
              condition: %Condition{
                identifier: "first_name",
                comparison_operator: "==",
                expression: "Joe"
              },
              logical_operator: :or
            },
            %Predicate{
              predicates: [
                %Predicate{
                  condition: %Condition{
                    identifier: "first_name",
                    comparison_operator: "==",
                    expression: "Jill"
                  },
                  logical_operator: :and
                },
                %Predicate{
                  condition: %Condition{
                    identifier: "first_name",
                    comparison_operator: "==",
                    expression: "Joe"
                  }
                }
              ]
            }
          ]
        },
        %Predicate{
          condition: %Condition{
            identifier: "last_name",
            comparison_operator: "==",
            expression: "Beaver"
          }
        }
      ]

      assert Predicated.test(predicates, subject) == false
    end
  end

  describe "test/2 when passed a query string" do
    test "returns true" do
      result =
        Predicated.test("trace_id == 'test123' and profile_id == '123'", %{
          trace_id: "test123",
          profile_id: "123"
        })

      assert result
    end

    test "returns false" do
      result =
        Predicated.test("trace_id != 'test123' and profile_id == '123'", %{
          trace_id: "test123",
          profile_id: "123"
        })

      refute result
    end
  end

  describe "to_query/1" do
    test "retuns query string for predicates" do
      predicates = [
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
      ]

      assert Predicated.to_query(predicates) ==
               "trace_id == 'test123' AND (organization_id == '1' OR (user_id == '123' OR user_id == '456'))"
    end
  end
end
