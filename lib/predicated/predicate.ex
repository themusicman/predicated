defmodule Predicated.Predicate do
  # patient_id == 1 AND (provider_id == 2 OR provider_id == 3) 
  defstruct condition: nil, logical_operator: :and, predicates: []
end
