
function MOI.get(
   model::Optimizer,
   ::MOI.NumberOfVariables
)
   return length(model.variable_info)
end

function MOI.get(
   model::Optimizer,
   ::MOI.ListOfVariableIndices
)
   return [MOI.VariableIndex(i) for i in 1:length(model.variable_info)]
end

function MOI.get(
   model::Optimizer,
   ::MOI.NumberOfConstraints{MOI.VariableIndex, MOI.LessThan{Float64}}
)
   n = 0
   for var in model.variable_info
      if _has_upper_bound(var)
         n += 1
      end
   end
   return n
end

function MOI.get(
   model::Optimizer,
   ::MOI.NumberOfConstraints{MOI.VariableIndex, MOI.GreaterThan{Float64}}
)
   n = 0
   for var in model.variable_info
      if _has_lower_bound(var)
         n += 1
      end
   end
   return n
end

function MOI.get(
   model::Optimizer,
   ::MOI.NumberOfConstraints{MOI.VariableIndex, MOI.EqualTo{Float64}}
)
   n = 0
   for var in model.variable_info
      if _is_fixed(var)
         n += 1
      end
   end
   return n
end

function MOI.add_variable(
   model::Optimizer
)
   push!(model.variable_info, VariableInfo())
   return MOI.VariableIndex(length(model.variable_info))
end

function MOI.add_variables(
   model::Optimizer,
   n::Int
)
   return [MOI.add_variable(model) for i in 1:n]
end

function MOI.set(
   model::Optimizer,
   ::MOI.VariablePrimalStart,
   vi::MOI.VariableIndex,
   value::Union{Real, Nothing}
)
   check_inbounds(model, vi)
   model.variable_info[vi.value].start = value
   return
end

function MOI.set(
   model::Optimizer,
   attr::MOI.VariableName,
   vi::MOI.VariableIndex,
   value
)
   check_inbounds(model, vi)
   model.variable_info[vi.value].name = value
end

function MOI.get(
   model::Optimizer,
   ::MOI.VariableName,
   vi::MOI.VariableIndex
)
   return model.variable_info[vi.value].name
end

function MOI.get(
   model::Optimizer,
   ::Type{MathOptInterface.VariableIndex},
   name::String
)
   for (i, var) in enumerate(model.variable_info)
      if name == var.name
         return MOI.VariableIndex(i)
      end
   end
   error("Unrecognized variable name $name.")
end

function MOI.add_constraint(
   model::Optimizer,
   vi::MOI.VariableIndex,
   lt::MOI.LessThan{Float64}
)
   check_inbounds(model, vi)
   if isnan(lt.upper)
      error("Invalid upper bound value $(lt.upper).")
   end
   upper_bound = model.variable_info[vi.value].upper_bound
   if upper_bound === nothing
      upper_bound = lt.upper
   else
      upper_bound = min(lt.upper, upper_bound)
   end
   model.variable_info[vi.value].upper_bound = upper_bound
   return MOI.ConstraintIndex{MOI.VariableIndex, MOI.LessThan{Float64}}(vi.value)
end

function MOI.add_constraint(
   model::Optimizer,
   vi::MOI.VariableIndex,
   gt::MOI.GreaterThan{Float64}
)
   check_inbounds(model, vi)
   if isnan(gt.lower)
      error("Invalid lower bound value $(gt.lower).")
   end
   lower_bound = model.variable_info[vi.value].lower_bound
   if lower_bound === nothing
      lower_bound = gt.lower
   else
      lower_bound = max(gt.lower, lower_bound)
   end
   model.variable_info[vi.value].lower_bound = lower_bound
   return MOI.ConstraintIndex{MOI.VariableIndex, MOI.GreaterThan{Float64}}(vi.value)
end

function MOI.add_constraint(
   model::Optimizer,
   vi::MOI.VariableIndex,
   eq::MOI.EqualTo{Float64}
)
   check_inbounds(model, vi)
   if isnan(eq.value)
      error("Invalid fixed value $(eq.value).")
   end
   model.variable_info[vi.value].lower_bound = eq.value
   model.variable_info[vi.value].upper_bound = eq.value
   return MOI.ConstraintIndex{MOI.VariableIndex, MOI.EqualTo{Float64}}(vi.value)
end

function MOI.add_constraint(
   model::Optimizer,
   vi::MOI.VariableIndex,
   ::MOI.ZeroOne
)
   check_inbounds(model, vi)
   lower_bound = model.variable_info[vi.value].lower_bound
   upper_bound = model.variable_info[vi.value].upper_bound
   if lower_bound === nothing
      lower_bound = 0
   else
      lower_bound = ceil(max(0, lower_bound))
   end
   if upper_bound === nothing
      upper_bound = 1
   else
      upper_bound = floor(min(1, upper_bound))
   end
   model.variable_info[vi.value].lower_bound = lower_bound
   model.variable_info[vi.value].upper_bound = upper_bound
   model.variable_info[vi.value].type = VARTYPE_BINARY
   return MOI.ConstraintIndex{MOI.VariableIndex, MOI.ZeroOne}(vi.value)
