
function MOI.get(
   model::Optimizer,
   ::MOI.ObjectiveSense
)
   return model.sense
end

function MOI.set(
   model::Optimizer,
   ::MOI.ObjectiveSense,
   sense::MOI.OptimizationSense
)
   model.sense = sense
   return
end

function MOI.set(
   model::Optimizer,
   ::MOI.ObjectiveFunction,
   func::Union{MOI.SingleVariable, MOI.ScalarAffineFunction, MOI.ScalarQuadraticFunction}
)
   check_inbounds(model, func)
   model.objective = func
   return
end

function MOI.get(
   model::Optimizer,
   attr::MOI.ObjectiveValue
)
   return model.obj
end

function MOI.get(
   model::Optimizer,
   attr::MOI.ObjectiveBound
)
   return model.obj_est
end
