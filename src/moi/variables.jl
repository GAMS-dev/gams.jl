
#####################################################################
##  Adding Variables and Variable Index                            ##
#####################################################################

function MOI.add_variable(model::Optimizer)
    push!(model.variables, VariableInfo())
    return MOI.VariableIndex(length(model.variables))
end

MOI.add_variables(model::Optimizer, n::Int) = [MOI.add_variable(model) for i in 1:n]

function MOI.get(model::Optimizer, ::Type{MathOptInterface.VariableIndex}, name::String)
    for (i, var) in enumerate(model.variables)
        if name == var.name
            return MOI.VariableIndex(i)
        end
    end
    return error("Unrecognized variable name $name.")
end

function check_inbounds(model::Optimizer, vi::MOI.VariableIndex)
    nvar = length(model.variables)
    if !(1 <= vi.value <= nvar)
        error("Invalid variable index: $vi ∉ [1,$nvar].")
    end
end

check_inbounds(model::Optimizer, var::MOI.VectorOfVariables) =
    for vi in var.variables
        check_inbounds(model, vi)
    end

function check_inbounds(model::Optimizer, aff::MOI.ScalarAffineFunction)
    for term in aff.terms
        check_inbounds(model, term.variable)
    end
end

function check_inbounds(model::Optimizer, quad::MOI.ScalarQuadraticFunction)
    for term in quad.affine_terms
        check_inbounds(model, term.variable)
    end
    for term in quad.quadratic_terms
        check_inbounds(model, term.variable_1)
        check_inbounds(model, term.variable_2)
    end
end

function check_inbounds(model::Optimizer, vaf::MOI.VectorAffineFunction)
    for vi in vaf.terms
        check_inbounds(model, vi.scalar_term)
    end
end

check_inbounds(model::Optimizer, aft::MOI.ScalarAffineTerm) = check_inbounds(model, aft.variable)

gms_name(vi::MOI.VariableIndex) = "x$(vi.value)"

#####################################################################
##  Variable Statistics                                            ##
#####################################################################

MOI.get(model::Optimizer, ::MOI.NumberOfVariables) = length(model.variables)

function MOI.get(model::Optimizer, ::MOI.ListOfVariableIndices)
    return [MOI.VariableIndex(i) for i in 1:length(model.variables)]
end

#####################################################################
##  Variable Attributes                                            ##
#####################################################################

MOI.supports(::Optimizer, ::MOI.VariablePrimalStart, ::Type{MOI.VariableIndex}) = true

function MOI.set(
    model::Optimizer,
    ::MOI.VariablePrimalStart,
    vi::MOI.VariableIndex,
    value::Union{Real, Nothing},
)
    check_inbounds(model, vi)
    model.variables[vi.value].start = value
    return
end

MOI.supports(::Optimizer, ::MOI.VariableName, ::Type{MOI.VariableIndex}) = true

function MOI.set(model::Optimizer, attr::MOI.VariableName, vi::MOI.VariableIndex, value)
    check_inbounds(model, vi)
    return model.variables[vi.value].name = value
end

function MOI.get(model::Optimizer, ::MOI.VariableName, vi::MOI.VariableIndex)
    return model.variables[vi.value].name
end

struct GeneratedVariableName <: MOI.AbstractVariableAttribute end

MOI.supports(::Optimizer, ::GeneratedVariableName, ::Type{MOI.VariableIndex}) = true

MOI.get(model::Optimizer, ::GeneratedVariableName, vi::MOI.VariableIndex) = gms_name(vi)

struct OriginalVariableName <: MOI.AbstractModelAttribute
    name::String
end

MOI.supports(::Optimizer, ::OriginalVariableName) = true

function MOI.get(model::Optimizer, attr::OriginalVariableName)
    for (i, v) in enumerate(model.variables)
        if gms_name(MOI.VariableIndex(i)) == attr.name
            return v.name
        end
    end
    return nothing
end

function MOI.get(model::Optimizer, attr::MOI.VariablePrimal, vi::MOI.VariableIndex)
    MOI.check_result_index_bounds(model, attr)
    check_inbounds(model, vi)
    try
        return model.solution.var[gms_name(vi)].level[1]
    catch
        return max(
            min(0, model.variables[vi.value].upper_bound),
            model.variables[vi.value].lower_bound,
        )
    end
end
