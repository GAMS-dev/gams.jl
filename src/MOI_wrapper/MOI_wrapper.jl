
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
   sysdir::Union{String, Nothing}
   workdir::Union{String, Nothing}
   gamswork::Union{GAMSWorkspace, Nothing}

   # problem attributes
   mtype::GAMSModelType
   n_binary::Int
   n_integer::Int
   n_semicont::Int
   n_semiint::Int
   m::Int
   m_lin::Int
   m_quad::Int
   m_nonlin::Int
   sense::MOI.OptimizationSense
   objective::Union{MOI.SingleVariable, MOI.ScalarAffineFunction{Float64}, MOI.ScalarQuadraticFunction{Float64}, Nothing}
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
   return Optimizer(nothing, nothing, workspace, MODEL_TYPE_UNDEFINED, 0, 0, 0, 0,
                    0, 0, 0, 0, MOI.FEASIBILITY_SENSE, nothing, true, [], [], [],
                    [], [], [], [], [], [], nothing, [], gams_options,
                    Dict{String, Any}(), NaN, SOLVE_STATUS_UNDEFINED,
                    MODEL_STATUS_UNDEFINED, nothing, NaN, NaN)
end

MOI.get(::Optimizer, ::MOI.SolverName) = "GAMS"

MOI.supports(::Optimizer, ::MOI.Silent) = true
MOI.supports(::Optimizer, ::MOI.ObjectiveSense) = true
MOI.supports(::Optimizer, ::MOI.RawParameter) = true
MOI.supports(::Optimizer, ::MOI.ObjectiveFunction{MOI.SingleVariable}) = true
MOI.supports(::Optimizer, ::MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}) = true
MOI.supports(::Optimizer, ::MOI.ObjectiveFunction{MOI.ScalarQuadraticFunction{Float64}}) = true
MOI.supports(::Optimizer, ::MOI.VariablePrimalStart, ::Type{MOI.VariableIndex}) = true
MOI.supports(::Optimizer, ::MOI.VariableName, ::Type{MOI.VariableIndex}) = true
MOI.supports(::Optimizer, ::MOI.ConstraintName, ::Type{MOI.ConstraintIndex}) = true
MOI.supports(::Optimizer, ::MOI.TimeLimitSec) = true
MOI.supports(::Optimizer, ::MOI.NumberOfThreads) = true
MOI.supports(::Optimizer, ::MOI.NLPBlock) = true
MOI.supports(::Optimizer, ::MOI.NLPBlockDual) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.SingleVariable}, ::Type{MOI.LessThan{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.SingleVariable}, ::Type{MOI.GreaterThan{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.SingleVariable}, ::Type{MOI.EqualTo{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.SingleVariable}, ::Type{MOI.ZeroOne}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.SingleVariable}, ::Type{MOI.Integer}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.SingleVariable}, ::Type{MOI.Semicontinuous{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.SingleVariable}, ::Type{MOI.Semiinteger{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.VectorOfVariables}, ::Type{MOI.SOS1{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.VectorOfVariables}, ::Type{MOI.SOS2{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.ScalarAffineFunction{Float64}}, ::Type{MOI.LessThan{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.ScalarAffineFunction{Float64}}, ::Type{MOI.GreaterThan{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.ScalarAffineFunction{Float64}}, ::Type{MOI.EqualTo{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.ScalarQuadraticFunction{Float64}}, ::Type{MOI.LessThan{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.ScalarQuadraticFunction{Float64}}, ::Type{MOI.GreaterThan{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.ScalarQuadraticFunction{Float64}}, ::Type{MOI.EqualTo{Float64}}) = true
MOI.supports_constraint(::Optimizer, ::Type{MOI.VectorAffineFunction{Float64}}, ::Type{MOI.Complements}) = true
MOI.supports(::Optimizer, ::MOI.ConstraintDualStart, ::MOI.ConstraintIndex{MOI.SingleVariable, MOI.GreaterThan{Float64}}, ::Union{Real, Nothing}) = true
MOI.supports(::Optimizer, ::MOI.ConstraintDualStart, ::MOI.ConstraintIndex{MOI.SingleVariable, MOI.LessThan{Float64}}, ::Union{Real, Nothing}) = true
MOI.supports(::Optimizer, ::MOI.ConstraintDualStart, ::MOI.ConstraintIndex{MOI.SingleVariable, MOI.EqualTo{Float64}}, ::Union{Real, Nothing}) = true

MOIU.supports_default_copy_to(model::Optimizer, copy_names::Bool) = !copy_names

function MOI.copy_to(
   model::Optimizer,
   src::MOI.ModelLike;
   copy_names = false
)
   return MOIU.default_copy_to(model, src, copy_names)
end

function MOI.empty!(
   model::Optimizer
)
   model.sysdir = nothing
   model.workdir = nothing
   model.mtype = MODEL_TYPE_UNDEFINED
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
   return isnothing(model.sysdir) &&
      isnothing(model.workdir) &&
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
      isempty(model.complementarity_constraints) &&
      isnan(model.solve_time) &&
      model.solve_status == SOLVE_STATUS_UNDEFINED &&
      model.model_status == MODEL_STATUS_UNDEFINED &&
      isnothing(model.sol) &&
      isnan(model.obj) &&
      isnan(model.obj_est)
end

has_start(var::VariableInfo) = ! isnothing(var.start)
has_upper_bound(var::VariableInfo) = ! isnothing(var.upper_bound)
has_lower_bound(var::VariableInfo) = ! isnothing(var.lower_bound)
is_fixed(var::VariableInfo) = has_lower_bound(var) && has_upper_bound(var) && var.lower_bound == var.upper_bound

has_upper_bound(model::Optimizer, vi::MOI.VariableIndex) = has_upper_bound(model.variable_info[vi.value])
has_lower_bound(model::Optimizer, vi::MOI.VariableIndex) = has_lower_bound(model.variable_info[vi.value])
is_fixed(model::Optimizer, vi::MOI.VariableIndex) = is_fixed(model.variable_info[vi.value])

offset_linear_le(model::Optimizer) = 0
offset_linear_ge(model::Optimizer) = length(model.linear_le_constraints)
offset_linear_eq(model::Optimizer) = offset_linear_ge(model) + length(model.linear_ge_constraints)
offset_quadratic_le(model::Optimizer) = offset_linear_eq(model) + length(model.linear_eq_constraints)
offset_quadratic_ge(model::Optimizer) = offset_quadratic_le(model) + length(model.quadratic_le_constraints)
offset_quadratic_eq(model::Optimizer) = offset_quadratic_ge(model) + length(model.quadratic_ge_constraints)
offset_nonlin(model::Optimizer) = offset_quadratic_eq(model) + length(model.quadratic_eq_constraints)
offset_complementarity(model::Optimizer) = 0

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
