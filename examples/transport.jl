# This problem finds a least cost shipping schedule that meets
# requirements at markets and supplies at factories.
#
# Dantzig, G B, Chapter 3.3. In Linear Programming and Extensions.
# Princeton University Press, Princeton, New Jersey, 1963.

using GAMS
using JuMP
using Test

function example_transport(; verbose = true)
    model = Model(GAMS.Optimizer)
    set_optimizer_attribute(model, MOI.Silent(), !verbose)

    a = [350, 600]
    b = [325, 300, 275]
    d = [2.5 1.7 1.8; 2.5 1.8 1.4]

    @variable(model, x[1:2, 1:3] >= 0)

    @objective(model, Min, 0.09 * sum(d[i, j] * x[i, j] for i in 1:2, j in 1:3))

    @constraint(model, [i = 1:2], sum(x[i, j] for j in 1:3) <= a[i])
    @constraint(model, [j = 1:3], sum(x[i, j] for i in 1:2) >= b[j])

    if verbose
        print(model)
    end

    JuMP.optimize!(model)

    obj_opt = JuMP.objective_value(model)
    x_opt = JuMP.value.(x)

    if verbose
        println("Objective value: ", obj_opt)
        println("x = ", x_opt)
    end

    @test obj_opt ≈ 153.6750
    @test x_opt[1, 1] ≈ 50.0
    @test x_opt[1, 2] ≈ 300.0
    @test x_opt[1, 3] ≈ 0.0
    @test x_opt[2, 1] ≈ 275.0
    @test x_opt[2, 2] ≈ 0.0
    @test x_opt[2, 3] ≈ 275.0
end

example_transport(verbose = false)
