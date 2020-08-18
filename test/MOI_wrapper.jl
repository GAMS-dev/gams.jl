
using Test
using Printf
using MathOptInterface

const MOI = MathOptInterface
const MOIT = MOI.Test
const MOIU = MOI.Utilities
const MOIB = MOI.Bridges

import GAMS

const OPTIMIZER_CONSTRUCTOR = MOI.OptimizerWithAttributes(GAMS.Optimizer, MOI.Silent() => true)
const OPTIMIZER = MOI.instantiate(OPTIMIZER_CONSTRUCTOR)

const CACHING_OPTIMIZER = MOIU.CachingOptimizer(MOIU.Model{Float64}(), OPTIMIZER);
const OPTIMIZER_SPLITINTERVAL = MOIB.Constraint.SplitInterval{Float64}(
    MOIU.CachingOptimizer(MOIU.UniversalFallback(MOIU.Model{Float64}()), OPTIMIZER))
const BRIDGED = MOI.instantiate(OPTIMIZER_CONSTRUCTOR, with_bridge_type = Float64)

const TEST_SOLVERS = (
   "alphaecp",
   "antigone",
   "baron",
   "bdmlp",
   "bonmin",
   "bonminh",
   "cbc",
   "conopt",
   "conopt3",
   "conopt4",
   "couenne",
   "cplex",
   "dicopt",
   "glomiqo",
   "gurobi",
   "ipopt",
   "ipopth",
   "knitro",
   "lgo",
   "lindo",
   "lindoglobal",
   "localsolver",
   "localsolver70",
   "minos",
   "mosek",
   "msnlp",
   "path",
   "pathc",
   "pathnlp",
   "quadminos",
   "sbb",
   "shot",
   "scip",
   "snopt",
   "soplex",
   "xa",
   "xpress"
)

atol = 1e-5
rtol = 1e-5
const CONFIG = MOIT.TestConfig(atol=atol, rtol=rtol)
const CONFIG_LOCAL = MOIT.TestConfig(atol=atol, rtol=rtol, optimal_status = MOI.LOCALLY_SOLVED)
const CONFIG_LOCAL_NODUAL = MOIT.TestConfig(atol=atol, rtol=rtol, duals = false, optimal_status = MOI.LOCALLY_SOLVED)
const CONFIG_NODUAL = MOIT.TestConfig(atol=atol, rtol=rtol, duals = false)

println("Unit Tests" * "_"^19)
testname = @sprintf("%-15s", "default")
@testset "$testname" begin
    @test MOI.get(OPTIMIZER, MOI.SolverName()) == "GAMS"
    @test MOIU.supports_default_copy_to(OPTIMIZER, false)
    @test !MOIU.supports_default_copy_to(OPTIMIZER, true)
    exclude = [
        "delete_variable",                  # deleting not supported
        "delete_variables",                 # deleting not supported
        "solve_affine_deletion_edge_cases", # deleting not supported
        "solve_affine_lessthan",            # constraint names for variable bounds not supported
        "solve_objbound_edge_cases",        # constraint names for variable bounds not supported
        "getconstraint",                    # constraint names for variable bounds not supported
        "getvariable",                      # constraint names for variable bounds not supported
        "solve_with_upperbound",            # constraint names for variable bounds not supported
        "solve_blank_obj",                  # constraint names for variable bounds not supported
        "solve_affine_equalto",             # constraint names for variable bounds not supported
        "solve_single_variable_dual_min",   # constraint names for variable bounds not supported
        "solve_integer_edge_cases",         # constraint names for variable bounds not supported
        "solve_constant_obj",               # constraint names for variable bounds not supported
        "solve_singlevariable_obj",         # constraint names for variable bounds not supported
        "solve_with_lowerbound",            # constraint names for variable bounds not supported
        "solve_zero_one_with_bounds_1",     # constraint names for variable bounds not supported
        "solve_zero_one_with_bounds_2",     # constraint names for variable bounds not supported
        "solve_zero_one_with_bounds_3",     # constraint names for variable bounds not supported
        "get_objective_function",           # function getters not supported
        "update_dimension_nonnegative_variables", # function getters not supported
        "delete_nonnegative_variables",     # function getters not supported
        "solve_result_index",               # DualObjectiveValue not supported
        "delete_soc_variables",             # second order cone not supported
        "solve_affine_interval",            # get constraint index not supported
        "solve_affine_greaterthan",         # get constraint index not supported
        "solve_qp_edge_cases",              # conopt finds only local optimal solution
        "solve_qcp_edge_cases",             # conopt finds only local optimal solution
    ]
    config = MOIT.TestConfig(atol=1e-3, rtol=1e-3)
    MOIT.unittest(BRIDGED, config, exclude)
