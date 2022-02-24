
function MOI.get(
   model::Optimizer,
   ::MOI.ListOfConstraintTypesPresent
)
   constraints = Set{Tuple{Type,Type}}()

   for info in values(model.variable_info)
      if info.type == VARTYPE_BINARY
         push!(constraints, (MOI.VariableIndex, MOI.ZeroOne))
      elseif info.type == VARTYPE_INTEGER
         push!(constraints, (MOI.VariableIndex, MOI.Integer))
      elseif info.type == VARTYPE_SEMICONT
         push!(constraints, (MOI.VariableIndex, MOI.Semicontinuous{Float64}))
      elseif info.type == VARTYPE_SEMIINT
         push!(constraints, (MOI.VariableIndex, MOI.Semiinteger{Float64}))
      end

      if _is_fixed(info)
         push!(constraints, (MOI.VariableIndex, MOI.EqualTo{Float64}))
      elseif _has_lower_bound(info) && _has_upper_bound(info)
         push!(constraints, (MOI.VariableIndex, MOI.GreaterThan{Float64}))
         push!(constraints, (MOI.VariableIndex, MOI.LessThan{Float64}))
      elseif _has_upper_bound(info)
         push!(constraints, (MOI.VariableIndex, MOI.LessThan{Float64}))
      elseif _has_lower_bound(info)
         push!(constraints, (MOI.VariableIndex, MOI.GreaterThan{Float64}))
      end
   end

   if length(model.linear_eq_constraints) > 0
      push!(constraints, (MOI.ScalarAffineFunction{Float64}, MOI.EqualTo{Float64}))
   end
   if length(model.linear_le_constraints) > 0
      push!(constraints, (MOI.ScalarAffineFunction{Float64}, MOI.LessThan{Float64}))
   end
   if length(model.linear_ge_constraints) > 0
      push!(constraints, (MOI.ScalarAffineFunction{Float64}, MOI.GreaterThan{Float64}))
   end

   if length(model.quadratic_eq_constraints) > 0
      push!(constraints, (MOI.ScalarQuadraticFunction{Float64}, MOI.EqualTo{Float64}))
   end
   if length(model.quadratic_le_constraints) > 0
      push!(constraints, (MOI.ScalarQuadraticFunction{Float64}, MOI.LessThan{Float64}))
   end
   if length(model.quadratic_ge_constraints) > 0
      push!(constraints, (MOI.ScalarQuadraticFunction{Float64}, MOI.GreaterThan{Float64}))
   end

   if length(model.sos1_constraints) > 0
      push!(constraints, (MOI.VectorOfVariables, MOI.SOS1{Float64}))
   end
   if length(model.sos2_constraints) > 0
      push!(constraints, (MOI.VectorOfVariables, MOI.SOS2{Float64}))
   end

   if length(model.complementarity_constraints) > 0
      push!(constraints, (MOI.VectorAffineFunction{Float64}, MOI.Complements))
   end

   return collect(constraints)
end

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

function MOI.add_constraint(
   model::Optimizer,
   func::MOI.VectorAffineFunction{Float64},
   set::MOI.Complements
)
   check_inbounds(model, func)
   push!(model.complementarity_constraints, ConstraintInfo(func, set))
   n = length(model.complementarity_constraints)
   return MathOptInterface.ConstraintIndex{MOI.VectorAffineFunction{Float64}, MOI.Complements}(n)
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

function MOI.get(
   model::Optimizer,
   ::MOI.NumberOfConstraints{MOI.VectorAffineFunction{Float64}, MOI.Complements}
)
   return length(model.complementarity_constraints)
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
   ::GeneratedConstraintName,
   ci::MOI.ConstraintIndex{F, S}
) where {
   F <: Union{
      MOI.ScalarAffineFunction{Float64},
      MOI.ScalarQuadraticFunction{Float64},
   },
   S,
}
   return equation_name(model, ci)
end

function MOI.get(
   model::Optimizer,
   attr::OriginalConstraintName
)
   for (i, con) in enumerate(model.linear_le_constraints)
      if equation_name(model, MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.LessThan{Float64}}(i)) == attr.name
         return con.name
      end
   end
   for (i, con) in enumerate(model.linear_ge_constraints)
      if equation_name(model, MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.GreaterThan{Float64}}(i)) == attr.name
         return con.name
      end
   end
   for (i, con) in enumerate(model.linear_eq_constraints)
      if equation_name(model, MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.EqualTo{Float64}}(i)) == attr.name
         return con.name
      end
   end
   for (i, con) in enumerate(model.quadratic_le_constraints)
      if equation_name(model, MOI.ConstraintIndex{MOI.ScalarQuadraticFunction{Float64}, MOI.LessThan{Float64}}(i)) == attr.name
         return con.name
      end
   end
   for (i, con) in enumerate(model.quadratic_ge_constraints)
      if equation_name(model, MOI.ConstraintIndex{MOI.ScalarQuadraticFunction{Float64}, MOI.GreaterThan{Float64}}(i)) == attr.name
         return con.name
      end
   end
   for (i, con) in enumerate(model.quadratic_eq_constraints)
      if equation_name(model, MOI.ConstraintIndex{MOI.ScalarQuadraticFunction{Float64}, MOI.EqualTo{Float64}}(i)) == attr.name
         return con.name
      end
   end
   return nothing
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
   ::MOI.ConstraintName,
   ci::MOI.ConstraintIndex{MOI.VectorAffineFunction{Float64}, MOI.Complements}
)
   if ! (1 <= ci.value <= length(model.complementarity_constraints))
      error("Invalid constraint index ", ci.value)
   end
   return model.complementarity_constraints[ci.value].name
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
   return model.sol.equ[equation_name(model, ci)].level[1]
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
   return model.sol.equ[equation_name(model, ci)].level[1]
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
   return model.sol.equ[equation_name(model, ci)].level[1]
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
   return model.sol.equ[equation_name(model, ci)].level[1]
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
   return model.sol.equ[equation_name(model, ci)].level[1]
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
   return model.sol.equ[equation_name(model, ci)].level[1]
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
   s = _dual_multiplier(model)
   return s * model.sol.equ[equation_name(model, ci)].dual[1]
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
   s = _dual_multiplier(model)
   return s * model.sol.equ[equation_name(model, ci)].dual[1]
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
   s = _dual_multiplier(model)
   return s * model.sol.equ[equation_name(model, ci)].dual[1]
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
   s = _dual_multiplier(model)
   return s * model.sol.equ[equation_name(model, ci)].dual[1]
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
   s = _dual_multiplier(model)
   return s * model.sol.equ[equation_name(model, ci)].dual[1]
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
   s = _dual_multiplier(model)
   return s * model.sol.equ[equation_name(model, ci)].dual[1]
end

function MOI.get(
   model::Optimizer,
   attr::MOI.NLPBlockDual
)
   MOI.check_result_index_bounds(model, attr)
   values = zeros(model.m_nonlin)
   s = _dual_multiplier(model)
   for i = _offset_nonlin(model)+1:_offset_nonlin(model)+model.m_nonlin
      values[i] = s * model.sol.equ["eq$i"].dual[1]
   end
   return values
end
