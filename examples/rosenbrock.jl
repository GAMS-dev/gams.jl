# A Classical Unconstrained Test Problem
#
# Rosenbrock, H H, An Automatic Method for finding the Greatest or
# least value of a function. Computer Journal 3 (1960), 175-184.

using GAMS
using JuMP
using Test

function example_rosenbrock(; verbose = true)
   model = Model(GAMS.Optimizer)
   set_optimizer_attribute(model, MOI.Silent(), !verbose)

   @variable(model, -10 <= x1 <= 5, start = -1.2)
   @variable(model, -10 <= x2 <= 10, start = 1.0)

   @NLobjective(model, Min, 100 * (x2 - x1^2)^2 + -(1 - x1)^2)

   if verbose
      print(model)
   end

   set_optimizer_attribute(model, "type", "LP")

   JuMP.optimize!(model)

   obj_opt = JuMP.objective_value(model)
   x1_opt = JuMP.value(x1)
   x2_opt = JuMP.value(x2)

   if verbose
      println("Objective value: ", obj_opt)
      println("x1 = ", x1_opt)
      println("x2 = ", x2_opt)
   end
end

example_rosenbrock(verbose = false)