end
println()

println("Continuous Linear" * "_"^12)
for solver in TEST_SOLVERS
    if ! GAMS.check_solver(OPTIMIZER.gamswork, solver, GAMS.MODEL_TYPE_LP)
        continue
    end
    testname = @sprintf("%-15s", "$solver")
    MOI.set(OPTIMIZER_SPLITINTERVAL, GAMS.Solver(), solver)
    exclude = [
        "linear7",  # VectorAffineFunction not supported
        "linear15", # VectorAffineFunction not supported
        "linear10", # DualObjectiveValue not supported
        "linear2",  # DualObjectiveValue not supported
        "linear1",  # DualObjectiveValue not supported
        "linear14", # DualObjectiveValue not supported
        "linear12", # dual behavior in infeasible case doesn't match test
        "linear8a", # dual behavior in infeasible case doesn't match test
    ]
    @testset "$testname" begin
        if solver in ("xa",)
            exclude_solver = [
                "linear8c", # wrong primal variables
            ]
            MOIT.contlineartest(OPTIMIZER_SPLITINTERVAL, CONFIG, union(exclude, exclude_solver))

        elseif solver in ("knitro", "lgo")
            exclude_solver = [
                "linear8b", # unable to detect unboundedness
                "linear8c", # unable to detect unboundedness
            ]
            MOIT.contlineartest(OPTIMIZER_SPLITINTERVAL, CONFIG, union(exclude, exclude_solver))

        elseif solver in ("conopt4",)
            exclude_solver = [
                "partial_start", # wrong objective (bug)
                "linear9",       # wrong objective (bug)
            ]
            MOIT.contlineartest(OPTIMIZER_SPLITINTERVAL, CONFIG, union(exclude, exclude_solver))

        elseif solver in ("ipopt", "ipopth")
            exclude_solver = [
                "linear13", # wrong dual
                "linear8c", # does not terminated unbounded
            ]
            MOIT.contlineartest(OPTIMIZER_SPLITINTERVAL, CONFIG, union(exclude, exclude_solver))

        elseif solver in ("localsolver", "localsolver70")
            # needs extra license

        else
            MOIT.contlineartest(OPTIMIZER_SPLITINTERVAL, CONFIG, exclude)
        end
    end
end
println()

MOI.empty!(OPTIMIZER)

