
MOI.supports(::Optimizer, ::MOI.ObjectiveFunction{MOI.VariableIndex}) = true
MOI.supports(::Optimizer, ::MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}) = true
MOI.supports(::Optimizer, ::MOI.ObjectiveFunction{MOI.ScalarQuadraticFunction{Float64}}) = true

function MOI.set(
    model::Optimizer,
    ::MOI.ObjectiveFunction,
    func::Union{MOI.VariableIndex, MOI.ScalarAffineFunction, MOI.ScalarQuadraticFunction},
)
    check_inbounds(model, func)
    model.objective = func
    return
end

MOI.supports(::Optimizer, ::MOI.ObjectiveSense) = true

MOI.get(model::Optimizer, ::MOI.ObjectiveSense) = model.sense

function MOI.set(model::Optimizer, ::MOI.ObjectiveSense, sense::MOI.OptimizationSense)
    model.sense = sense
    if sense == MOI.FEASIBILITY_SENSE
        model.objective = nothing
    end
    return
end

MOI.supports(::Optimizer, ::MOI.ObjectiveValue) = true

function MOI.get(model::Optimizer, attr::MOI.ObjectiveValue)
    MOI.check_result_index_bounds(model, attr)
    return model.objective_value
end

MOI.supports(::Optimizer, ::MOI.ObjectiveBound) = true

MOI.get(model::Optimizer, ::MOI.ObjectiveBound) = model.objective_bound

MOI.supports(::Optimizer, ::MOI.RelativeGap) = true

function MOI.get(model::Optimizer, ::MOI.RelativeGap)
    return abs(model.objective_value - model.objective_bound) /
           max(abs(model.objective_value), abs(model.objective_bound))
end
