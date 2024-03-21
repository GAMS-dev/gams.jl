
struct GeneratedConstraintName <: MOI.AbstractConstraintAttribute end

struct OriginalConstraintName <: MOI.AbstractModelAttribute
    name::String
end

MOI.supports(::Optimizer, ::OriginalConstraintName) = true

function MOI.get(model::Optimizer, attr::OriginalConstraintName)
    for (i, c) in enumerate(model.constraints)
        if gms_name(MOI.ConstraintIndex{typeof(c.func), typeof(c.set)}(i)) == attr.name
            return c.name
        end
    end
    return nothing
end

#####################################################################
##  Variable Type Constraints                                      ##
#####################################################################

MOI.supports_constraint(::Optimizer, ::Type{MOI.VariableIndex}, ::Type{MOI.ZeroOne}) = true

function MOI.add_constraint(model::Optimizer, vi::MOI.VariableIndex, ::MOI.ZeroOne)
    check_inbounds(model, vi)
    model.variables[vi.value].type = :Binary
    model.variables[vi.value].lower_bound =
        max(0, min(1, ceil(model.variables[vi.value].lower_bound)))
    model.variables[vi.value].upper_bound =
        max(0, min(1, floor(model.variables[vi.value].upper_bound)))
    return MOI.ConstraintIndex{MOI.VariableIndex, MOI.ZeroOne}(vi.value)
end

MOI.supports_constraint(::Optimizer, ::Type{MOI.VariableIndex}, ::Type{MOI.Integer}) = true

function MOI.add_constraint(model::Optimizer, vi::MOI.VariableIndex, ::MOI.Integer)
    check_inbounds(model, vi)
    model.variables[vi.value].type = :Integer
    model.variables[vi.value].lower_bound = ceil(model.variables[vi.value].lower_bound)
    model.variables[vi.value].upper_bound = floor(model.variables[vi.value].upper_bound)
    return MOI.ConstraintIndex{MOI.VariableIndex, MOI.Integer}(vi.value)
end

MOI.supports_constraint(
    ::Optimizer,
    ::Type{MOI.VariableIndex},
    ::Type{MOI.Semicontinuous{Float64}},
) = true

function MOI.add_constraint(
    model::Optimizer,
    vi::MOI.VariableIndex,
    set::MOI.Semicontinuous{Float64},
)
    check_inbounds(model, vi)
    model.variables[vi.value].type = :SemiCont
    model.variables[vi.value].lower_bound = set.lower
    model.variables[vi.value].upper_bound = set.upper
    return MOI.ConstraintIndex{MOI.VariableIndex, MOI.Semicontinuous{Float64}}(vi.value)
end

MOI.supports_constraint(::Optimizer, ::Type{MOI.VariableIndex}, ::Type{MOI.Semiinteger{Float64}}) =
    true

function MOI.add_constraint(model::Optimizer, vi::MOI.VariableIndex, set::MOI.Semiinteger{Float64})
    check_inbounds(model, vi)
    model.variables[vi.value].type = :SemiInt
    model.variables[vi.value].lower_bound = ceil(set.lower)
    model.variables[vi.value].upper_bound = floor(set.upper)
    return MOI.ConstraintIndex{MOI.VariableIndex, MOI.Semiinteger{Float64}}(vi.value)
end

#####################################################################
##  Variable Bound Constraints                                     ##
#####################################################################

function MOI.supports_constraint(
    ::Optimizer,
    ::Type{MOI.VariableIndex},
    ::Type{S},
) where {S <: Union{MOI.LessThan{Float64}, MOI.GreaterThan{Float64}, MOI.EqualTo{Float64}}}
    return true
end

function MOI.add_constraint(model::Optimizer, vi::MOI.VariableIndex, set::MOI.LessThan{Float64})
    check_inbounds(model, vi)
    if isnan(set.upper)
        error("Invalid upper bound value $(set.upper).")
    end
    model.variables[vi.value].upper_bound = min(model.variables[vi.value].upper_bound, set.upper)
    return MOI.ConstraintIndex{MOI.VariableIndex, MOI.LessThan{Float64}}(vi.value)
end

function MOI.add_constraint(model::Optimizer, vi::MOI.VariableIndex, set::MOI.GreaterThan{Float64})
    check_inbounds(model, vi)
    if isnan(set.lower)
        error("Invalid lower bound value $(set.lower).")
    end
    model.variables[vi.value].lower_bound = max(model.variables[vi.value].lower_bound, set.lower)
    return MOI.ConstraintIndex{MOI.VariableIndex, MOI.GreaterThan{Float64}}(vi.value)
