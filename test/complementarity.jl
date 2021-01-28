import GAMS
using JuMP, Test

# # An MPEC from F. Facchinei, H. Jiang and L. Qi, A smoothing method for
# # mathematical programs with equilibrium constraints, Universita di Roma
# # Technical report, 03.96. Problem number 8
# 
# # Number of variables:   10
# # Number of constraints:  8
#
# # ... parameters for each firm/company
# param c{1..5};			# c_i
# param K{1..5};			# K_i
# param b{1..5};			# \beta_i
#
# # ... parameters for each problem instance
# param L;			# L
# param g;			# \gamma
#
# # ... computed constants
# param gg := 5000^(1/g);
#
# var x >= 0, <= L;
# var y{1..4};
# var l{1..4};   		        # Multipliers
# var Q = x+y[1]+y[2]+y[3]+y[4];	# defined variable Q
#
# minimize f: c[1]*x + b[1]/(b[1]+1)*K[1]^(-1/b[1])*x^((1+b[1])/b[1])
# 		- x*( gg*Q^(-1/g) );
#
# subject to
#
#    F1: 0 = ( c[2] + K[2]^(-1/b[2])*y[1] ) - ( gg*Q^(-1/g) )
# 				- y[1]*( -1/g*gg*Q^(-1-1/g) ) - l[1];
#    F2: 0 = ( c[3] + K[3]^(-1/b[3])*y[2] ) - ( gg*Q^(-1/g) )
# 				- y[2]*( -1/g*gg*Q^(-1-1/g) ) - l[2];
#    F3: 0 = ( c[4] + K[4]^(-1/b[4])*y[3] ) - ( gg*Q^(-1/g) )
# 				- y[3]*( -1/g*gg*Q^(-1-1/g) ) - l[3];
#    F4: 0 = ( c[5] + K[5]^(-1/b[5])*y[4] ) - ( gg*Q^(-1/g) )
# 				- y[4]*( -1/g*gg*Q^(-1-1/g) ) - l[4];
#
#    g1: 0 <= y[1] <= L  complements   l[1];
#    g3: 0 <= y[2] <= L  complements   l[2];
#    g5: 0 <= y[3] <= L  complements   l[3];
#    g7: 0 <= y[4] <= L  complements   l[4];

