
using Printf
import MathOptInterface

const MOI = MathOptInterface
const MOIU = MathOptInterface.Utilities

# supported GAMS command line options
const MOI_SUPPORTED_CLOPTIONS = (
   "reslim",
   "iterlim",
   "holdfixed",
   "nodlim",
   "optca",
   "optcr",
   "solver",
   "threads",
   "trace",
   "traceopt",
   "license",
   "logoption",
   "lp",
   "mip",
   "rmip",
   "nlp",
   "dnlp",
   "cns",
   "minlp",
   "rminlp",
   "qcp",
   "miqcp",
   "rmiqcp"
)

# supported model types
const MOI_SUPPORTED_MODEL_TYPES = (
   GAMS.MODEL_TYPE_LP,
   GAMS.MODEL_TYPE_MIP,
   GAMS.MODEL_TYPE_RMIP,
   GAMS.MODEL_TYPE_NLP,
   GAMS.MODEL_TYPE_MINLP,
   GAMS.MODEL_TYPE_RMINLP,
   GAMS.MODEL_TYPE_QCP,
   GAMS.MODEL_TYPE_MIQCP,
   GAMS.MODEL_TYPE_RMIQCP,
   GAMS.MODEL_TYPE_MCP,
   GAMS.MODEL_TYPE_MPEC,
)

mutable struct VariableInfo
   name::String
   type::GAMSVarType
   lower_bound::Union{Float64, Nothing}
   lower_bound_dual_start::Union{Float64, Nothing}
   upper_bound::Union{Float64, Nothing}
   upper_bound_dual_start::Union{Float64, Nothing}
   start::Union{Float64, Nothing}
end

VariableInfo() = VariableInfo("", VARTYPE_FREE, nothing, nothing, nothing,
   nothing, nothing)

mutable struct ConstraintInfo{F, S}
   name::String
   func::F
   set::S
   dual_start::Union{Nothing, Float64}
end

ConstraintInfo(func, set) = ConstraintInfo("", func, set, nothing)

mutable struct Optimizer <: MOI.AbstractOptimizer
   gamswork::Union{GAMSWorkspace, Nothing}

   # problem attributes
   name::String
   model_type::GAMSModelType
   n_binary::Int
   n_integer::Int
   n_semicont::Int
   n_semiint::Int
   m::Int
   m_lin::Int
   m_quad::Int
   m_nonlin::Int
   sense::MOI.OptimizationSense
   objective::Union{MOI.VariableIndex, MOI.ScalarAffineFunction{Float64}, MOI.ScalarQuadraticFunction{Float64}, Nothing}
   objvar::Bool
   variable_info::Vector{VariableInfo}
   linear_le_constraints::Vector{ConstraintInfo{MOI.ScalarAffineFunction{Float64}, MOI.LessThan{Float64}}}
   linear_ge_constraints::Vector{ConstraintInfo{MOI.ScalarAffineFunction{Float64}, MOI.GreaterThan{Float64}}}
   linear_eq_constraints::Vector{ConstraintInfo{MOI.ScalarAffineFunction{Float64}, MOI.EqualTo{Float64}}}
   quadratic_le_constraints::Vector{ConstraintInfo{MOI.ScalarQuadraticFunction{Float64}, MOI.LessThan{Float64}}}
   quadratic_ge_constraints::Vector{ConstraintInfo{MOI.ScalarQuadraticFunction{Float64}, MOI.GreaterThan{Float64}}}
   quadratic_eq_constraints::Vector{ConstraintInfo{MOI.ScalarQuadraticFunction{Float64}, MOI.EqualTo{Float64}}}
   sos1_constraints::Vector{ConstraintInfo{MOI.VectorOfVariables, MOI.SOS1{Float64}}}
   sos2_constraints::Vector{ConstraintInfo{MOI.VectorOfVariables, MOI.SOS2{Float64}}}
   nlp_data::Union{MOI.NLPBlockData, Nothing}
   complementarity_constraints::Vector{ConstraintInfo{MOI.VectorAffineFunction{Float64}, MOI.Complements}}

   # parameters
   sysdir::Union{String, Nothing}
   workdir::Union{String, Nothing}
   user_model_type::GAMSModelType
   gams_options::Dict{String, Any}
   solver_options::Dict{String, Any}

   # solution attributes
   solve_time::Float64
   solve_status::GAMSSolveStatus
   model_status::GAMSModelStatus
   sol::Union{GAMSSolution, Nothing}
   obj::Float64
   obj_est::Float64
end