end

function MOI.add_constraint(model::Optimizer, vi::MOI.VariableIndex, set::MOI.EqualTo{Float64})
    check_inbounds(model, vi)
    if isnan(set.value)
        error("Invalid fixed value $(set.value).")
    end
    model.variables[vi.value].lower_bound = set.value
    model.variables[vi.value].upper_bound = set.value
    return MOI.ConstraintIndex{MOI.VariableIndex, MOI.EqualTo{Float64}}(vi.value)
end

function MOI.get(
    model::Optimizer,
    attr::MOI.ConstraintPrimal,
    ci::MOI.ConstraintIndex{MOI.VariableIndex, S},
) where {S <: Union{MOI.LessThan{Float64}, MOI.GreaterThan{Float64}, MOI.EqualTo{Float64}}}
    MOI.check_result_index_bounds(model, attr)
    vi = MOI.VariableIndex(ci.value)
    check_inbounds(model, vi)
    try
        return model.solution.var[gms_name(vi)].level[1]
    catch
        return NaN
    end
end

function MOI.get(
    model::Optimizer,
    attr::MOI.ConstraintDual,
    ci::MOI.ConstraintIndex{MOI.VariableIndex, S},
) where {S <: Union{MOI.LessThan{Float64}, MOI.GreaterThan{Float64}, MOI.EqualTo{Float64}}}
    MOI.check_result_index_bounds(model, attr)
    vi = MOI.VariableIndex(ci.value)
    check_inbounds(model, vi)
    if model.variables[vi.value].lower_bound == model.variables[vi.value].upper_bound &&
       S == MOI.GreaterThan{Float64}
        return 0.0
    end
    s = model.sense == MOI.MIN_SENSE ? 1.0 : -1.0
    try
        return s * model.solution.var[gms_name(vi)].dual[1]
    catch
        return NaN
    end
end

#####################################################################
##  Scalar Function + (<=, >=, ==) Constraints                     ##
#####################################################################

const SupportedScalarConstraintFunctions{T} =
    Union{MOI.ScalarAffineFunction{T}, MOI.ScalarQuadraticFunction{T}}

const SupportedScalarConstraintSets{T} = Union{MOI.LessThan{T}, MOI.GreaterThan{T}, MOI.EqualTo{T}}

function check_inbounds(
    model::Optimizer,
    ci::MOI.ConstraintIndex{F, S},
) where {
    F <: SupportedScalarConstraintFunctions{Float64},
    S <: SupportedScalarConstraintSets{Float64},
}
    if !(1 <= ci.value <= length(model.constraints))
        error("Invalid constraint index ", ci.value)
    end
end

function MOI.supports_constraint(
    ::Optimizer,
    ::Type{<:SupportedScalarConstraintFunctions{Float64}},
    ::Type{<:SupportedScalarConstraintSets{Float64}},
)
    return true
end

function MOI.add_constraint(
    model::Optimizer,
    func::F,
    set::S,
) where {
    F <: SupportedScalarConstraintFunctions{Float64},
    S <: SupportedScalarConstraintSets{Float64},
}
    check_inbounds(model, func)
    push!(model.constraints, ConstraintInfo(func, set))
    return MOI.ConstraintIndex{F, S}(length(model.constraints))
end

function MOI.get(
    model::Optimizer,
    ::MOI.NumberOfConstraints{F, S},
) where {
    F <: SupportedScalarConstraintFunctions{Float64},
    S <: SupportedScalarConstraintSets{Float64},
}
    n = 0
    for c in values(model.constraints)
        if c.func isa F && c.set isa S
            n += 1
        end
    end
    return n
end

function MOI.supports(
    ::Optimizer,
    ::MOI.ConstraintName,
    ::Type{MOI.ConstraintIndex{F, S}},
) where {
    F <: SupportedScalarConstraintFunctions{Float64},
    S <: SupportedScalarConstraintSets{Float64},
}
    return true
end

function MOI.get(
    model::Optimizer,
    ::MOI.ConstraintName,
    ci::MOI.ConstraintIndex{F, S},
) where {
    F <: SupportedScalarConstraintFunctions{Float64},
    S <: SupportedScalarConstraintSets{Float64},
}
    check_inbounds(model, ci)
    return model.constraints[ci.value].name