end

function MOI.add_constraint(
   model::Optimizer,
   vi::MOI.VariableIndex,
   ::MOI.Integer
)
   check_inbounds(model, vi)
   lower_bound = model.variable_info[vi.value].lower_bound
   upper_bound = model.variable_info[vi.value].upper_bound
   if lower_bound !== nothing
      lower_bound = ceil(lower_bound)
   end
   if upper_bound !== nothing
      upper_bound = floor(upper_bound)
   end
   model.variable_info[vi.value].lower_bound = lower_bound
   model.variable_info[vi.value].upper_bound = upper_bound
   model.variable_info[vi.value].type = VARTYPE_INTEGER
   return MOI.ConstraintIndex{MOI.VariableIndex, MOI.Integer}(vi.value)
end

function MOI.add_constraint(
   model::Optimizer,
   vi::MOI.VariableIndex,
   sc::MOI.Semicontinuous{Float64}
)
   check_inbounds(model, vi)
   model.variable_info[vi.value].type = VARTYPE_SEMICONT
   model.variable_info[vi.value].lower_bound = sc.lower
   model.variable_info[vi.value].upper_bound = sc.upper
   return MOI.ConstraintIndex{MOI.VariableIndex, MOI.Semicontinuous{Float64}}(vi.value)
end

function MOI.add_constraint(
   model::Optimizer,
   vi::MOI.VariableIndex,
   si::MOI.Semiinteger{Float64}
)
   check_inbounds(model, vi)
   model.variable_info[vi.value].type = VARTYPE_SEMIINT
   model.variable_info[vi.value].lower_bound = si.lower
   model.variable_info[vi.value].upper_bound = si.upper
   return MOI.ConstraintIndex{MOI.VariableIndex, MOI.Semiinteger{Float64}}(vi.value)
end

function MOI.add_constraint(
   model::Optimizer,
   v::MOI.VectorOfVariables,
   sos::MOI.SOS1{Float64}
)
   check_inbounds(model, v)
   push!(model.sos1_constraints, ConstraintInfo(v, sos))
   n = length(model.sos1_constraints)
   return MOI.ConstraintIndex{MOI.VectorOfVariables, MOI.SOS1{Float64}}(n)
end

function MOI.add_constraint(
   model::Optimizer,
   v::MOI.VectorOfVariables,
   sos::MOI.SOS2{Float64}
)
   perm = sortperm(sos.weights)
   sos_sort = MOI.SOS2{Float64}(sos.weights[perm])
   v_sort = MOI.VectorOfVariables(v.variables[perm])
   check_inbounds(model, v)
   push!(model.sos2_constraints, ConstraintInfo(v_sort, sos_sort))
   n = length(model.sos2_constraints)
   return MOI.ConstraintIndex{MOI.VectorOfVariables, MOI.SOS2{Float64}}(n)
end

function check_inbounds(
   model::Optimizer,
   vi::MOI.VariableIndex
)
   nvar = length(model.variable_info)
   if !(1 <= vi.value <= nvar)
      error("Invalid variable index: $vi ∉ [1,$nvar].")
   end
end

function check_inbounds(
   model::Optimizer,
   var::MOI.VectorOfVariables
)
   for vi in var.variables
      check_inbounds(model, vi)
   end
end

function check_inbounds(
   model::Optimizer,
   aff::MOI.ScalarAffineFunction
)
   for term in aff.terms
      check_inbounds(model, term.variable)
   end
end

function check_inbounds(
   model::Optimizer,
   quad::MOI.ScalarQuadraticFunction
)
   for term in quad.affine_terms
      check_inbounds(model, term.variable)
   end
   for term in quad.quadratic_terms
      check_inbounds(model, term.variable_1)
      check_inbounds(model, term.variable_2)
   end
end

function check_inbounds(
   model::Optimizer,
   vaf::MOI.VectorAffineFunction
)
   for vi in vaf.terms
      check_inbounds(model, vi.scalar_term)
   end
end

function check_inbounds(
   model::Optimizer,
   aft::MOI.ScalarAffineTerm
)
   return check_inbounds(model, aft.variable)
end

function MOI.get(
   model::Optimizer,
   ::MOI.ConstraintSet,
   ci::MOI.ConstraintIndex{MOI.VariableIndex, MOI.LessThan{Float64}}
)
   vi = MOI.VariableIndex(ci.value)
   check_inbounds(model, vi)
   if ! _has_upper_bound(model, vi)
      error("Variable $vi has no upper bound -- ConstraintSet not defined.")
   end
   return MOI.LessThan(model.variable_info[vi.value].upper_bound)
end

