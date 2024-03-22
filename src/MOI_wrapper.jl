
using Printf
import MathOptInterface

const MOI = MathOptInterface
const MOIU = MathOptInterface.Utilities

mutable struct VariableInfo
    name::String
    type::Symbol
    lower_bound::Float64
    upper_bound::Float64
    start::Union{Float64, Nothing}
end

VariableInfo() = VariableInfo("", :Free, -Inf, Inf, nothing)

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
    type::Union{Nothing, Symbol}
    sense::MOI.OptimizationSense
    variables::Vector{VariableInfo}
    objective::Union{
        Nothing,
        MOI.VariableIndex,
        MOI.ScalarAffineFunction{Float64},
        MOI.ScalarQuadraticFunction{Float64},
        MOI.ScalarNonlinearFunction,
    }
    constraints::Vector{
        Union{
            ConstraintInfo{MOI.ScalarAffineFunction{Float64}, MOI.LessThan{Float64}},
            ConstraintInfo{MOI.ScalarAffineFunction{Float64}, MOI.GreaterThan{Float64}},
            ConstraintInfo{MOI.ScalarAffineFunction{Float64}, MOI.EqualTo{Float64}},
            ConstraintInfo{MOI.ScalarQuadraticFunction{Float64}, MOI.LessThan{Float64}},
            ConstraintInfo{MOI.ScalarQuadraticFunction{Float64}, MOI.GreaterThan{Float64}},
            ConstraintInfo{MOI.ScalarQuadraticFunction{Float64}, MOI.EqualTo{Float64}},
            ConstraintInfo{MOI.ScalarNonlinearFunction, MOI.LessThan{Float64}},
            ConstraintInfo{MOI.ScalarNonlinearFunction, MOI.GreaterThan{Float64}},
            ConstraintInfo{MOI.ScalarNonlinearFunction, MOI.EqualTo{Float64}},
        },
    }
    sos_constraints::Vector{
        Union{
            ConstraintInfo{MOI.VectorOfVariables, MOI.SOS1{Float64}},
            ConstraintInfo{MOI.VectorOfVariables, MOI.SOS2{Float64}},
        },
    }
    compl_constraints::Vector{ConstraintInfo{MOI.VectorAffineFunction{Float64}, MOI.Complements}}
    nlp_data::Union{MOI.NLPBlockData, Nothing}

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
    solution::Union{GAMSSolution, Nothing}
    objective_value::Float64
    objective_bound::Float64
    node_count::Int
end

function Optimizer(workspace::Union{Nothing, GAMSWorkspace} = nothing)
    return Optimizer(
        workspace,
        "m",
        nothing,
        MOI.FEASIBILITY_SENSE,
        [],
        nothing,
        [],
        [],
        [],
        nothing,
        nothing,
        nothing,
        MODEL_TYPE_UNDEFINED,
        Dict{String, Any}(),
        Dict{String, Any}(),
        NaN,
        SOLVE_STATUS_UNDEFINED,
        MODEL_STATUS_UNDEFINED,
        nothing,
        NaN,
        NaN,
        0,
    )
end

MOI.get(::Optimizer, ::MOI.SolverName) = "GAMS"

MOI.supports(::Optimizer, ::MOI.SolverVersion) = true

function MOI.get(model::Optimizer, ::MOI.SolverVersion)
    ver = get_version(model.gamswork)
    return "$(ver[1]).$(ver[2]).$(ver[3])"
end

MOI.supports_incremental_interface(::Optimizer) = true

MOI.copy_to(model::Optimizer, src::MOI.ModelLike) = MOIU.default_copy_to(model, src)

function MOI.empty!(model::Optimizer)
    model.type = nothing
    model.sense = MOI.FEASIBILITY_SENSE
    model.objective = nothing
    empty!(model.variables)
    empty!(model.constraints)
    empty!(model.sos_constraints)
    empty!(model.compl_constraints)
    model.nlp_data = nothing
    model.solve_time = NaN
    model.solve_status = SOLVE_STATUS_UNDEFINED
    model.model_status = MODEL_STATUS_UNDEFINED
    model.solution = nothing
    model.objective_value = NaN
    return model.objective_bound = NaN
end

function MOI.is_empty(model::Optimizer)
    return isnothing(model.type) &&
           model.sense == MOI.FEASIBILITY_SENSE &&
           isnothing(model.objective) &&
           isempty(model.variables) &&
           isempty(model.constraints) &&
           isempty(model.sos_constraints) &&
           isempty(model.compl_constraints) &&
           isnothing(model.nlp_data)
end

