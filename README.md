
# GAMS.jl

GAMS.jl provides a
[MathOptInterface](https://github.com/JuliaOpt/MathOptInterface.jl) Optimizer to
solve [JuMP](https://github.com/JuliaOpt/JuMP.jl) models using
[GAMS](https://www.gams.com/).

GAMS comes with dozens of supported solvers. Among them are:
[ALPHAECP](https://www.gams.com/latest/docs/S_ALPHAECP.html),
[ANTIGONE](https://www.gams.com/latest/docs/S_ANTIGONE.html),
[BARON](https://www.gams.com/latest/docs/S_BARON.html),
[BDMLP](https://www.gams.com/latest/docs/S_BDMLP.html),
[BONMIN](https://www.gams.com/latest/docs/S_BONMIN.html),
[CBC](https://www.gams.com/latest/docs/S_CBC.html),
[CONOPT](https://www.gams.com/latest/docs/S_CONOPT.html),
[COUENNE](https://www.gams.com/latest/docs/S_COUENNE.html),
[CPLEX](https://www.gams.com/latest/docs/S_CPLEX.html),
[DICOPT](https://www.gams.com/latest/docs/S_DICOPT.html),
[GLOMIQO](https://www.gams.com/latest/docs/S_GLOMIQO.html),
[GUROBI](https://www.gams.com/latest/docs/S_GUROBI.html),
[IPOPT](https://www.gams.com/latest/docs/S_IPOPT.html),
[KNITRO](https://www.gams.com/latest/docs/S_KNITRO.html),
[LGO](https://www.gams.com/latest/docs/S_LGO.html),
[LINDO](https://www.gams.com/latest/docs/S_LINDO.html),
[LINDOGLOBAL](https://www.gams.com/latest/docs/S_LINDO.html),
[LOCALSOLVER](https://www.gams.com/latest/docs/S_LOCALSOLVER.html),
[MINOS](https://www.gams.com/latest/docs/S_MINOS.html),
[MOSEK](https://www.gams.com/latest/docs/S_MOSEK.html),
[MSNLP](https://www.gams.com/latest/docs/S_MSNLP.html),
[NLPEC](https://www.gams.com/latest/docs/S_NLPEC.html),
[PATH](https://www.gams.com/latest/docs/S_PATH.html),
[QUADMINOS](https://www.gams.com/latest/docs/S_MINOS.html),
[SBB](https://www.gams.com/latest/docs/S_SBB.html),
[SHOT](https://www.gams.com/latest/docs/S_SHOT.html),
[SCIP](https://www.gams.com/latest/docs/S_SCIP.html),
[SNOPT](https://www.gams.com/latest/docs/S_SNOPT.html),
[SOPLEX](https://www.gams.com/latest/docs/S_SOPLEX.html),
[XA](https://www.gams.com/latest/docs/S_XA.html),
[XPRESS](https://www.gams.com/latest/docs/S_XPRESS.html).
Find a complete list [here](https://www.gams.com/latest/docs/S_MAIN.html).

GAMS.jl supports the following JuMP features:
- linear, quadratic and nonlinear (convex and non-convex) objective and constraints
- continuous, binary, integer, semi-continuous and semi-integer variables
- SOS1 and SOS2 sets
- complementarity constraints


## Installation

1. [Download GAMS](https://www.gams.com/download/) and obtain a
GAMS license. Please note that GAMS also offers a [free community
license](https://www.gams.com/latest/docs/UG_License.html#GAMS_Community_Licenses).
2. (optional) Add the GAMS system directory to the `PATH` variable in order to
find GAMS automatically.
3. Install GAMS.jl using the Julia package manager:
```julia
using Pkg
Pkg.add("GAMS")
```

## Usage

Using GAMS as optimizer for your JuMP model:
```julia
using GAMS, JuMP
model = Model(GAMS.Optimizer)
```

### GAMS Options

#### Solver

Choosing a GAMS solver (one of the following):
```julia
set_optimizer_attribute(model, "Solver", "<solver_name>")
set_optimizer_attribute(model, GAMS.Solver(), "<solver_name>")
```
Other [GAMS command line options](https://www.gams.com/latest/docs/UG_GamsCall.html#UG_GamsCall_ListOfCommandLineParameters) can be specified the same way. GAMS.jl
supports the command line options
[HoldFixed](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOholdfixed),
[IterLim](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOiterlim),
[LogOption](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOlogoption),
[NodLim](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOnodlim),
[OptCA](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOoptca),
[OptCR](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOoptcr),
[ResLim](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOreslim),
[Solver](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOsolver),
[Threads](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOthreads),
[Trace](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOtrace),
[TraceOpt](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOtraceopt) as well as
[LP](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOlp),
[MIP](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOmip),
[RMIP](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOrmip),
[NLP](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOnlp),
[DNLP](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOdnlp),
[CNS](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOcns),
[MINLP](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOminlp),
[RMINLP](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOrminlp),
[QCP](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOqcp),
[MIQCP](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOmiqcp),
[RMIQCP](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOrmiqcp),
[MCP](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOmcp) and
[MPEC](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOmpec).
Note that `GAMS.ResLim()` is equivalent to `MOI.TimeLimitSec()` and
`GAMS.Threads()` to `MOI.NumberOfThreads()`.

#### Model Type

GAMS.jl will automatically choose a [GAMS model
type](https://www.gams.com/latest/docs/UG_ModelSolve.html#UG_ModelSolve_ModelClassificationOfModels)
for you. Choosing a different model type:
```julia
set_optimizer_attribute(model, GAMS.ModelType(), "<model_type>")
```

#### GAMS System

If the GAMS system directory has been added to the `PATH` variable, GAMS.jl will find
it automatically. Otherwise, or if you like to switch between systems, the
system directory can be specified by (one of the following):
```julia
set_optimizer_attribute(model, "SysDir", "<gams_system_dir>")
set_optimizer_attribute(model, GAMS.SysDir(), "<gams_system_dir>")
```

### GAMS Solver Options

Specifying GAMS solver options:
```julia
set_optimizer_attribute(model, "<solver_option_name>", <option_value>)
```
Note that passing a solver option is only valid when exlicitly choosing a GAMS
solver and not using the default.

### Checking Solver Support

In order to check, if a GAMS solver is licensed (and supports a given [GAMS
model
type](https://www.gams.com/latest/docs/UG_ModelSolve.html#UG_ModelSolve_ModelClassificationOfModels)),
do
```julia
GAMS.check_solver(GAMS.GAMSWorkspace(), "<solver_name>")
GAMS.check_solver(GAMS.GAMSWorkspace(), "<solver_name>", "<model_type>")
```