@testset "gnash1m" begin
   c = [10, 8, 6, 4, 2]
   K = [5, 5, 5, 5, 5]
   b = [1.2, 1.1, 1.0, 0.9, 0.8]
   L = 20
   g = 1.7

   gg = 5000^(1/g)

   gnash1m = Model(GAMS.Optimizer)

   @variable(gnash1m, 0 <= x <= L)
   @variable(gnash1m, 0 <= y[1:4] <= L)
   @variable(gnash1m, l[1:4])
   @variable(gnash1m, Q >= 0)
   @constraint(gnash1m, Q == x+y[1]+y[2]+y[3]+y[4])
   @NLobjective(gnash1m, Min, c[1]*x + b[1]/(b[1]+1)*K[1]^(-1/b[1])*x^((1+b[1])/b[1])
     		        - x*( gg*Q^(-1/g) ) )

   @NLconstraint(gnash1m, cnstr[i=1:4], 0 == ( c[i+1] + K[i+1]^(-1/b[i+1])*y[i] ) - ( gg*Q^(-1/g) )
                 - y[i]*( -1/g*gg*Q^(-1-1/g) ) - l[i] )

   for i in 1:4
      @constraint(gnash1m, l[i] ⟂ y[i])
   end

   # Initial solutions to help reaching the optimality
   set_start_value.(y, [11, 19, 20, 20])
   set_start_value.(l, [0, 0, -3, -5])
   set_start_value(x, 5)
   set_start_value(Q, 70)

   JuMP.optimize!(gnash1m)

   @show JuMP.value.(y)
   @show JuMP.value.(l)
   @show JuMP.value(x)
   @show JuMP.value(Q)

   # JuMP.value.(y) = [11.3327, 19.5003, 20.0, 20.0]
   # JuMP.value.(l) = [-1.35686e-10, -9.7489e-9, -2.51077, -5.18082]
   # JuMP.value(x) = 6.369341692612341
   # JuMP.value(Q) = 77.20235592852553
   # JuMP.objective_value(gnash1m) = -6.116708234438121

   @show JuMP.objective_value(gnash1m)
   @test isapprox(JuMP.objective_value(gnash1m), -6.11671, atol=1e-4)
   @test isapprox( JuMP.value.(l)' * (L .- JuMP.value.(y)), 0, atol=1e-5)
end

# # An MPEC from J.F. Bard, Convex two-level optimization,
# # Mathematical Programming 40(1), 15-27, 1988.
#
# # Number of variables:   2 + 3 slack + 3 multipliers
# # Number of constraints: 4
#
# var x >= 0;
# var y >= 0;
#
# # ... multipliers
# var l{1..3};
#
# minimize f:(x - 5)^2 + (2*y + 1)^2;
#
# subject to
#
#    KKT:    2*(y-1) - 1.5*x + l[1] - l[2]*0.5 + l[3] = 0;
#
#    lin_1:  0 <= 3*x - y - 3        complements l[1] >= 0;
#    lin_2:  0 <= - x + 0.5*y + 4    complements l[2] >= 0;
#    lin_3:  0 <= - x - y + 7        complements l[3] >= 0;

@testset "bard1" begin
   bard1 = Model(GAMS.Optimizer)
   set_optimizer_attribute(bard1, GAMS.ModelType(), "MPEC")

   @variable(bard1, x>=0)
   @variable(bard1, y>=0)
   @variable(bard1, l[1:3]>=0)

   @objective(bard1, Min, (x - 5)^2 + (2*y + 1)^2)

   @constraint(bard1, 2*(y-1) - 1.5*x + l[1] - l[2]*0.5 + l[3] == 0)

   @constraint(bard1, 0 <= 3*x - y - 3)
   @constraint(bard1, 0 <= - x + 0.5*y + 4)
   @constraint(bard1, 0 <= - x - y + 7)

   @constraint(bard1, 3*x - y - 3 ⟂ l[1])
   @constraint(bard1, - x + 0.5*y + 4 ⟂ l[2])
   @constraint(bard1, - x - y + 7 ⟂ l[3])


   JuMP.optimize!(bard1)

   @show JuMP.objective_value(bard1)
   @test isapprox(JuMP.objective_value(bard1), 17.0000, atol=1e-4)
end

# # An MPEC from S. Dempe, "A necessary and sufficient optimality
# # condition for bilevel programming problems", Optimization 25,
# # pp. 341-354, 1992.
#
# # Number of variables:   2 + 1 multipliers
# # Number of constraints: 2
# # Nonlinear complementarity constraints
#
# var x;
# var z;
# var w >= 0;
#
# minimize f: (x - 3.5)^2 + (z + 4)^2;
#
# subject to
#     con1:  z - 3 + 2*z*w = 0;
#     con2:  0 >= z^2 - x     complements  w >= 0;
#
# data;
#
# # starting point
# let x := 1;
# let z := 1;
# let w := 1;
#
#
# let x :=   0.183193 ;
# let z := 0.428106;
# let w := 3.00379;

@testset "dempe" begin

   dempe = Model(GAMS.Optimizer)

   @variable(dempe, x)
   @variable(dempe, z)
   @variable(dempe, w>=0)

   @objective(dempe, Min, (x - 3.5)^2 + (z + 4)^2)

   @constraint(dempe, z - 3 + 2*z*w == 0)

   @constraint(dempe, 0 >= z^2 - x)
   @constraint(dempe,  z^2 - x ⟂ w)

   # Initial solutions to help reaching the optimality
   set_start_value(x, 0)
   set_start_value(z, 0)
   set_start_value(w, 1e7)

   # (xx, zz, ww) = (-3.999779029254958e-10, 9.852984581857451e-8, 1.5223813031201378e7)


   JuMP.optimize!(dempe)

   @show JuMP.objective_value(dempe)
   @test isapprox(JuMP.objective_value(dempe), 28.25, atol=1e-4)

   xx = JuMP.value(x)
   zz = JuMP.value(z)
   ww = JuMP.value(w)
   @test isapprox(zz - 3 + 2*zz*ww, 0, atol=1e-4)
end
