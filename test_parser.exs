alias Predicated.Query

# Test different patterns
tests = [
  "a == 1 AND b == 2 AND ( c == 3 )",
  "a == 1 AND b == 2 AND (c == 3)",
  "a == 1 AND b == 2 AND ( (c == 3) )",
  "age >= 21 AND age <= 65 AND (score >= 700)",
  "age >= 21 AND age <= 65 AND ( (score >= 700) )",
]

for test <- tests do
  result = Query.new(test)
  case result do
    {:ok, _} -> IO.puts("✓ #{test}")
    {:error, reason} -> IO.puts("✗ #{test} - #{inspect(reason)}")
  end
end