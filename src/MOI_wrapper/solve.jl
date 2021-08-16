
function MOI.optimize!(
   model::Optimizer
)
   start_time = time()

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
   if length(model.solver_options) > 0 && ! haskey(model.gams_options, "solver")
      error("No GAMS solver selected (attribute 'solver') but solver options specified: ",
         model.solver_options)
   end

   # dimensions
   model.n_binary = 0
   model.n_integer = 0
   model.n_semiint = 0
   model.n_semicont = 0
   for var in model.variable_info
      if var.type == VARTYPE_BINARY
         model.n_binary += 1
      end
      if var.type == VARTYPE_INTEGER
         model.n_integer += 1
      end
      if var.type == VARTYPE_SEMICONT
         model.n_semicont += 1
      end
      if var.type == VARTYPE_SEMIINT
         model.n_semiint += 1
      end
   end
   model.m_lin = length(model.linear_le_constraints) +
      length(model.linear_ge_constraints) + length(model.linear_eq_constraints)
   model.m_quad = length(model.quadratic_le_constraints) +
      length(model.quadratic_ge_constraints) + length(model.quadratic_eq_constraints)
   model.m_nonlin = !isnothing(model.nlp_data) ? length(model.nlp_data.constraint_bounds) : 0
   model.m = offset_nonlin(model) + model.m_nonlin

   # choose model type
   is_discrete = model.n_binary + model.n_integer + model.n_semicont + model.n_semiint > 0
   is_discrete |= length(model.sos1_constraints) + length(model.sos2_constraints) > 0
   is_nonlinear = model.m_nonlin > 0 || (!isnothing(model.nlp_data) && model.nlp_data.has_objective)
   is_quadratic = model.m_quad > 0 || isa(model.objective, MOI.ScalarQuadraticFunction{Float64})
   is_complementarity = length(model.complementarity_constraints) > 0
   model.model_type = auto_model_type(model.user_model_type, is_quadratic, is_nonlinear, is_discrete, is_complementarity)
   if model.model_type != model.user_model_type && ! MOI.get(model, MOI.Silent())
      @info "Updated GAMS model type: " * label(model.user_model_type) * " -> " * label(model.model_type)
   end

   # use additional objective variable?
   model.objvar = true
   if typeof(model.objective) == MOI.SingleVariable && model.m > 0
      model.objvar = false
   end
   if model.model_type == GAMS.MODEL_TYPE_MCP || model.model_type == GAMS.MODEL_TYPE_CNS
      model.objvar = false
   end

   # write GMS file
   filename = joinpath(model.gamswork.working_dir, "moi.gms")
   open(filename, "w") do fio
      io = GAMSTranslateStream(fio)
      translate_header(io)
      translate_defsets(io, model)
      translate_defvars(io, model)
      translate_defequs(io, model)
      translate_objective(io, model)
      translate_equations(io, model)
      translate_vardata(io, model)
      translate_solve(io, model, "moi")
   end

   # run GAMS
   job = GAMSJob(model.gamswork, filename, "moi")
   model.sol, stats = run(job, options=model.gams_options, solver_options=model.solver_options)

   # process optimal objective
   if model.model_type != GAMS.MODEL_TYPE_MCP && model.model_type != GAMS.MODEL_TYPE_CNS
      if model.objvar
         objvar_name = "objvar"
      else
         objvar_name = "x$(model.objective.variable.value)"
      end
      if haskey(model.sol.var, objvar_name)
         model.obj = model.sol.var[objvar_name].level[1]
      end
   end

   # process solution statistics
   model.solve_status = stats["solveStat"]
   model.model_status = stats["modelStat"]
   if haskey(stats, "objEst")
      model.obj_est = stats["objEst"]
   end

   if haskey(stats, "resUsd")
      model.solve_time = stats["resUsd"]
   else
      model.solve_time = 0.0
   end
   return
end

function MOI.get(
   model::Optimizer,
   ::MOI.SolveTime
)
   return model.solve_time
end

function MOI.get(
   model::Optimizer,
   ::MOI.TerminationStatus
)
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
         if ! MOI.get(model, MOI.Silent())
            @info "Solver returned feasible solution but failed to prove optimality"
         end
         return MOI.OTHER_ERROR
      else
         error("Unsupported termination: " * string(model.solve_status) * " / " *
            string(model.model_status))
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

function MOI.get(
   model::Optimizer,
   ::MOI.RawStatusString
)
   return string(model.solve_status) * " / " * string(model.model_status)
end

function MOI.get(
   model::Optimizer,
   ::MOI.ResultCount
)
   if typeof(model.sol) == GAMSSolution
      return 1
   end
   return 0
end

function MOI.get(
   model::Optimizer,
   attr::MOI.PrimalStatus
)
   if ! (1 <= attr.N <= MOI.get(model, MOI.ResultCount()))
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

function MOI.get(
   model::Optimizer,
   attr::MOI.DualStatus
)
   if ! (1 <= attr.N <= MOI.get(model, MOI.ResultCount()))
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