println("Integer Linear" * "_"^15)
MOI.set(OPTIMIZER, GAMS.ModelType(), "MIP")
for solver in TEST_SOLVERS
    if ! GAMS.check_solver(OPTIMIZER.gamswork, solver, GAMS.MODEL_TYPE_MIP)
        continue
    end
    testname = @sprintf("%-15s", "$solver")
    MOI.set(OPTIMIZER, GAMS.Solver(), solver)
    exclude = [
        "indicator1",   # indicator constraints not supported
        "indicator2",   # indicator constraints not supported
        "indicator3",   # indicator constraints not supported
        "indicator4",   # indicator constraints not supported
    ]
    @testset "$testname" begin
        if solver in ("baron", "mosek")
            exclude_solver = [
                "semiconttest", # semicont constraints not supported
                "semiinttest",  # semiint constraints not supported
                "int2",         # sos constraints not supported
            ]
            MOIT.intlineartest(OPTIMIZER_SPLITINTERVAL, CONFIG, union(exclude, exclude_solver))

        elseif solver in ("lindo", "lindoglobal")
            exclude_solver = [
                "semiconttest", # semicont constraints not supported
                "semiinttest",  # semiint constraints not supported
                "int2",         # finds different optimal solution
            ]
            MOIT.intlineartest(OPTIMIZER_SPLITINTERVAL, CONFIG, union(exclude, exclude_solver))

        elseif solver in ("bdmlp", "cbc", "cplex", "gurobi")
            exclude_solver = [
                "semiconttest", # does not provide objective bound
                "semiinttest",  # does not provide objective bound
            ]
            MOIT.intlineartest(OPTIMIZER_SPLITINTERVAL, CONFIG, union(exclude, exclude_solver))

        elseif solver in ("xa",)
            exclude_solver = [
                "semiconttest", # does not provide objective bound
                "semiinttest",  # does not provide objective bound
                "int2",         # sos constraints not supported
            ]
            MOIT.intlineartest(OPTIMIZER_SPLITINTERVAL, CONFIG, union(exclude, exclude_solver))

        elseif solver in ("scip",)
            exclude_solver = [
                "int1",         # finds suboptimal solution
                "semiconttest", # does not provide objective bound
                "semiinttest",  # does not provide objective bound
            ]
            MOIT.intlineartest(OPTIMIZER_SPLITINTERVAL, CONFIG, union(exclude, exclude_solver))

        elseif solver in ("xpress",)
            exclude_solver = [
                "int3",         # finds suboptimal solution
                "semiconttest", # does not provide objective bound
                "semiinttest",  # does not provide objective bound
            ]
            MOIT.intlineartest(OPTIMIZER_SPLITINTERVAL, CONFIG, union(exclude, exclude_solver))

        elseif solver in ("localsolver", "localsolver70")
            # needs extra license

        else
            MOIT.intlineartest(OPTIMIZER_SPLITINTERVAL, CONFIG, exclude)
        end
    end
end
println()

MOI.empty!(OPTIMIZER)

