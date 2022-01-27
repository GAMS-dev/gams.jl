
abstract type AbstractGAMSCmdAttribute <: MOI.AbstractOptimizerAttribute end

struct ModelType <: MOI.AbstractOptimizerAttribute end
struct SysDir <: MOI.AbstractOptimizerAttribute end
struct WorkDir <: MOI.AbstractOptimizerAttribute end

struct HoldFixed <: AbstractGAMSCmdAttribute end
struct IterLim <: AbstractGAMSCmdAttribute end
struct License <: AbstractGAMSCmdAttribute end
struct LogOption <: AbstractGAMSCmdAttribute end
struct NodLim <: AbstractGAMSCmdAttribute end
struct OptCA <: AbstractGAMSCmdAttribute end
struct OptCR <: AbstractGAMSCmdAttribute end
struct ResLim <: AbstractGAMSCmdAttribute end
struct Solver <: AbstractGAMSCmdAttribute end
struct Threads <: AbstractGAMSCmdAttribute end
struct Trace <: AbstractGAMSCmdAttribute end
struct TraceOpt <: AbstractGAMSCmdAttribute end

struct CNS <: AbstractGAMSCmdAttribute end
struct DNLP <: AbstractGAMSCmdAttribute end
struct LP <: AbstractGAMSCmdAttribute end
struct MCP <: AbstractGAMSCmdAttribute end
struct MINLP <: AbstractGAMSCmdAttribute end
struct MIP <: AbstractGAMSCmdAttribute end
struct MIQCP <: AbstractGAMSCmdAttribute end
struct MPEC <: AbstractGAMSCmdAttribute end
struct NLP <: AbstractGAMSCmdAttribute end
struct QCP <: AbstractGAMSCmdAttribute end
struct RMINLP <: AbstractGAMSCmdAttribute end
struct RMIP <: AbstractGAMSCmdAttribute end
struct RMIQCP <: AbstractGAMSCmdAttribute end

function MOI.get(
   model::Optimizer,
   opt::AbstractGAMSCmdAttribute
)
   name = lowercase(replace(string(typeof(opt)), r"(GAMS.)" => ""))
   if haskey(model.gams_options, name)
      return model.gams_options[name]
   end
   error("GAMS option '$(name)' is not set.")
end

function MOI.set(
   model::Optimizer,
   opt::AbstractGAMSCmdAttribute,
   value
)
   name = lowercase(replace(string(typeof(opt)), r"(GAMS.)" => ""))
   model.gams_options[name] = value
   return
end

function MOI.get(
   model::Optimizer,
   ::ModelType
)
   return label(model.user_model_type)
end

function MOI.set(
   model::Optimizer,
   ::ModelType,
   value::String
)
   value = uppercase(value)
   model.user_model_type = model_type_from_label(value)
   if model.user_model_type == MODEL_TYPE_UNDEFINED
      error("Unsupported model type '$value'.")
   end
   return
end

function MOI.get(
   model::Optimizer,
   ::SysDir
)
   if isnothing(model.gamswork)
      if isnothing(model.sysdir)
         error("GAMS system directory has not been set.")
      end
      return model.sysdir
   else
      return model.gamswork.system_dir
   end
end

function MOI.set(
   model::Optimizer,
   ::SysDir,
   value::String
)
   if isnothing(model.gamswork)
      check_system_dir(value)
      model.sysdir = value
   else
      set_system_dir(model.gamswork, value)
   end
   return
end

function MOI.get(
   model::Optimizer,
   ::WorkDir
)
   if isnothing(model.gamswork)
      if isnothing(model.workdir)
         error("GAMS working directory has not been set.")
      end
      return model.workdir
   else
      return model.gamswork.working_dir
   end
end

function MOI.set(
   model::Optimizer,
   ::WorkDir,
   value::String
)
   if isnothing(model.gamswork)
      model.workdir = value
   else
      set_working_dir(model.gamswork, value)
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
      MOI.set(model, MOI.RawOptimizerAttribute("logoption"), 0)
   else
      MOI.set(model, MOI.RawOptimizerAttribute("logoption"), 1)
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
   MOI.set(model, MOI.RawOptimizerAttribute("reslim"), Float64(value))
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
   MOI.set(model, MOI.RawOptimizerAttribute("threads"), value)
   return
end

function MOI.get(
   model::Optimizer,
   option::MOI.RawOptimizerAttribute
)
   name = lowercase(option.name)

   if name == "modeltype"
      return MOI.get(model, ModelType())
   elseif name == "sysdir"
      return MOI.get(model, SysDir())
   elseif name == "workdir"
      return MOI.get(model, WorkDir())
   end

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
   option::MOI.RawOptimizerAttribute,
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
   option::MOI.RawOptimizerAttribute,
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
