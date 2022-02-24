
using GAMS

println("")
println("-"^30)
println("Translate Tests")
println("-"^30)
println("")
include("translate.jl")

println("")
println("-"^30)
println("MathOptInterface Tests")
println("-"^30)
println("")
include("MOI_wrapper.jl")

# we need GAMS 34.3 for JuMP output in Convert
ver = GAMS.get_version(GAMS.GAMSWorkspace())
ver = "$(ver[1]).$(ver[2]).$(ver[3])"
if ver >= "34.3.0"
    println("")
    println("-"^30)
    println("GAMS Model Library Tests")
    println("-"^30)
    println("")
    include("gamslib.jl")
end

println("")
println("-"^30)
println("Complementarity Tests")
println("-"^30)
println("")
include("complementarity.jl")