end

function MOI.set(
    model::Optimizer,
    attr::MOI.ConstraintName,
    ci::MOI.ConstraintIndex{F, S},
    value,
) where {
    F <: SupportedScalarConstraintFunctions{Float64},
    S <: SupportedScalarConstraintSets{Float64},
}
    check_inbounds(model, ci)
    model.constraints[ci.value].name = value
    return
end

function MOI.get(
    model::Optimizer,
    ::MOI.ConstraintFunction,
    ci::MOI.ConstraintIndex{F, S},
) where {
    F <: SupportedScalarConstraintFunctions{Float64},
    S <: SupportedScalarConstraintSets{Float64},
}
    check_inbounds(model, ci)
    return model.constraints[ci.value].func
end

function MOI.get(
    model::Optimizer,
    ::MOI.ConstraintSet,
    ci::MOI.ConstraintIndex{F, S},
) where {
    F <: SupportedScalarConstraintFunctions{Float64},
    S <: SupportedScalarConstraintSets{Float64},
}
    check_inbounds(model, ci)
    return model.constraints[ci.value].set
end

function MOI.get(
    model::Optimizer,
    attr::MOI.ConstraintPrimal,
    ci::MOI.ConstraintIndex{F, S},
) where {
    F <: SupportedScalarConstraintFunctions{Float64},
    S <: SupportedScalarConstraintSets{Float64},
}
    MOI.check_result_index_bounds(model, attr)
    check_inbounds(model, ci)
    return model.solution.equ[gms_name(ci)].level[1]
end

function MOI.get(
    model::Optimizer,
    attr::MOI.ConstraintDual,
    ci::MOI.ConstraintIndex{F, S},
) where {
    F <: SupportedScalarConstraintFunctions{Float64},
    S <: SupportedScalarConstraintSets{Float64},
}
    MOI.check_result_index_bounds(model, attr)
    check_inbounds(model, ci)
    s = model.sense == MOI.MIN_SENSE ? 1.0 : -1.0
    return s * model.solution.equ[gms_name(ci)].dual[1]
end

function gms_name(
    ci::MOI.ConstraintIndex{F, S},
) where {
    F <: SupportedScalarConstraintFunctions{Float64},
    S <: SupportedScalarConstraintSets{Float64},
}
    return "eq$(ci.value)"
end

function MOI.supports(
    ::Optimizer,
    ::GeneratedConstraintName,
    ::Type{MOI.ConstraintIndex{F, S}},
) where {
    F <: SupportedScalarConstraintFunctions{Float64},
    S <: SupportedScalarConstraintSets{Float64},
}
    return true
end

function MOI.get(
    model::Optimizer,
    ::GeneratedConstraintName,
    ci::MOI.ConstraintIndex{F, S},
) where {
    F <: SupportedScalarConstraintFunctions{Float64},
    S <: SupportedScalarConstraintSets{Float64},
}
    return gms_name(ci)
end

#####################################################################
##  SOS Constraints                                                ##
#####################################################################

MOI.supports_constraint(::Optimizer, ::Type{MOI.VectorOfVariables}, ::Type{MOI.SOS1{Float64}}) =
    true

function MOI.add_constraint(model::Optimizer, func::MOI.VectorOfVariables, set::MOI.SOS1{Float64})
    check_inbounds(model, func)
    push!(model.sos_constraints, ConstraintInfo(func, set))
    n = length(model.sos_constraints)
    return MOI.ConstraintIndex{MOI.VectorOfVariables, MOI.SOS1{Float64}}(n)
end

gms_name(ci::MOI.ConstraintIndex{MOI.VectorOfVariables, MOI.SOS1{Float64}}) = "sos_$(ci.value)"

MOI.supports_constraint(::Optimizer, ::Type{MOI.VectorOfVariables}, ::Type{MOI.SOS2{Float64}}) =
    true

function MOI.add_constraint(model::Optimizer, func::MOI.VectorOfVariables, set::MOI.SOS2{Float64})
    check_inbounds(model, func)
    perm = sortperm(set.weights)
    func_sort = MOI.VectorOfVariables(func.variables[perm])
    set_sort = MOI.SOS2{Float64}(set.weights[perm])
    push!(model.sos_constraints, ConstraintInfo(func_sort, set_sort))
    n = length(model.sos_constraints)
    return MOI.ConstraintIndex{MOI.VectorOfVariables, MOI.SOS2{Float64}}(n)
