
function MOI.add_constraint(
   model::Optimizer,
   func::MOI.ScalarAffineFunction{Float64},
   set::MOI.LessThan{Float64}
)
   check_inbounds(model, func)
   push!(model.linear_le_constraints, ConstraintInfo(func, set))
   n = length(model.linear_le_constraints)
   return MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.LessThan{Float64}}(n)
end

function MOI.add_constraint(
   model::Optimizer,
   func::MOI.ScalarAffineFunction{Float64},
   set::MOI.GreaterThan{Float64}
)
   check_inbounds(model, func)
   push!(model.linear_ge_constraints, ConstraintInfo(func, set))
   n = length(model.linear_ge_constraints)
   return MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.GreaterThan{Float64}}(n)
end

function MOI.add_constraint(
   model::Optimizer,
   func::MOI.ScalarAffineFunction{Float64},
   set::MOI.EqualTo{Float64}
)
   check_inbounds(model, func)
   push!(model.linear_eq_constraints, ConstraintInfo(func, set))
   n = length(model.linear_eq_constraints)
   return MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.EqualTo{Float64}}(n)
end

function MOI.add_constraint(
   model::Optimizer,
   func::MOI.ScalarQuadraticFunction{Float64},
   set::MOI.LessThan{Float64}
)
   check_inbounds(model, func)
   push!(model.quadratic_le_constraints, ConstraintInfo(func, set))
   n = length(model.quadratic_le_constraints)
   return MOI.ConstraintIndex{MOI.ScalarQuadraticFunction{Float64}, MOI.LessThan{Float64}}(n)
end

function MOI.add_constraint(
   model::Optimizer,
   func::MOI.ScalarQuadraticFunction{Float64},
   set::MOI.GreaterThan{Float64}
)
   check_inbounds(model, func)
   push!(model.quadratic_ge_constraints, ConstraintInfo(func, set))
   n = length(model.quadratic_ge_constraints)
   return MOI.ConstraintIndex{MOI.ScalarQuadraticFunction{Float64}, MOI.GreaterThan{Float64}}(n)
end

function MOI.add_constraint(
   model::Optimizer,
   func::MOI.ScalarQuadraticFunction{Float64},
   set::MOI.EqualTo{Float64}
)
   check_inbounds(model, func)
   push!(model.quadratic_eq_constraints, ConstraintInfo(func, set))
   n = length(model.quadratic_eq_constraints)
   return MOI.ConstraintIndex{MOI.ScalarQuadraticFunction{Float64}, MOI.EqualTo{Float64}}(n)
end

function MOI.get(
   model::Optimizer,
   ::MOI.NumberOfConstraints{MOI.ScalarAffineFunction{Float64}, MOI.LessThan{Float64}}
)
   return length(model.linear_le_constraints)
end

function MOI.get(
   model::Optimizer,
   ::MOI.NumberOfConstraints{MOI.ScalarAffineFunction{Float64}, MOI.GreaterThan{Float64}}
)
   return length(model.linear_ge_constraints)
end

function MOI.get(
   model::Optimizer,
   ::MOI.NumberOfConstraints{MOI.ScalarAffineFunction{Float64}, MOI.EqualTo{Float64}}
)
   return length(model.linear_eq_constraints)
end

function MOI.get(
   model::Optimizer,
   ::MOI.NumberOfConstraints{MOI.ScalarQuadraticFunction{Float64}, MOI.LessThan{Float64}}
)
   return length(model.quadratic_le_constraints)
end

function MOI.get(
   model::Optimizer,
   ::MOI.NumberOfConstraints{MOI.ScalarQuadraticFunction{Float64}, MOI.GreaterThan{Float64}}
)
   return length(model.quadratic_ge_constraints)
end

function MOI.get(
   model::Optimizer,
   ::MOI.NumberOfConstraints{MOI.ScalarQuadraticFunction{Float64}, MOI.EqualTo{Float64}}
)
   return length(model.quadratic_eq_constraints)
end

function MOI.set(
   model::Optimizer,
   attr::MOI.ConstraintName,
   ci::MOI.ConstraintIndex{MOI.SingleVariable},
   value
)
   error("Constraint names for variable bound constraints not supported.")
   return
end

