using GAMS
using Test

ws = GAMSWorkspace()

const TEST_GAMSLIB_MODELS = (
   "trnsport",
   "blend",
   "prodmix",
   "whouse",
   "jobt",
   "sroute",
   "diet",
   "aircraft",
   "prodsch",
   "pdi",
   "uimp",
   "magic",
   "ferts",
   "fertd",
   "mexss",
   "mexsd",
   "mexls",
   "weapons",
   "bid",
   "process",
   "chem",
   "ship",
   "linear",
   "least",
   "like",
   "chance",
   "sample",
   "pindyck",
   "vietman",
   "marco",
   "chenery",
   "pak",
   "himmel16",
   "robert",
   "rdata",
   "mine",
   "orani",
   "cube",
   "chakra",
   "andean",
   "copper",
   "otpop",
   "korpet",
   "sarf",
   "port",
   "prodschx",
   "bidsos",
   "wallmcp",
   "transmcp",
   # "nash"
)

# create temporary working directory
curdir = pwd()
tempdir = mktempdir(prefix = "gams_jl_")
cd(tempdir)

# prepare GAMS Convert option file to write JuMP model
open("convert.opt", "w") do io
   println(io, "jump jump.jl")
end

for model in TEST_GAMSLIB_MODELS
   @testset "$model" begin

      # get model and convert to scalar GAMS and JuMP model
      Base.run(`gamslib -q $model`)
      Base.run(`gams $model.gms lo=2 solver=convert`)
      Base.run(`gams $model.gms lo=2 solver=convert optfile=1`)

      # instruct GAMS model to export objective function
      open("gams.gms", "a") do io
         println(io, "File result_file / objval.txt /;")
         println(io, "result_file.nd = 7;")
         println(io, "put result_file;")
         println(io, "put m.objval;")
         println(io, "putclose;")
      end

      # solve GAMS model
      objval_gams = NaN;
      Base.run(`gams gams.gms lo=2`)
      open("objval.txt", "r") do io
         objval_gams = parse(Float64, read(io, String))
      end

      # solve JuMP model using GAMS
      include(joinpath(tempdir, "jump.jl"))
      set_optimizer(m, GAMS.Optimizer)
      set_optimizer_attribute(m, GAMS.WorkDir(), tempdir)
      set_optimizer_attribute(m, MOI.Silent(), true)
      optimize!(m)
      objval_jump = objective_value(m)

      @test objval_gams ≈ objval_jump rtol=1e-4
   end
end

cd(curdir)