end

gms_name(ci::MOI.ConstraintIndex{MOI.VectorOfVariables, MOI.SOS2{Float64}}) = "sos_$(ci.value)"

#####################################################################
##  Complementarity Constraints                                    ##
#####################################################################

function check_inbounds(
    model::Optimizer,
    ci::MOI.ConstraintIndex{MOI.VectorAffineFunction{Float64}, MOI.Complements},
)
    if !(1 <= ci.value <= length(model.compl_constraints))
        error("Invalid constraint index ", ci.value)
    end
end

MOI.supports_constraint(
    ::Optimizer,
    ::Type{MOI.VectorAffineFunction{Float64}},
    ::Type{MOI.Complements},
) = true

function MOI.add_constraint(
    model::Optimizer,
    func::MOI.VectorAffineFunction{Float64},
    set::MOI.Complements,
)
    check_inbounds(model, func)
    push!(model.compl_constraints, ConstraintInfo(func, set))
    n = length(model.compl_constraints)
    return MathOptInterface.ConstraintIndex{MOI.VectorAffineFunction{Float64}, MOI.Complements}(n)
end

function MOI.get(
    model::Optimizer,
    ::MOI.NumberOfConstraints{MOI.VectorAffineFunction{Float64}, MOI.Complements},
)
    return length(model.compl_constraints)
end

function MOI.get(
    model::Optimizer,
    ::MOI.ConstraintName,
    ci::MOI.ConstraintIndex{MOI.VectorAffineFunction{Float64}, MOI.Complements},
)
    check_inbounds(model, ci)
    return model.compl_constraints[ci.value].name
end

function MOI.set(
    model::Optimizer,
    attr::MOI.ConstraintName,
    ci::MOI.ConstraintIndex{MOI.VectorAffineFunction{Float64}, MOI.Complements},
    value,
)
    check_inbounds(model, ci)
    return model.compl_constraints[ci.value].name = value
end

#####################################################################
##  Nonlinear Block Constraints                                    ##
#####################################################################

MOI.supports(::Optimizer, ::MOI.NLPBlock) = true
MOI.supports(::Optimizer, ::MOI.NLPBlockDual) = true

function MOI.set(model::Optimizer, ::MOI.NLPBlock, nlp_data::MOI.NLPBlockData)
    model.nlp_data = nlp_data
    MOI.initialize(model.nlp_data.evaluator, [:ExprGraph])
    return
end

function MOI.get(model::Optimizer, attr::MOI.NLPBlockDual)
    MOI.check_result_index_bounds(model, attr)
    values = zeros(length(model.nlp_data.constraint_bounds))
    s = model.sense == MOI.MIN_SENSE ? 1.0 : -1.0
    for i in 1:length(model.nlp_data.constraint_bounds)
        values[i] = s * model.solution.equ["nlp_eq$i"].dual[1]
    end
    return values
end

#####################################################################
##  Constraints Statistics                                         ##
#####################################################################

function MOI.get(model::Optimizer, ::MOI.ListOfConstraintTypesPresent)
    types = Set{Tuple{Type, Type}}()
    for v in model.variables
        if v.type == :Binary
            push!(types, (MOI.VariableIndex, MOI.ZeroOne))
        elseif v.type == :Integer
            push!(types, (MOI.VariableIndex, MOI.Integer))
        elseif v.type == :SemiCont
            push!(types, (MOI.VariableIndex, MOI.Semicontinuous{Float64}))
        elseif v.type == :SemiInt
            push!(types, (MOI.VariableIndex, MOI.Semiinteger{Float64}))
        end

        if v.lower_bound == v.upper_bound
            push!(types, (MOI.VariableIndex, MOI.EqualTo{Float64}))
        else
            if !isinf(v.lower_bound)
                push!(types, (MOI.VariableIndex, MOI.GreaterThan{Float64}))
            end
            if !isinf(v.upper_bound)
                push!(types, (MOI.VariableIndex, MOI.LessThan{Float64}))
            end
        end
    end
    for c in model.constraints
        push!(types, (typeof(c.func), typeof(c.set)))
    end
    for c in model.sos_constraints
        push!(types, (typeof(c.func), typeof(c.set)))
    end
    for c in model.compl_constraints
        push!(types, (typeof(c.func), typeof(c.set)))
    end
    return collect(types)
end