function MOI.set(
   model::Optimizer,
   attr::MOI.ConstraintName,
   ci::MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.LessThan{Float64}},
   value
)
   if ! (1 <= ci.value <= length(model.linear_le_constraints))
      error("Invalid constraint index ", ci.value)
   end
   model.linear_le_constraints[ci.value].name = value
   return
end

function MOI.set(
   model::Optimizer,
   attr::MOI.ConstraintName,
   ci::MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.GreaterThan{Float64}},
   value
)
   if ! (1 <= ci.value <= length(model.linear_ge_constraints))
      error("Invalid constraint index ", ci.value)
   end
   model.linear_ge_constraints[ci.value].name = value
   return
end

function MOI.set(
   model::Optimizer,
   attr::MOI.ConstraintName,
   ci::MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.EqualTo{Float64}},
   value
)
   if ! (1 <= ci.value <= length(model.linear_eq_constraints))
      error("Invalid constraint index ", ci.value)
   end
   model.linear_eq_constraints[ci.value].name = value
   return
end

function MOI.set(
   model::Optimizer,
   attr::MOI.ConstraintName,
   ci::MOI.ConstraintIndex{MOI.ScalarQuadraticFunction{Float64}, MOI.LessThan{Float64}},
   value
)
   if ! (1 <= ci.value <= length(model.quadratic_le_constraints))
      error("Invalid constraint index ", ci.value)
   end
   model.quadratic_le_constraints[ci.value].name = value
   return
end

function MOI.set(
   model::Optimizer,
   attr::MOI.ConstraintName,
   ci::MOI.ConstraintIndex{MOI.ScalarQuadraticFunction{Float64}, MOI.GreaterThan{Float64}},
   value
)
   if ! (1 <= ci.value <= length(model.quadratic_ge_constraints))
      error("Invalid constraint index ", ci.value)
   end
   model.quadratic_ge_constraints[ci.value].name = value
   return
end

function MOI.set(
   model::Optimizer,
   attr::MOI.ConstraintName,
   ci::MOI.ConstraintIndex{MOI.ScalarQuadraticFunction{Float64}, MOI.EqualTo{Float64}},
   value
)
   if ! (1 <= ci.value <= length(model.quadratic_eq_constraints))
      error("Invalid constraint index ", ci.value)
   end
   model.quadratic_eq_constraints[ci.value].name = value
   return
end

function MOI.get(
   model::Optimizer,
   ::MOI.ConstraintName,
   ci::MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.LessThan{Float64}}
)
   if ! (1 <= ci.value <= length(model.linear_le_constraints))
      error("Invalid constraint index ", ci.value)
   end
   return model.linear_le_constraints[ci.value].name
end

function MOI.get(
   model::Optimizer,
   ::MOI.ConstraintName,
   ci::MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.GreaterThan{Float64}}
)
   if ! (1 <= ci.value <= length(model.linear_ge_constraints))
      error("Invalid constraint index ", ci.value)
   end
   return model.linear_ge_constraints[ci.value].name
end

function MOI.get(
   model::Optimizer,
   ::MOI.ConstraintName,
   ci::MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.EqualTo{Float64}}
)
   if ! (1 <= ci.value <= length(model.linear_eq_constraints))
      error("Invalid constraint index ", ci.value)
   end
   return model.linear_eq_constraints[ci.value].name
end

function MOI.get(
   model::Optimizer,
   ::MOI.ConstraintName,
   ci::MOI.ConstraintIndex{MOI.ScalarQuadraticFunction{Float64}, MOI.LessThan{Float64}}
)
   if ! (1 <= ci.value <= length(model.quadratic_le_constraints))
      error("Invalid constraint index ", ci.value)
   end
   return model.quadratic_le_constraints[ci.value].name
end

function MOI.get(
   model::Optimizer,
   ::MOI.ConstraintName,
   ci::MOI.ConstraintIndex{MOI.ScalarQuadraticFunction{Float64}, MOI.GreaterThan{Float64}}
)
   if ! (1 <= ci.value <= length(model.quadratic_ge_constraints))
      error("Invalid constraint index ", ci.value)
   end
   return model.quadratic_ge_constraints[ci.value].name
end

function MOI.get(
   model::Optimizer,
   ::MOI.ConstraintName,
   ci::MOI.ConstraintIndex{MOI.ScalarQuadraticFunction{Float64}, MOI.EqualTo{Float64}}
)
   if ! (1 <= ci.value <= length(model.quadratic_eq_constraints))
      error("Invalid constraint index ", ci.value)
   end
   return model.quadratic_eq_constraints[ci.value].name
