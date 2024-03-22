
using Test
using Printf
using MathOptInterface

const MOI = MathOptInterface
const solver = "xpress"

import GAMS

model = MOI.Utilities.CachingOptimizer(
    MOI.Utilities.UniversalFallback(MOI.Utilities.Model{Float64}()),
    MOI.Bridges.full_bridge_optimizer(GAMS.Optimizer(), Float64),
)
MOI.set(model, MOI.Silent(), true)
MOI.set(model, GAMS.Solver(), solver)

common_excludes = [
    # ZeroBridge does not support ConstraintDual
    "test_conic_linear_VectorOfVariables_2",

    # lower bound > upper bound leads to compilation error in GAMS
    "test_constraint_ZeroOne_bounds_3",

    # invalid symbol leads to compilation error in GAMS
    "test_nonlinear_invalid",

    # not supported
    "test_linear_Indicator_ON_ZERO",
    "test_linear_Indicator_constant_term",
    "test_linear_Indicator_integration",
    "test_model_default_DualStatus",
    "test_model_default_PrimalStatus",

    # no solution returned
    r"test_infeasible_MAX_SENSE.*",
    r"test_infeasible_MIN_SENSE.*",
    r"test_infeasible_affine_MAX_SENSE.*",
    r"test_infeasible_affine_MIN_SENSE.*",
    r"test_linear_INFEASIBLE.*",
    "test_solve_DualStatus_INFEASIBILITY_CERTIFICATE_EqualTo_lower",
    "test_solve_DualStatus_INFEASIBILITY_CERTIFICATE_EqualTo_upper",
    "test_solve_DualStatus_INFEASIBILITY_CERTIFICATE_GreaterThan",
    "test_solve_DualStatus_INFEASIBILITY_CERTIFICATE_Interval_lower",
    "test_solve_DualStatus_INFEASIBILITY_CERTIFICATE_Interval_upper",
    "test_solve_DualStatus_INFEASIBILITY_CERTIFICATE_LessThan",
    r"test_solve_DualStatus_INFEASIBILITY_CERTIFICATE_VariableIndex_LessThan.*",

    # local optimal instead of optimal
    r"test_nonlinear_hs071.*",
    "test_nonlinear_mixed_complementarity",
    r"test_nonlinear_objective.*",
    "test_nonlinear_qp_complementarity_constraint",
    "test_nonlinear_without_objective",
    "test_quadratic_nonconvex_constraint_basic",
    "test_quadratic_nonconvex_constraint_integration",
    r"test_nonlinear_expression_hs071.*",
    "test_nonlinear_expression_hs109",
    "test_nonlinear_expression_hs110",
    "test_nonlinear_expression_quartic",

    # xpress doesn't return dual bound
    "test_linear_Semicontinuous_integration",
    "test_linear_Semiinteger_integration",
    "test_solve_ObjectiveBound_MAX_SENSE_LP",
    "test_solve_ObjectiveBound_MIN_SENSE_LP",

    # xpress returns different duals
    "test_linear_integration_delete_variables",
    "test_solve_VariableIndex_ConstraintDual_MIN_SENSE",
    "test_variable_solve_with_lowerbound",
    "test_variable_solve_with_upperbound",
    "test_nonlinear_duals",
]

version_depend_excludes = Dict(
    "29.1.0" => String[
    # xpress finds incorrect solution
        "test_linear_integer_solve_twice",],
    "38.2.1" => String[
        # xpress returns different duals
        "test_conic_NormInfinityCone_3",
        "test_quadratic_nonhomogeneous",
    ],
    "40.4.0" => String[
    # xpress returns different duals
        "test_quadratic_nonhomogeneous",],
)

MOI.optimize!(model)
ver = MOI.get(model, MOI.SolverVersion())
excludes = common_excludes
if haskey(version_depend_excludes, ver)
    excludes = vcat(excludes, version_depend_excludes[ver])
end

MOI.Test.runtests(
    model,
    MOI.Test.Config(
        atol = 1e-5,
        rtol = 1e-5,
        optimal_status = MOI.OPTIMAL,
        exclude = Any[MOI.DualObjectiveValue, MOI.VariableBasisStatus, MOI.ConstraintBasisStatus],
    );
    exclude = excludes,
)

return
