import GAMS
using JuMP
using Test

# An MPEC from F. Facchinei, H. Jiang and L. Qi, A smoothing method for
# mathematical programs with equilibrium constraints, Universita di Roma
# Technical report, 03.96. Problem number 8
@testset "gnash1m" begin
   gnash1m = Model(GAMS.Optimizer)
   set_optimizer_attribute(gnash1m, MOI.Silent(), true)

   c = [10, 8, 6, 4, 2]
   K = [5, 5, 5, 5, 5]
   b = [1.2, 1.1, 1.0, 0.9, 0.8]
   L = 20
   g = 1.7

   gg = 5000^(1/g)

   @variable(gnash1m, 0 <= x <= L)
   @variable(gnash1m, 0 <= y[1:4] <= L)
   @variable(gnash1m, l[1:4])
   @variable(gnash1m, Q >= 0)

   @NLobjective(gnash1m, Min, c[1] * x + b[1] / (b[1] + 1) * K[1]^(-1 / b[1]) *
      x^((1 + b[1]) / b[1]) - x * (gg * Q^(-1 / g)))

   @constraint(gnash1m, Q == x + y[1] + y[2] + y[3] + y[4])
   @NLconstraint(gnash1m, [i=1:4], 0 == (c[i+1] + K[i+1]^(-1 / b[i+1]) * y[i]) -
      (gg*Q^(-1 / g)) - y[i] * (-1 / g * gg * Q^(-1 - 1 / g) ) - l[i])
   for i in 1:4
      @constraint(gnash1m, l[i] ⟂ y[i])
   end

   # Initial solutions to help reaching the optimality
   set_start_value.(y, [11, 19, 20, 20])
   set_start_value.(l, [0, 0, -3, -5])
   set_start_value(x, 5)
   set_start_value(Q, 70)

   JuMP.optimize!(gnash1m)

   @test isapprox(JuMP.objective_value(gnash1m), -6.11671, atol=1e-4)
   @test isapprox( JuMP.value.(l)' * (L .- JuMP.value.(y)), 0, atol=1e-5)
end

# An MPEC from J.F. Bard, Convex two-level optimization,
# Mathematical Programming 40(1), 15-27, 1988.
@testset "bard1" begin
   bard1 = Model(GAMS.Optimizer)
   set_optimizer_attribute(bard1, GAMS.ModelType(), "MPEC")
   set_optimizer_attribute(bard1, MOI.Silent(), true)

   @variable(bard1, x >= 0)
   @variable(bard1, y >= 0)
   @variable(bard1, l[1:3] >= 0)

   @objective(bard1, Min, (x - 5)^2 + (2*y + 1)^2)

   @constraint(bard1, 2*(y-1) - 1.5*x + l[1] - l[2]*0.5 + l[3] == 0)
   @constraint(bard1, 0 <= 3*x - y - 3)
   @constraint(bard1, 0 <= - x + 0.5*y + 4)
   @constraint(bard1, 0 <= - x - y + 7)
   @constraint(bard1, 3*x - y - 3 ⟂ l[1])
   @constraint(bard1, - x + 0.5*y + 4 ⟂ l[2])
   @constraint(bard1, - x - y + 7 ⟂ l[3])

   JuMP.optimize!(bard1)

   @test isapprox(JuMP.objective_value(bard1), 17.0000, atol=1e-4)
end

# An MPEC from S. Dempe, "A necessary and sufficient optimality
# condition for bilevel programming problems", Optimization 25,
# pp. 341-354, 1992.
@testset "dempe" begin
   dempe = Model(GAMS.Optimizer)
   set_optimizer_attribute(dempe, MOI.Silent(), true)

   @variable(dempe, x)
   @variable(dempe, z)
   @variable(dempe, w >= 0)

   @objective(dempe, Min, (x - 3.5)^2 + (z + 4)^2)

   @constraint(dempe, z - 3 + 2 * z * w == 0)
   @constraint(dempe, 0 >= z^2 - x)
   @constraint(dempe,  z^2 - x ⟂ w)

   # Initial solutions to help reaching the optimality
   set_start_value(x, 0)
   set_start_value(z, 0)
   set_start_value(w, 1e7)

   JuMP.optimize!(dempe)

   @test isapprox(JuMP.objective_value(dempe), 28.25, atol=1e-4)

   xx = JuMP.value(x)
   zz = JuMP.value(z)
   ww = JuMP.value(w)
   @test isapprox(zz - 3 + 2 * zz * ww, 0, atol=1e-4)
end

@testset "MCP" begin

   mcp = Model(GAMS.Optimizer)
   set_optimizer_attribute(mcp, GAMS.ModelType(), "MCP")

   @variable(mcp, x[1:4] >= 0)

   @constraint(mcp, x[1]+2x[2]-2x[3]+4x[4] -6⟂ x[4])
   @constraint(mcp, -x[3]-x[4] +2 ⟂ x[1])
   @constraint(mcp, x[1]-x[2]+2x[3]-2x[4] -2 ⟂ x[3])
   @constraint(mcp, x[3]-2x[4] +2 ⟂ x[2])

   JuMP.optimize!(mcp)
   @test isapprox(value.(x), [2.8, 0.0, 0.8, 1.2])
end

return