end

function MOI.get(
   model::Optimizer,
   ::MOI.ConstraintSet,
   ci::MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.LessThan{Float64}}
)
   if ! (1 <= ci.value <= length(model.linear_le_constraints))
      error("Invalid constraint index ", ci.value)
   end
   return MOI.LessThan(model.linear_le_constraints[ci.value].set.upper)
end

function MOI.get(
   model::Optimizer,
   ::MOI.ConstraintSet,
   ci::MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.GreaterThan{Float64}}
)
   if ! (1 <= ci.value <= length(model.linear_ge_constraints))
      error("Invalid constraint index ", ci.value)
   end
   return MOI.GreaterThan(model.linear_ge_constraints[ci.value].set.lower)
end

function MOI.get(
   model::Optimizer,
   ::MOI.ConstraintSet,
   ci::MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.EqualTo{Float64}}
)
   if ! (1 <= ci.value <= length(model.linear_eq_constraints))
      error("Invalid constraint index ", ci.value)
   end
   return MOI.EqualTo(model.linear_eq_constraints[ci.value].set.value)
end

function MOI.get(
   model::Optimizer,
   ::MOI.ConstraintSet,
   ci::MOI.ConstraintIndex{MOI.ScalarQuadraticFunction{Float64}, MOI.LessThan{Float64}}
)
   if ! (1 <= ci.value <= length(model.quadratic_le_constraints))
      error("Invalid constraint index ", ci.value)
   end
   return MOI.LessThan(model.quadratic_le_constraints[ci.value].set.upper)
end

function MOI.get(
   model::Optimizer,
   ::MOI.ConstraintSet,
   ci::MOI.ConstraintIndex{MOI.ScalarQuadraticFunction{Float64}, MOI.GreaterThan{Float64}}
)
   if ! (1 <= ci.value <= length(model.quadratic_ge_constraints))
      error("Invalid constraint index ", ci.value)
   end
   return MOI.GreaterThan(model.quadratic_ge_constraints[ci.value].set.lower)
end

function MOI.get(
   model::Optimizer,
   ::MOI.ConstraintSet,
   ci::MOI.ConstraintIndex{MOI.ScalarQuadraticFunction{Float64}, MOI.EqualTo{Float64}}
)
   if ! (1 <= ci.value <= length(model.quadratic_eq_constraints))
      error("Invalid constraint index ", ci.value)
   end
   return MOI.EqualTo(model.quadratic_eq_constraints[ci.value].set.value)
end

function MOI.get(
   model::Optimizer,
   attr::MOI.ConstraintPrimal,
   ci::MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.LessThan{Float64}}
)
   MOI.check_result_index_bounds(model, attr)
   if ! (1 <= ci.value <= length(model.linear_le_constraints))
      error("Invalid constraint index ", ci.value)
   end
   return model.sol.equ["eq$(ci.value + offset_linear_le(model))"].level[1]
end

function MOI.get(
   model::Optimizer,
   attr::MOI.ConstraintPrimal,
   ci::MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.GreaterThan{Float64}}
)
   MOI.check_result_index_bounds(model, attr)
   if ! (1 <= ci.value <= length(model.linear_ge_constraints))
      error("Invalid constraint index ", ci.value)
   end
   return model.sol.equ["eq$(ci.value + offset_linear_ge(model))"].level[1]
end

function MOI.get(
   model::Optimizer,
   attr::MOI.ConstraintPrimal,
   ci::MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.EqualTo{Float64}}
)
   MOI.check_result_index_bounds(model, attr)
   if ! (1 <= ci.value <= length(model.linear_eq_constraints))
      error("Invalid constraint index ", ci.value)
   end
   return model.sol.equ["eq$(ci.value + offset_linear_eq(model))"].level[1]
end

function MOI.get(
   model::Optimizer,
   attr::MOI.ConstraintPrimal,
   ci::MOI.ConstraintIndex{MOI.ScalarQuadraticFunction{Float64}, MOI.LessThan{Float64}}
)
   MOI.check_result_index_bounds(model, attr)
   if ! (1 <= ci.value <= length(model.quadratic_le_constraints))
      error("Invalid constraint index ", ci.value)
   end
   return model.sol.equ["eq$(ci.value + offset_quadratic_le(model))"].level[1]
