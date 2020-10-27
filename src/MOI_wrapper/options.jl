
struct ModelType <: MOI.AbstractOptimizerAttribute end
struct ResLim <: MOI.AbstractOptimizerAttribute end
struct IterLim <: MOI.AbstractOptimizerAttribute end
struct HoldFixed <: MOI.AbstractOptimizerAttribute end
struct NodLim <: MOI.AbstractOptimizerAttribute end
struct OptCA <: MOI.AbstractOptimizerAttribute end
struct OptCR <: MOI.AbstractOptimizerAttribute end
struct Solver <: MOI.AbstractOptimizerAttribute end
struct Threads <: MOI.AbstractOptimizerAttribute end
struct Trace <: MOI.AbstractOptimizerAttribute end
struct TraceOpt <: MOI.AbstractOptimizerAttribute end
struct LogOption <: MOI.AbstractOptimizerAttribute end
struct SysDir <: MOI.AbstractOptimizerAttribute end
struct WorkDir <: MOI.AbstractOptimizerAttribute end

struct LP <: MOI.AbstractOptimizerAttribute end
struct MIP <: MOI.AbstractOptimizerAttribute end
struct RMIP <: MOI.AbstractOptimizerAttribute end
struct NLP <: MOI.AbstractOptimizerAttribute end
struct DNLP <: MOI.AbstractOptimizerAttribute end
struct CNS <: MOI.AbstractOptimizerAttribute end
struct MINLP <: MOI.AbstractOptimizerAttribute end
struct RMINLP <: MOI.AbstractOptimizerAttribute end
struct QCP <: MOI.AbstractOptimizerAttribute end
struct MIQCP <: MOI.AbstractOptimizerAttribute end
struct RMIQCP <: MOI.AbstractOptimizerAttribute end

function MOI.get(
   model::Optimizer,
   opt::Union{ResLim, IterLim, HoldFixed, NodLim, OptCA, OptCR, Solver, Threads,
              Trace, TraceOpt, LogOption, LP, MIP, RMIP, NLP, DNLP, CNS, MINLP,
              RMINLP, QCP, MIQCP, RMIQCP, MCP, MPEC}
)
   name = replace(string(typeof(opt)), r"(GAMS.)" => "")
   if haskey(model.gams_options, name)
      return model.gams_options[name]
   end
   error("GAMS option '$(name)' is not set.")
end

function MOI.set(
   model::Optimizer,
   opt::Union{ResLim, IterLim, HoldFixed, NodLim, OptCA, OptCR, Solver, Threads,
              Trace, TraceOpt, LogOption, LP, MIP, RMIP, NLP, DNLP, CNS, MINLP,
              RMINLP, QCP, MIQCP, RMIQCP, MCP, MPEC},
   value
)
   name = replace(string(typeof(opt)), r"(GAMS.)" => "")
   model.gams_options[name] = value
   return
end

function MOI.get(
   model::Optimizer,
   ::ModelType
)
   return label(model.mtype)
end

function MOI.set(
   model::Optimizer,
   ::ModelType,
   value::String
)
   value = uppercase(value)
   model.mtype = model_type_from_label(value)
   if model.mtype == MODEL_TYPE_UNDEFINED
      error("Unsupported model type '$value'.")
   end
   return
end

function MOI.get(
   model::Optimizer,
   ::SysDir
)
   return model.gamswork.system_dir
end

function MOI.set(
   model::Optimizer,
   ::SysDir,
   value::String
)
   set_system_dir(model.gamswork, value)
   return
end

function MOI.get(
   model::Optimizer,
   ::WorkDir
)
   return model.gamswork.working_dir
end

function MOI.set(
   model::Optimizer,
   ::WorkDir,
   value::String
)
   set_working_dir(model.gamswork, value)
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

   if name == "modeltype"
      MOI.set(model, ModelType(), value)
      return
   elseif name == "sysdir"
      MOI.set(model, SysDir(), value)
      return
   elseif name == "workdir"
      MOI.set(model, WorkDir(), value)
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