function MOI.get(
   model::Optimizer,
   ::MOI.ConstraintSet,
   ci::MOI.ConstraintIndex{MOI.VariableIndex, MOI.GreaterThan{Float64}}
)
   vi = MOI.VariableIndex(ci.value)
   check_inbounds(model, vi)
   if ! _has_lower_bound(model, vi)
      error("Variable $vi has no lower bound -- ConstraintSet not defined.")
   end
   return MOI.GreaterThan(model.variable_info[vi.value].lower_bound)
end

function MOI.get(
   model::Optimizer,
   ::MOI.ConstraintSet,
   ci::MOI.ConstraintIndex{MOI.VariableIndex, MOI.EqualTo{Float64}}
)
   vi = MOI.VariableIndex(ci.value)
   check_inbounds(model, vi)
   if ! _is_fixed(model, vi)
      error("Variable $vi is not fixed -- ConstraintSet not defined.")
   end
   return MOI.EqualTo(model.variable_info[vi.value].lower_bound)
end

function MOI.get(
   model::Optimizer,
   attr::MOI.VariablePrimal,
   vi::MOI.VariableIndex
)
   MOI.check_result_index_bounds(model, attr)
   check_inbounds(model, vi)
   try
      return model.sol.var[variable_name(model, vi)].level[1]
   catch
      return 0
   end
end

function MOI.get(
   model::Optimizer,
   attr::MOI.ConstraintPrimal,
   ci::MOI.ConstraintIndex{MOI.VariableIndex, MOI.LessThan{Float64}}
)
   MOI.check_result_index_bounds(model, attr)
   vi = MOI.VariableIndex(ci.value)
   check_inbounds(model, vi)
   if ! _has_upper_bound(model, vi)
      error("Variable $vi has no upper bound -- ConstraintPrimal not defined.")
   end
   try
      return model.sol.var[variable_name(model, vi)].level[1]
   catch
      return 0
   end
end

function MOI.get(
   model::Optimizer,
   attr::MOI.ConstraintPrimal,
   ci::MOI.ConstraintIndex{MOI.VariableIndex, MOI.GreaterThan{Float64}}
)
   MOI.check_result_index_bounds(model, attr)
   vi = MOI.VariableIndex(ci.value)
   check_inbounds(model, vi)
   if ! _has_lower_bound(model, vi)
      error("Variable $vi has no lower bound -- ConstraintPrimal not defined.")
   end
   try
      return model.sol.var[variable_name(model, vi)].level[1]
   catch
      return 0
   end
end

function MOI.get(
   model::Optimizer,
   attr::MOI.ConstraintPrimal,
   ci::MOI.ConstraintIndex{MOI.VariableIndex, MOI.EqualTo{Float64}}
)
   MOI.check_result_index_bounds(model, attr)
   vi = MOI.VariableIndex(ci.value)
   check_inbounds(model, vi)
   if ! _is_fixed(model, vi)
      error("Variable $vi is not fixed -- ConstraintPrimal not defined.")
   end
   try
      return model.sol.var[variable_name(model, vi)].level[1]
   catch
      return 0
   end
end

function MOI.get(
   model::Optimizer,
   attr::MOI.ConstraintDual,
   ci::MOI.ConstraintIndex{MOI.VariableIndex, MOI.LessThan{Float64}}
)
   MOI.check_result_index_bounds(model, attr)
   vi = MOI.VariableIndex(ci.value)
   check_inbounds(model, vi)
   if ! _has_upper_bound(model, vi)
      error("Variable $vi has no upper bound -- ConstraintDual not defined.")
   end
   s = _dual_multiplier(model)
   try
      return s * model.sol.var[variable_name(model, vi)].dual[1]
   catch
      return 0
   end
end

function MOI.get(
   model::Optimizer,
   attr::MOI.ConstraintDual,
   ci::MOI.ConstraintIndex{MOI.VariableIndex, MOI.GreaterThan{Float64}}
)
   MOI.check_result_index_bounds(model, attr)
   vi = MOI.VariableIndex(ci.value)
   check_inbounds(model, vi)
   if ! _has_lower_bound(model, vi)
      error("Variable $vi has no lower bound -- ConstraintDual not defined.")
   end
   if _is_fixed(model, vi)
      return 0.0
   else
      s = _dual_multiplier(model)
      try
         return s * model.sol.var[variable_name(model, vi)].dual[1]
      catch
         return 0
      end
   end
end

function MOI.get(
   model::Optimizer,
   attr::MOI.ConstraintDual,
   ci::MOI.ConstraintIndex{MOI.VariableIndex, MOI.EqualTo{Float64}}
)
   MOI.check_result_index_bounds(model, attr)
   vi = MOI.VariableIndex(ci.value)
   check_inbounds(model, vi)
   if ! _is_fixed(model, vi)
      error("Variable $vi is not fixed -- ConstraintDual not defined.")
   end
   try
      s = _dual_multiplier(model)
      return s * model.sol.var[variable_name(model, vi)].dual[1]
   catch
      return 0
   end
end