end

function MOI.get(
   model::Optimizer,
   attr::MOI.ConstraintPrimal,
   ci::MOI.ConstraintIndex{MOI.ScalarQuadraticFunction{Float64}, MOI.GreaterThan{Float64}}
)
   MOI.check_result_index_bounds(model, attr)
   if ! (1 <= ci.value <= length(model.quadratic_ge_constraints))
      error("Invalid constraint index ", ci.value)
   end
   return model.sol.equ["eq$(ci.value + offset_quadratic_ge(model))"].level[1]
end

function MOI.get(
   model::Optimizer,
   attr::MOI.ConstraintPrimal,
   ci::MOI.ConstraintIndex{MOI.ScalarQuadraticFunction{Float64}, MOI.EqualTo{Float64}}
)
   MOI.check_result_index_bounds(model, attr)
   if ! (1 <= ci.value <= length(model.quadratic_eq_constraints))
      error("Invalid constraint index ", ci.value)
   end
   return model.sol.equ["eq$(ci.value + offset_quadratic_eq(model))"].level[1]
end

function MOI.get(
   model::Optimizer,
   attr::MOI.ConstraintDual,
   ci::MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.LessThan{Float64}}
)
   MOI.check_result_index_bounds(model, attr)
   if !(1 <= ci.value <= length(model.linear_le_constraints))
         error("Invalid constraint index ", ci.value)
   end
   return -model.sol.equ["eq$(ci.value + offset_linear_le(model))"].dual[1]
end

function MOI.get(
   model::Optimizer,
   attr::MOI.ConstraintDual,
   ci::MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.GreaterThan{Float64}}
)
   MOI.check_result_index_bounds(model, attr)
   if !(1 <= ci.value <= length(model.linear_ge_constraints))
         error("Invalid constraint index ", ci.value)
   end
   return model.sol.equ["eq$(ci.value + offset_linear_ge(model))"].dual[1]
end

function MOI.get(
   model::Optimizer,
   attr::MOI.ConstraintDual,
   ci::MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.EqualTo{Float64}}
)
   MOI.check_result_index_bounds(model, attr)
   if !(1 <= ci.value <= length(model.linear_eq_constraints))
         error("Invalid constraint index ", ci.value)
   end
   return model.sol.equ["eq$(ci.value + offset_linear_eq(model))"].dual[1]
end

function MOI.get(
   model::Optimizer,
   attr::MOI.ConstraintDual,
   ci::MOI.ConstraintIndex{MOI.ScalarQuadraticFunction{Float64}, MOI.LessThan{Float64}}
)
   MOI.check_result_index_bounds(model, attr)
   if !(1 <= ci.value <= length(model.quadratic_le_constraints))
         error("Invalid constraint index ", ci.value)
   end
   return -model.sol.equ["eq$(ci.value + offset_quadratic_le(model))"].dual[1]
end

function MOI.get(
   model::Optimizer,
   attr::MOI.ConstraintDual,
   ci::MOI.ConstraintIndex{MOI.ScalarQuadraticFunction{Float64}, MOI.GreaterThan{Float64}}
)
   MOI.check_result_index_bounds(model, attr)
   if !(1 <= ci.value <= length(model.quadratic_ge_constraints))
         error("Invalid constraint index ", ci.value)
   end
   return -model.sol.equ["eq$(ci.value + offset_quadratic_ge(model))"].dual[1]
end

function MOI.get(
   model::Optimizer,
   attr::MOI.ConstraintDual,
   ci::MOI.ConstraintIndex{MOI.ScalarQuadraticFunction{Float64}, MOI.EqualTo{Float64}}
)
   MOI.check_result_index_bounds(model, attr)
   if !(1 <= ci.value <= length(model.quadratic_eq_constraints))
         error("Invalid constraint index ", ci.value)
   end
   return -model.sol.equ["eq$(ci.value + offset_quadratic_eq(model))"].dual[1]
end

function MOI.get(
   model::Optimizer,
   attr::MOI.NLPBlockDual
)
   MOI.check_result_index_bounds(model, attr)
   values = zeros(model.m_nonlin)
   for i = offset_nonlin(model)+1:offset_nonlin(model)+model.m_nonlin
      values[i] = -model.sol.equ["eq$i"].dual[1]
   end
   return values
end