println("Continuous Quadratic" * "_"^9)
MOI.set(OPTIMIZER, GAMS.ModelType(), "QCP")
for solver in TEST_SOLVERS
    if ! GAMS.check_solver(OPTIMIZER.gamswork, solver, GAMS.MODEL_TYPE_QCP)
        continue
    end
    testname = @sprintf("%-15s", "$solver")
    MOI.set(OPTIMIZER, GAMS.Solver(), solver)
    exclude = [
        "qcp1",   # VectorAffineFunction not supported
    ]
    @testset "$testname" begin
        if solver in ("antigone", "glomiqo")
            exclude_solver = [
                "ncqcp1", # finds only local optimal solution
                "socp1",  # finds only local optimal solution
            ]
            MOIT.contquadratictest(CACHING_OPTIMIZER, CONFIG_NODUAL, union(exclude, exclude_solver))

        elseif solver in ("conopt", "conopt3", "dicopt", "minos", "snopt", "pathnlp")
            exclude_solver = [
                "socp1",  # fails to find feasible solution
                "ncqcp2", # fails to find feasible solution
                "qp3",    # manages to find global optimal solution
            ]
            MOIT.contquadratictest(CACHING_OPTIMIZER, CONFIG_LOCAL_NODUAL, union(exclude, exclude_solver))

        elseif solver in ("baron",)
            exclude_solver = [
                "qp1",    # finds only local optimal solution
                "qp3",    # finds only local optimal solution
                "qp2",    # fails to prove optimality
                "qcp2",   # fails to prove optimality
                "qcp3",   # fails to prove optimality
                "qcp4",   # fails to prove optimality
                "qcp5",   # fails to prove optimality
                "socp1",  # fails to prove optimality
                "ncqcp1", # fails to prove optimality
            ]
            MOIT.contquadratictest(CACHING_OPTIMIZER, CONFIG_NODUAL, union(exclude, exclude_solver))

        elseif solver in ("couenne",)
            exclude_solver = [
                "qp1",    # finds different solution
                "qp2",    # takes too much time
                "qcp3",   # fails to prove optimality
                "qp3",    # fails to prove optimality
            ]
            MOIT.contquadratictest(CACHING_OPTIMIZER, CONFIG_NODUAL, union(exclude, exclude_solver))

        elseif solver in ("cplex",)
            exclude_solver = [
                "socp1",  # not positive semi-definite
                "ncqcp1", # not positive semi-definite
                "ncqcp2", # not positive semi-definite
            ]
            cplex_config = MOIT.TestConfig(atol=1e-3, rtol=1e-3, duals = false)
            MOIT.contquadratictest(CACHING_OPTIMIZER, cplex_config, union(exclude, exclude_solver))

        elseif solver in ("conopt4",)
            exclude_solver = [
                "qp3",    # wrong objective (bug)
                "ncqcp1", # wrong objective (bug)
                "ncqcp2", # manages to find global optimal solution
            ]
            MOIT.contquadratictest(CACHING_OPTIMIZER, CONFIG_LOCAL_NODUAL, union(exclude, exclude_solver))

        elseif solver in ("gurobi", "lindo", "lindoglobal")
            exclude_solver = [
                "ncqcp1", # not positive semi-definite
            ]
            MOIT.contquadratictest(CACHING_OPTIMIZER, CONFIG_NODUAL, union(exclude, exclude_solver))

        elseif solver in ("ipopt", "ipopth", "knitro", "lgo", "msnlp")
            exclude_solver = [
                "qp3",    # manages to find global optimal solution
            ]
            MOIT.contquadratictest(CACHING_OPTIMIZER, CONFIG_LOCAL_NODUAL, union(exclude, exclude_solver))

        elseif solver in ("mosek", "xpress")
            exclude_solver = [
                "ncqcp1", # not supported
                "ncqcp2", # not supported
            ]
            MOIT.contquadratictest(CACHING_OPTIMIZER, CONFIG_NODUAL, union(exclude, exclude_solver))

        elseif solver in ("scip",)
            MOIT.contquadratictest(CACHING_OPTIMIZER, CONFIG_NODUAL, exclude)

        elseif solver in ("localsolver", "localsolver70")
            # needs extra license

        else
            MOIT.contquadratictest(CACHING_OPTIMIZER, CONFIG, exclude)
        end
    end
end
println()

MOI.empty!(OPTIMIZER)

println("Continuous Nonlinear" * "_"^9)
MOI.set(OPTIMIZER, GAMS.ModelType(), "NLP")
for solver in TEST_SOLVERS
    if ! GAMS.check_solver(OPTIMIZER.gamswork, solver, GAMS.MODEL_TYPE_NLP)
        continue
    end
    testname = @sprintf("%-15s", "$solver")
    MOI.set(OPTIMIZER, GAMS.Solver(), solver)
    @testset "$testname" begin
        if solver in ("antigone", "baron", "couenne")
            exclude = [
                "hs071",            # finds only local optimal solution / fails to prove optimality
                "hs071_no_hessian", # finds only local optimal solution / fails to prove optimality
            ]
            MOIT.nlptest(OPTIMIZER, CONFIG, exclude)

        elseif solver in ("scip",)
            exclude = [
                "hs071",            # fails to prove optimality
                "hs071_no_hessian", # fails to prove optimality
                "nlp_objective_and_moi_objective", # finds different solution
            ]
            MOIT.nlptest(OPTIMIZER, CONFIG, exclude)

        elseif solver in ("mosek",)
            # not supported

        elseif solver in ("lindo", "lindoglobal")
            exclude = [
                "hs071",            # finds global optimal solution
                "hs071_no_hessian", # finds global optimal solution
            ]
            MOIT.nlptest(OPTIMIZER, CONFIG_LOCAL, exclude)

        elseif solver in ("xpress",)
            exclude = [
                "hs071",            # finds different point
                "hs071_no_hessian", # finds different point
            ]
            MOIT.nlptest(OPTIMIZER, CONFIG_LOCAL, exclude)

        elseif solver in ("localsolver", "localsolver70")
            # needs extra license

        else
            MOIT.nlptest(OPTIMIZER, CONFIG_LOCAL)
        end
    end
end

return
