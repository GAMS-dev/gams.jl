using GAMS
import JuMP
using MathOptInterface
using Test

const MOI = MathOptInterface

occursinfile(filename::String, regex::Regex) =
    open(filename) do f
        for line in eachline(f)
            if occursin(regex, line)
                return true
            end
        end
        return false
    end

@testset "general        " begin
    @testset "precision" begin
        m = JuMP.Model(GAMS.Optimizer)
        JuMP.@variable(m, x >= 0)
        JuMP.@objective(m, MOI.MIN_SENSE, x)
        JuMP.@constraint(m, x >= 2257.812325)
        JuMP.set_optimizer_attribute(m, MOI.Silent(), true)
        JuMP.optimize!(m)

        workdir = JuMP.get_optimizer_attribute(m, GAMS.WorkDir())
        @test occursinfile(joinpath(workdir, "moi.gms"), r"x.*=G=.*2257.812325")
        @test JuMP.value(x) == 2257.812325
    end

    @testset "fixed_var" begin
        m = JuMP.Model(GAMS.Optimizer)
        JuMP.@variable(m, x)
        JuMP.@variable(m, y)
        JuMP.fix(x, 1)
        JuMP.@constraint(m, y == 1)
        JuMP.set_optimizer_attribute(m, MOI.Silent(), true)
        JuMP.optimize!(m)

        @test JuMP.value(x) == JuMP.value(y)
    end

    @testset "parenthesis_1" begin
        m = JuMP.Model(GAMS.Optimizer)
        JuMP.@variable(m, -1.0 <= x <= 1.0)
        JuMP.@variable(m, must_have_eq, Bin, start = 0)
        JuMP.@constraint(m, con, 0 <= x^3 + (1.0 - must_have_eq) * 100.0)
        JuMP.set_optimizer_attribute(m, MOI.Silent(), true)
        JuMP.optimize!(m)
    end

    @testset "model_type" begin
        m = JuMP.Model(GAMS.Optimizer)
        JuMP.@variable(m, -1.0 <= x <= 1.0)
        JuMP.@objective(m, MOI.MIN_SENSE, x)
        JuMP.@constraint(m, abs(x) == 1)
        JuMP.set_optimizer_attribute(m, MOI.Silent(), true)
        JuMP.set_optimizer_attribute(m, GAMS.ModelType(), "DNLP")
        JuMP.optimize!(m)
    end
end