function MOI.optimize!(model::Optimizer)
    # create GAMS Workspace if not done so far
    if isnothing(model.gamswork)
        if isnothing(model.sysdir) && isnothing(model.workdir)
            model.gamswork = GAMSWorkspace()
        elseif isnothing(model.sysdir)
            model.gamswork = GAMSWorkspace()
            set_working_dir(model.gamswork, model.workdir)
        elseif isnothing(model.workdir)
            model.gamswork = GAMSWorkspace(model.sysdir)
        else
            model.gamswork = GAMSWorkspace(model.sysdir, model.workdir)
        end
        model.sysdir = nothing
        model.workdir = nothing
    end

    # check solver options
    if length(model.solver_options) > 0 && !haskey(model.gams_options, "solver")
        error(
            "No GAMS solver selected (attribute 'solver') but solver options specified: ",
            model.solver_options,
        )
    end

    # write GMS file
    filename = joinpath(model.gamswork.working_dir, "moi.gms")
    write(filename, model)

    # run GAMS
    job = GAMSJob(model.gamswork, filename, model.name)
    model.solution, stats =
        run(job, options = model.gams_options, solver_options = model.solver_options)

    # process solution statistics
    model.solve_status = stats["solveStat"]
    model.model_status = stats["modelStat"]
    if !isnothing(model.objective) && typeof(model.objective) == MOI.VariableIndex
        objective_name = gms_name(model.objective)
    else
        objective_name = "objvar"
    end
    if haskey(model.solution.var, objective_name)
        model.objective_value = model.solution.var[objective_name].level[1]
    end
    if haskey(stats, "objEst")
        model.objective_bound = stats["objEst"]
    end
    if haskey(stats, "resUsd")
        model.solve_time = stats["resUsd"]
    else
        model.solve_time = 0.0
    end
    if haskey(stats, "nodUsd") && !isnan(stats["nodUsd"])
        model.node_count = stats["nodUsd"]
    end
    return
end

MOI.supports(::Optimizer, ::MOI.SolveTimeSec) = true

MOI.get(model::Optimizer, ::MOI.SolveTimeSec) = model.solve_time

MOI.supports(::Optimizer, ::MOI.NodeCount) = true

MOI.get(model::Optimizer, ::MOI.NodeCount) = model.node_count

MOI.supports(::Optimizer, ::MOI.TerminationStatus) = true

function MOI.get(model::Optimizer, ::MOI.TerminationStatus)
    # not called
    if model.solve_status == SOLVE_STATUS_UNDEFINED && model.model_status == MODEL_STATUS_UNDEFINED
        return MOI.OPTIMIZE_NOT_CALLED
    end

    # (more or less) good outcomes
    if model.solve_status == SOLVE_STATUS_NORMAL
        if model.model_status == MODEL_STATUS_OPTIMAL_GLOBAL
            return MOI.OPTIMAL
        elseif model.model_status == MODEL_STATUS_OPTIMAL_LOCAL
            return MOI.LOCALLY_SOLVED
        elseif model.model_status == MODEL_STATUS_UNBOUNDED
            return MOI.DUAL_INFEASIBLE
        elseif model.model_status == MODEL_STATUS_INFEASIBLE_GLOBAL
            return MOI.INFEASIBLE
        elseif model.model_status == MODEL_STATUS_INFEASIBLE_LOCAL
            return MOI.LOCALLY_INFEASIBLE
        elseif model.model_status == MODEL_STATUS_SOLVED_UNIQUE
            return MOI.OPTIMAL
        elseif model.model_status == MODEL_STATUS_SOLVED
            return MOI.LOCALLY_SOLVED
        elseif model.model_status == MODEL_STATUS_SOLVED_SINGULAR
            return MOI.LOCALLY_SOLVED
        elseif model.model_status == MODEL_STATUS_UNBOUNDED_NO_SOLUTION
            return MOI.DUAL_INFEASIBLE
        elseif model.model_status == MODEL_STATUS_INFEASIBLE_NO_SOLUTION
            return MOI.INFEASIBLE
        elseif model.model_status == MODEL_STATUS_INTEGER
            return MOI.OPTIMAL
        elseif model.model_status == MODEL_STATUS_INTEGER_INFEASIBLE
            return MOI.INFEASIBLE
        elseif model.model_status == MODEL_STATUS_FEASIBLE
            if !MOI.get(model, MOI.Silent())
                @info "Solver returned feasible solution but failed to prove optimality"
            end
            return MOI.OTHER_ERROR
        else
            error(
                "Unsupported termination: " *
                string(model.solve_status) *
                " / " *
                string(model.model_status),
            )
        end

        # bad outcomes
    elseif model.solve_status == SOLVE_STATUS_ITERATION
        return MOI.ITERATION_LIMIT
    elseif model.solve_status == SOLVE_STATUS_RESOURCE
        return MOI.TIME_LIMIT
    elseif model.solve_status == SOLVE_STATUS_SOLVER
        return MOI.OTHER_LIMIT
    elseif model.solve_status == SOLVE_STATUS_EVAL_ERROR
        return MOI.OTHER_ERROR
    elseif model.solve_status == SOLVE_STATUS_CAPABILITY
        return MOI.INVALID_MODEL
    elseif model.solve_status == SOLVE_STATUS_LICENSE
        return MOI.OTHER_ERROR
    elseif model.solve_status == SOLVE_STATUS_SETUP_ERROR
        return MOI.INVALID_MODEL
    elseif model.solve_status == SOLVE_STATUS_SOLVE_ERROR
        return MOI.OTHER_ERROR
    elseif model.solve_status == SOLVE_STATUS_INTERNAL_ERROR
        return MOI.OTHER_ERROR
    elseif model.solve_status == SOLVE_STATUS_SYSTEM_ERROR
        return MOI.OTHER_ERROR
    else
        error("Unsupported termination: " * string(model.solve_status))
    end