function Optimizer(workspace::Union{Nothing, GAMSWorkspace} = nothing)
   gams_options = Dict{String, Any}()
   gams_options["threads"] = 1
   return Optimizer(workspace, "m", MODEL_TYPE_UNDEFINED, 0, 0, 0, 0, 0, 0, 0, 0,
                    MOI.FEASIBILITY_SENSE, nothing, true, [], [], [], [], [], [],
                    [], [], [], nothing, [], nothing, nothing, MODEL_TYPE_UNDEFINED,
                    gams_options, Dict{String, Any}(), NaN, SOLVE_STATUS_UNDEFINED,
                    MODEL_STATUS_UNDEFINED, nothing, NaN, NaN)
end

struct GeneratedVariableName <: MOI.AbstractVariableAttribute end
struct GeneratedConstraintName <: MOI.AbstractConstraintAttribute end
struct OriginalVariableName <: MOI.AbstractModelAttribute
   name::String
end
struct OriginalConstraintName <: MOI.AbstractModelAttribute
   name::String
end

MOI.get(::Optimizer, ::MOI.SolverName) = "GAMS"

MOI.supports(::Optimizer, ::MOI.Name) = true
MOI.supports(::Optimizer, ::MOI.SolverVersion) = true
MOI.supports(::Optimizer, ::MOI.Silent) = true
MOI.supports(::Optimizer, ::MOI.ObjectiveSense) = true
MOI.supports(::Optimizer, ::MOI.RawOptimizerAttribute) = true
MOI.supports(::Optimizer, ::MOI.ObjectiveFunction{MOI.VariableIndex}) = true
MOI.supports(::Optimizer, ::MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}) = true
MOI.supports(::Optimizer, ::MOI.ObjectiveFunction{MOI.ScalarQuadraticFunction{Float64}}) = true
MOI.supports(::Optimizer, ::OriginalVariableName) = true
MOI.supports(::Optimizer, ::OriginalConstraintName) = true
MOI.supports(::Optimizer, ::MOI.VariableName, ::Type{MOI.VariableIndex}) = true
MOI.supports(::Optimizer, ::GeneratedVariableName, ::Type{MOI.VariableIndex}) = true
MOI.supports(::Optimizer, ::MOI.ConstraintName, ::Type{MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.LessThan{Float64}}}) = true
MOI.supports(::Optimizer, ::MOI.ConstraintName, ::Type{MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.GreaterThan{Float64}}}) = true
MOI.supports(::Optimizer, ::MOI.ConstraintName, ::Type{MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.EqualTo{Float64}}}) = true
MOI.supports(::Optimizer, ::MOI.ConstraintName, ::Type{MOI.ConstraintIndex{MOI.ScalarQuadraticFunction{Float64}, MOI.LessThan{Float64}}}) = true
MOI.supports(::Optimizer, ::MOI.ConstraintName, ::Type{MOI.ConstraintIndex{MOI.ScalarQuadraticFunction{Float64}, MOI.GreaterThan{Float64}}}) = true
MOI.supports(::Optimizer, ::MOI.ConstraintName, ::Type{MOI.ConstraintIndex{MOI.ScalarQuadraticFunction{Float64}, MOI.EqualTo{Float64}}}) = true
MOI.supports(::Optimizer, ::GeneratedConstraintName, ::Type{MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.LessThan{Float64}}}) = true
MOI.supports(::Optimizer, ::GeneratedConstraintName, ::Type{MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.GreaterThan{Float64}}}) = true
MOI.supports(::Optimizer, ::GeneratedConstraintName, ::Type{MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.EqualTo{Float64}}}) = true
MOI.supports(::Optimizer, ::GeneratedConstraintName, ::Type{MOI.ConstraintIndex{MOI.ScalarQuadraticFunction{Float64}, MOI.LessThan{Float64}}}) = true
MOI.supports(::Optimizer, ::GeneratedConstraintName, ::Type{MOI.ConstraintIndex{MOI.ScalarQuadraticFunction{Float64}, MOI.GreaterThan{Float64}}}) = true
MOI.supports(::Optimizer, ::GeneratedConstraintName, ::Type{MOI.ConstraintIndex{MOI.ScalarQuadraticFunction{Float64}, MOI.EqualTo{Float64}}}) = true
MOI.supports(::Optimizer, ::MOI.TimeLimitSec) = true
MOI.supports(::Optimizer, ::MOI.NumberOfThreads) = true
MOI.supports(::Optimizer, ::MOI.NLPBlock) = true
MOI.supports(::Optimizer, ::MOI.NLPBlockDual) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.VariableIndex}, ::Type{MOI.LessThan{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.VariableIndex}, ::Type{MOI.GreaterThan{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.VariableIndex}, ::Type{MOI.EqualTo{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.VariableIndex}, ::Type{MOI.ZeroOne}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.VariableIndex}, ::Type{MOI.Integer}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.VariableIndex}, ::Type{MOI.Semicontinuous{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.VariableIndex}, ::Type{MOI.Semiinteger{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.VectorOfVariables}, ::Type{MOI.SOS1{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.VectorOfVariables}, ::Type{MOI.SOS2{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.ScalarAffineFunction{Float64}}, ::Type{MOI.LessThan{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.ScalarAffineFunction{Float64}}, ::Type{MOI.GreaterThan{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.ScalarAffineFunction{Float64}}, ::Type{MOI.EqualTo{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.ScalarQuadraticFunction{Float64}}, ::Type{MOI.LessThan{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.ScalarQuadraticFunction{Float64}}, ::Type{MOI.GreaterThan{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.ScalarQuadraticFunction{Float64}}, ::Type{MOI.EqualTo{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.VectorAffineFunction{Float64}}, ::Type{MOI.Complements}) = true
MOI.supports(::Optimizer, ::MOI.VariablePrimalStart, ::Type{MOI.VariableIndex}) = true
MOI.supports(::Optimizer, ::MOI.ConstraintDualStart, ::MOI.ConstraintIndex{MOI.VariableIndex, MOI.GreaterThan{Float64}}, ::Union{Real, Nothing}) = true
MOI.supports(::Optimizer, ::MOI.ConstraintDualStart, ::MOI.ConstraintIndex{MOI.VariableIndex, MOI.LessThan{Float64}}, ::Union{Real, Nothing}) = true
MOI.supports(::Optimizer, ::MOI.ConstraintDualStart, ::MOI.ConstraintIndex{MOI.VariableIndex, MOI.EqualTo{Float64}}, ::Union{Real, Nothing}) = true

MOI.supports_incremental_interface(::Optimizer) = true

function MOI.get(
   model::Optimizer,
   ::MOI.SolverVersion
)
   ver = get_version(model.gamswork);
   return "$(ver[1]).$(ver[2]).$(ver[3])"
end

function MOI.copy_to(
   model::Optimizer,
   src::MOI.ModelLike
)
   return MOIU.default_copy_to(model, src)
end

function MOI.empty!(
   model::Optimizer
)
   model.model_type = MODEL_TYPE_UNDEFINED
   model.n_binary = 0
   model.n_integer = 0
   model.n_semicont = 0
   model.n_semiint = 0
   model.m = 0
   model.m_lin = 0
   model.m_quad = 0
   model.m_nonlin = 0
   model.sense = MOI.FEASIBILITY_SENSE
   model.objective = nothing
   empty!(model.variable_info)
   empty!(model.linear_le_constraints)
   empty!(model.linear_ge_constraints)
   empty!(model.linear_eq_constraints)
   empty!(model.quadratic_le_constraints)
   empty!(model.quadratic_ge_constraints)
   empty!(model.quadratic_eq_constraints)
   empty!(model.sos1_constraints)
   empty!(model.sos2_constraints)
   model.nlp_data = nothing
   empty!(model.complementarity_constraints)
   model.solve_time = NaN
   model.solve_status = SOLVE_STATUS_UNDEFINED
   model.model_status = MODEL_STATUS_UNDEFINED
   model.sol = nothing
   model.obj = NaN
   model.obj_est = NaN
end

function MOI.is_empty(
   model::Optimizer
)
   return model.model_type == MODEL_TYPE_UNDEFINED
      model.n_binary == 0 &&
      model.n_integer == 0 &&
      model.n_semicont == 0 &&
      model.n_semiint == 0 &&
      model.m == 0 &&
      model.m_lin == 0 &&
      model.m_quad == 0 &&
      model.m_nonlin == 0 &&
      model.sense == MOI.FEASIBILITY_SENSE &&
      isnothing(model.objective) &&
      isempty(model.variable_info) &&
      isempty(model.linear_le_constraints) &&
      isempty(model.linear_ge_constraints) &&
      isempty(model.linear_eq_constraints) &&
      isempty(model.quadratic_le_constraints) &&
      isempty(model.quadratic_ge_constraints) &&
      isempty(model.quadratic_eq_constraints) &&
      isempty(model.sos1_constraints) &&
      isempty(model.sos2_constraints) &&
      isnothing(model.nlp_data) &&
      isempty(model.complementarity_constraints)
end

_has_start(var::VariableInfo) = ! isnothing(var.start)
_has_upper_bound(var::VariableInfo) = ! isnothing(var.upper_bound)
_has_lower_bound(var::VariableInfo) = ! isnothing(var.lower_bound)
_is_fixed(var::VariableInfo) = _has_lower_bound(var) && _has_upper_bound(var) && var.lower_bound == var.upper_bound

_has_upper_bound(model::Optimizer, vi::MOI.VariableIndex) = _has_upper_bound(model.variable_info[vi.value])
_has_lower_bound(model::Optimizer, vi::MOI.VariableIndex) = _has_lower_bound(model.variable_info[vi.value])
_is_fixed(model::Optimizer, vi::MOI.VariableIndex) = _is_fixed(model.variable_info[vi.value])

function _constraints(
   model::Optimizer,
   ::Type{MOI.ScalarAffineFunction{Float64}},
   ::Type{MOI.LessThan{Float64}},
)
   return model.linear_le_constraints
end

function _constraints(
   model::Optimizer,
   ::Type{MOI.ScalarAffineFunction{Float64}},
   ::Type{MOI.GreaterThan{Float64}},
)
   return model.linear_ge_constraints
end

function _constraints(
   model::Optimizer,
   ::Type{MOI.ScalarAffineFunction{Float64}},
   ::Type{MOI.EqualTo{Float64}},
)
   return model.linear_eq_constraints
end

function _constraints(
   model::Optimizer,
   ::Type{MOI.ScalarQuadraticFunction{Float64}},
   ::Type{MOI.LessThan{Float64}},
)
   return model.quadratic_le_constraints
end

function _constraints(
   model::Optimizer,
   ::Type{MOI.ScalarQuadraticFunction{Float64}},
   ::Type{MOI.GreaterThan{Float64}},
)
   return model.quadratic_ge_constraints
end

function _constraints(
   model::Optimizer,
   ::Type{MOI.ScalarQuadraticFunction{Float64}},
   ::Type{MOI.EqualTo{Float64}},
)
   return model.quadratic_eq_constraints
end

function _offset(
   model::Optimizer,
   ::Type{MOI.ScalarAffineFunction{Float64}},
   ::Type{MOI.LessThan{Float64}},
)
   return 0
end

function _offset(
   model::Optimizer,
   ::Type{MOI.ScalarAffineFunction{Float64}},
   ::Type{MOI.GreaterThan{Float64}},
)
   return length(model.linear_le_constraints)
end

function _offset(
   model::Optimizer,
   ::Type{MOI.ScalarAffineFunction{Float64}},
   ::Type{MOI.EqualTo{Float64}},
)
   return _offset(model, MOI.ScalarAffineFunction{Float64}, MOI.GreaterThan{Float64}) + length(model.linear_ge_constraints)
end

function _offset(
   model::Optimizer,
   ::Type{MOI.ScalarQuadraticFunction{Float64}},
   ::Type{MOI.LessThan{Float64}},
)
   return _offset(model, MOI.ScalarAffineFunction{Float64}, MOI.EqualTo{Float64}) + length(model.linear_eq_constraints)
end

function _offset(
   model::Optimizer,
   ::Type{MOI.ScalarQuadraticFunction{Float64}},
   ::Type{MOI.GreaterThan{Float64}},
)
   return _offset(model, MOI.ScalarQuadraticFunction{Float64}, MOI.LessThan{Float64}) + length(model.quadratic_le_constraints)
end

function _offset(
   model::Optimizer,
   ::Type{MOI.ScalarQuadraticFunction{Float64}},
   ::Type{MOI.EqualTo{Float64}},
)
   return _offset(model, MOI.ScalarQuadraticFunction{Float64}, MOI.GreaterThan{Float64}) + length(model.quadratic_ge_constraints)
end

_offset_nonlin(model::Optimizer) = _offset(model, MOI.ScalarQuadraticFunction{Float64}, MOI.EqualTo{Float64}) + length(model.quadratic_eq_constraints)

_dual_multiplier(model::Optimizer) = model.sense == MOI.MIN_SENSE ? 1.0 : -1.0

function MOI.set(
   model::Optimizer,
   ::MOI.NLPBlock,
   nlp_data::MOI.NLPBlockData
)
   model.nlp_data = nlp_data
   MOI.initialize(model.nlp_data.evaluator, [:ExprGraph])
   return
end

include("options.jl")
include("variables.jl")
include("objective.jl")
include("constraints.jl")
include("translate.jl")
include("solve.jl")
