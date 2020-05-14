
struct type <: MOI.AbstractOptimizerAttribute end
struct reslim <: MOI.AbstractOptimizerAttribute end
struct iterlim <: MOI.AbstractOptimizerAttribute end
struct holdfixed <: MOI.AbstractOptimizerAttribute end
struct nodlim <: MOI.AbstractOptimizerAttribute end
struct optca <: MOI.AbstractOptimizerAttribute end
struct optcr <: MOI.AbstractOptimizerAttribute end
struct solver <: MOI.AbstractOptimizerAttribute end
struct threads <: MOI.AbstractOptimizerAttribute end
struct logoption <: MOI.AbstractOptimizerAttribute end
struct sysdir <: MOI.AbstractOptimizerAttribute end

function MOI.get(
   model::Optimizer,
   opt::Union{reslim, iterlim, holdfixed, nodlim, optca, optcr, solver, threads, logoption, sysdir}
)
   name = replace(string(typeof(opt)), r"(GAMS.)" => "")
   if haskey(model.gams_options, name)
      return model.gams_options[name]
   end
   error("GAMS option '$(name)' is not set.")
end

function MOI.set(
   model::Optimizer,
   opt::Union{reslim, iterlim, holdfixed, nodlim, optca, optcr, solver, threads, logoption, sysdir},
   value
)
   name = replace(string(typeof(opt)), r"(GAMS.)" => "")
   model.gams_options[name] = value
   return
end

function MOI.get(
   model::Optimizer,
   ::type
)
   return label(model.type)
end

function MOI.set(
   model::Optimizer,
   ::type,
   value::String
)
   value = uppercase(value)
   model.type = model_type_from_label(value)
   if model.type == MODEL_TYPE_UNDEFINED
      error("Unsupported model type '$value'.")
   end
   return
end

function MOI.get(
   model::Optimizer,
   ::MOI.Silent
)
   return get(model.gams_options, "logoption", nothing) == 0
end

function MOI.set(
   model::Optimizer,
   ::MOI.Silent,
   silent::Bool
)
   if silent
      MOI.set(model, MOI.RawParameter("logoption"), 0)
   else
      MOI.set(model, MOI.RawParameter("logoption"), 1)
   end
   return
end

function MOI.get(
   model::Optimizer,
   ::MOI.TimeLimitSec
)
   return get(model.gams_options, "reslim", nothing)
end

function MOI.set(
   model::Optimizer,
   ::MOI.TimeLimitSec,
   value::Real
)
   MOI.set(model, MOI.RawParameter("reslim"), Float64(value))
   return
end

function MOI.set(
   model::Optimizer,
   ::MOI.TimeLimitSec,
   ::Nothing
)
   delete!(model.gams_options, "reslim")
   return
end

function MOI.get(
   model::Optimizer,
   ::MOI.NumberOfThreads
)
   return get(model.gams_options, "threads", nothing)
end

function MOI.set(
   model::Optimizer,
   ::MOI.NumberOfThreads,
   value::Int
)
   MOI.set(model, MOI.RawParameter("threads"), value)
   return
end

function MOI.get(
   model::Optimizer,
   option::MOI.RawParameter
)
   name = lowercase(option.name)
   if name in GAMS.MOI_SUPPORTED_CLOPTIONS
      if haskey(model.gams_options, name)
         return model.gams_options[name]
      end
      error("GAMS option '$(option.name)' is not set.")
   else
      if haskey(model.solver_options, option.name)
         return model.solver_options[option.name]
      end
      error("GAMS solver option '$(option.name)' is not set.")
   end
end

function MOI.set(
   model::Optimizer,
   option::MOI.RawParameter,
   value::String
)
   name = lowercase(option.name)

   if name == "type"
      MOI.set(model, type(), value)
      return
   end

   if name in GAMS.MOI_SUPPORTED_CLOPTIONS
      model.gams_options[name] = lowercase(value)
   else
      model.solver_options[option.name] = value
   end
   return
end

function MOI.set(
   model::Optimizer,
   option::MOI.RawParameter,
   value::Number
)
   name = lowercase(option.name)
   if name in GAMS.MOI_SUPPORTED_CLOPTIONS
      model.gams_options[name] = value
   else
      model.solver_options[option.name] = value
   end
   return
end