end

function MOI.get(model::Optimizer, ::MOI.RawStatusString)
    return string(model.solve_status) * " / " * string(model.model_status)
end

function MOI.get(model::Optimizer, ::MOI.ResultCount)
    if typeof(model.solution) == GAMSSolution
        return 1
    end
    return 0
end

function MOI.get(model::Optimizer, attr::MOI.PrimalStatus)
    if !(1 <= attr.result_index <= MOI.get(model, MOI.ResultCount()))
        return MOI.NO_SOLUTION
    end

    if model.solve_status == SOLVE_STATUS_NORMAL
        if model.model_status == MODEL_STATUS_OPTIMAL_GLOBAL ||
           model.model_status == MODEL_STATUS_OPTIMAL_LOCAL ||
           model.model_status == MODEL_STATUS_SOLVED_UNIQUE ||
           model.model_status == MODEL_STATUS_SOLVED ||
           model.model_status == MODEL_STATUS_SOLVED_SINGULAR ||
           model.model_status == MODEL_STATUS_INTEGER
            return MOI.FEASIBLE_POINT
        elseif model.model_status == MODEL_STATUS_INFEASIBLE_GLOBAL ||
               model.model_status == MODEL_STATUS_INFEASIBLE_NO_SOLUTION ||
               model.model_status == MODEL_STATUS_INTEGER_INFEASIBLE
            return MOI.NO_SOLUTION
        elseif model.model_status == MODEL_STATUS_UNBOUNDED ||
               model.model_status == MODEL_STATUS_UNBOUNDED_NO_SOLUTION ||
               return MOI.INFEASIBILITY_CERTIFICATE
        elseif model.model_status == MODEL_STATUS_INFEASIBLE_LOCAL
            return MOI.INFEASIBLE_POINT
        end
    end
    return MOI.UNKNOWN_RESULT_STATUS
end

function MOI.get(model::Optimizer, attr::MOI.DualStatus)
    if !(1 <= attr.result_index <= MOI.get(model, MOI.ResultCount()))
        return MOI.NO_SOLUTION
    end

    if model.solve_status == SOLVE_STATUS_NORMAL
        if model.model_status == MODEL_STATUS_OPTIMAL_GLOBAL ||
           model.model_status == MODEL_STATUS_OPTIMAL_LOCAL ||
           model.model_status == MODEL_STATUS_SOLVED_UNIQUE ||
           model.model_status == MODEL_STATUS_SOLVED ||
           model.model_status == MODEL_STATUS_SOLVED_SINGULAR ||
           model.model_status == MODEL_STATUS_INTEGER
            return MOI.FEASIBLE_POINT
        elseif model.model_status == MODEL_STATUS_INFEASIBLE_GLOBAL ||
               model.model_status == MODEL_STATUS_INFEASIBLE_NO_SOLUTION ||
               model.model_status == MODEL_STATUS_UNBOUNDED ||
               model.model_status == MODEL_STATUS_UNBOUNDED_NO_SOLUTION ||
               model.model_status == MODEL_STATUS_INTEGER_INFEASIBLE
            return MOI.INFEASIBILITY_CERTIFICATE
        elseif model.model_status == MODEL_STATUS_INFEASIBLE_LOCAL
            return MOI.INFEASIBLE_POINT
        end
    end
    return MOI.UNKNOWN_RESULT_STATUS
end

include(joinpath("moi", "model_stream.jl"))
include(joinpath("moi", "options.jl"))
include(joinpath("moi", "variables.jl"))
include(joinpath("moi", "objective.jl"))
include(joinpath("moi", "constraints.jl"))
