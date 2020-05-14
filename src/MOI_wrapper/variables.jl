
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
   ::MOI.NumberOfConstraints{MOI.SingleVariable, MOI.LessThan{Float64}}
)
   n = 0
   for var in model.variable_info
      if has_upper_bound(var)
         n += 1
      end
   end
   return n
end

function MOI.get(
   model::Optimizer, 
   ::MOI.NumberOfConstraints{MOI.SingleVariable, MOI.GreaterThan{Float64}}
)
   n = 0
   for var in model.variable_info
      if has_lower_bound(var)
         n += 1
      end
   end
   return n
end

function MOI.get(
   model::Optimizer, 
   ::MOI.NumberOfConstraints{MOI.SingleVariable, MOI.EqualTo{Float64}}
)
   n = 0
   for var in model.variable_info
      if is_fixed(var)
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
   v::MOI.SingleVariable,
   lt::MOI.LessThan{Float64}
)
   vi = v.variable
   check_inbounds(model, vi)
   if isnan(lt.upper)
      error("Invalid upper bound value $(lt.upper).")
   end
   if has_upper_bound(model, vi)
      error("Upper bound on variable $vi already exists.")
   end
   if is_fixed(model, vi)
      error("Variable $vi is fixed. Cannot also set upper bound.")
   end
   model.variable_info[vi.value].upper_bound = lt.upper
   return MOI.ConstraintIndex{MOI.SingleVariable, MOI.LessThan{Float64}}(vi.value)
end

function MOI.add_constraint(
   model::Optimizer,
   v::MOI.SingleVariable,
   gt::MOI.GreaterThan{Float64}
)
   vi = v.variable
   check_inbounds(model, vi)
   if isnan(gt.lower)
      error("Invalid lower bound value $(gt.lower).")
   end
   if has_lower_bound(model, vi)
      error("Lower bound on variable $vi already exists.")
   end
   if is_fixed(model, vi)
      error("Variable $vi is fixed. Cannot also set lower bound.")
   end
   model.variable_info[vi.value].lower_bound = gt.lower
   return MOI.ConstraintIndex{MOI.SingleVariable, MOI.GreaterThan{Float64}}(vi.value)
end

function MOI.add_constraint(
   model::Optimizer,
   v::MOI.SingleVariable,
   eq::MOI.EqualTo{Float64}
)
   vi = v.variable
   check_inbounds(model, vi)
   if isnan(eq.value)
      error("Invalid fixed value $(eq.value).")
   end
   if has_lower_bound(model, vi)
      error("Variable $vi has a lower bound. Cannot be fixed.")
   end
   if has_upper_bound(model, vi)
      error("Variable $vi has an upper bound. Cannot be fixed.")
   end
   if is_fixed(model, vi)
      error("Variable $vi is already fixed.")
   end
   model.variable_info[vi.value].lower_bound = eq.value
   model.variable_info[vi.value].upper_bound = eq.value
   return MOI.ConstraintIndex{MOI.SingleVariable, MOI.EqualTo{Float64}}(vi.value)
end

function MOI.add_constraint(
   model::Optimizer, 
   v::MOI.SingleVariable, 
   ::MOI.ZeroOne
)
   vi = v.variable
   check_inbounds(model, vi)
   model.variable_info[vi.value].lower_bound = 0
   model.variable_info[vi.value].upper_bound = 1
   model.variable_info[vi.value].type = VARTYPE_BINARY
   return MOI.ConstraintIndex{MOI.SingleVariable, MOI.ZeroOne}(vi.value)
end

function MOI.add_constraint(
   model::Optimizer, 
   v::MOI.SingleVariable, 
   ::MOI.Integer
)
   vi = v.variable
   check_inbounds(model, vi)
   model.variable_info[vi.value].type = VARTYPE_INTEGER
   return MOI.ConstraintIndex{MOI.SingleVariable, MOI.Integer}(vi.value)
end

function MOI.add_constraint(
   model::Optimizer, 
   v::MOI.SingleVariable, 
   sc::MOI.Semicontinuous{Float64}
)
   vi = v.variable
   check_inbounds(model, vi)
   model.variable_info[vi.value].type = VARTYPE_SEMICONT
   model.variable_info[vi.value].lower_bound = sc.lower
   model.variable_info[vi.value].upper_bound = sc.upper
   return MOI.ConstraintIndex{MOI.SingleVariable, MOI.Semicontinuous{Float64}}(vi.value)
end

function MOI.add_constraint(
   model::Optimizer, 
   v::MOI.SingleVariable, 
   si::MOI.Semiinteger{Float64}
)
   vi = v.variable
   check_inbounds(model, vi)
   model.variable_info[vi.value].type = VARTYPE_SEMIINT
   model.variable_info[vi.value].lower_bound = si.lower
   model.variable_info[vi.value].upper_bound = si.upper
   return MOI.ConstraintIndex{MOI.SingleVariable, MOI.Semiinteger{Float64}}(vi.value)
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
   var::MOI.SingleVariable
)
   return check_inbounds(model, var.variable)
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
      check_inbounds(model, term.variable_index)
   end
end

function check_inbounds(
   model::Optimizer,
   quad::MOI.ScalarQuadraticFunction
)
   for term in quad.affine_terms
      check_inbounds(model, term.variable_index)
   end
   for term in quad.quadratic_terms
      check_inbounds(model, term.variable_index_1)
      check_inbounds(model, term.variable_index_2)
   end
end

function MOI.get(
   model::Optimizer,
   ::MOI.ConstraintSet,
   ci::MOI.ConstraintIndex{MOI.SingleVariable, MOI.LessThan{Float64}}
)
   vi = MOI.VariableIndex(ci.value)
   check_inbounds(model, vi)
   if ! has_upper_bound(model, vi)
      error("Variable $vi has no upper bound -- ConstraintSet not defined.")
   end
   return MOI.LessThan(model.variable_info[vi.value].upper_bound)
end

function MOI.get(
   model::Optimizer,
   ::MOI.ConstraintSet,
   ci::MOI.ConstraintIndex{MOI.SingleVariable, MOI.GreaterThan{Float64}}
)
   vi = MOI.VariableIndex(ci.value)
   check_inbounds(model, vi)
   if ! has_lower_bound(model, vi)
      error("Variable $vi has no lower bound -- ConstraintSet not defined.")
   end
   return MOI.GreaterThan(model.variable_info[vi.value].lower_bound)
end

function MOI.get(
   model::Optimizer,
   ::MOI.ConstraintSet,
   ci::MOI.ConstraintIndex{MOI.SingleVariable, MOI.EqualTo{Float64}}
)
   vi = MOI.VariableIndex(ci.value)
   check_inbounds(model, vi)
   if ! is_fixed(model, vi)
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
   if model.objvar
      return model.sol.x[1 + vi.value]
   else
      return model.sol.x[vi.value]
   end
end

function MOI.get(
   model::Optimizer,
   attr::MOI.ConstraintPrimal,
   ci::MOI.ConstraintIndex{MOI.SingleVariable, MOI.LessThan{Float64}}
)
   MOI.check_result_index_bounds(model, attr)
   vi = MOI.VariableIndex(ci.value)
   check_inbounds(model, vi)
   if ! has_upper_bound(model, vi)
      error("Variable $vi has no upper bound -- ConstraintPrimal not defined.")
   end
   if model.objvar
      return model.sol.x[1 + vi.value]
   else
      return model.sol.x[vi.value]
   end
end

function MOI.get(
   model::Optimizer,
   attr::MOI.ConstraintPrimal,
   ci::MOI.ConstraintIndex{MOI.SingleVariable, MOI.GreaterThan{Float64}}
)
   MOI.check_result_index_bounds(model, attr)
   vi = MOI.VariableIndex(ci.value)
   check_inbounds(model, vi)
   if ! has_lower_bound(model, vi)
      error("Variable $vi has no lower bound -- ConstraintPrimal not defined.")
   end
   if model.objvar
      return model.sol.x[1 + vi.value]
   else
      return model.sol.x[vi.value]
   end
end

function MOI.get(
   model::Optimizer,
   attr::MOI.ConstraintPrimal,
   ci::MOI.ConstraintIndex{MOI.SingleVariable, MOI.EqualTo{Float64}}
)
   MOI.check_result_index_bounds(model, attr)
   vi = MOI.VariableIndex(ci.value)
   check_inbounds(model, vi)
   if ! is_fixed(model, vi)
      error("Variable $vi is not fixed -- ConstraintPrimal not defined.")
   end
   if model.objvar
      return model.sol.x[1 + vi.value]
   else
      return model.sol.x[vi.value]
   end
end

function MOI.get(
   model::Optimizer, 
   attr::MOI.ConstraintDual,
   ci::MOI.ConstraintIndex{MOI.SingleVariable, MOI.LessThan{Float64}}
)
   MOI.check_result_index_bounds(model, attr)
   vi = MOI.VariableIndex(ci.value)
   check_inbounds(model, vi)
   if ! has_upper_bound(model, vi)
      error("Variable $vi has no upper bound -- ConstraintDual not defined.")
   end
   if model.objvar
      return -1 * model.sol.x_dual[1 + vi.value]
   else
      return -1 * model.sol.x_dual[vi.value]
   end
end

function MOI.get(
   model::Optimizer, 
   attr::MOI.ConstraintDual,
   ci::MOI.ConstraintIndex{MOI.SingleVariable, MOI.GreaterThan{Float64}}
)
   MOI.check_result_index_bounds(model, attr)
   vi = MOI.VariableIndex(ci.value)
   check_inbounds(model, vi)
   if ! has_lower_bound(model, vi)
      error("Variable $vi has no lower bound -- ConstraintDual not defined.")
   end
   if is_fixed(model, vi)
      return 0.0
   elseif model.objvar
      return model.sol.x_dual[1 + vi.value]
   else
      return model.sol.x_dual[vi.value]
   end
end

function MOI.get(
   model::Optimizer, 
   attr::MOI.ConstraintDual,
   ci::MOI.ConstraintIndex{MOI.SingleVariable, MOI.EqualTo{Float64}}
)
   MOI.check_result_index_bounds(model, attr)
   vi = MOI.VariableIndex(ci.value)
   check_inbounds(model, vi)
   if ! is_fixed(model, vi)
      error("Variable $vi is not fixed -- ConstraintDual not defined.")
   end
   if model.objvar
      return model.sol.x_dual[1 + vi.value]
   else
      return model.sol.x_dual[vi.value]
   end
end
