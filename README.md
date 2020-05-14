
# GAMS.jl

GAMS.jl provides a
[MathOptInterface](https://github.com/JuliaOpt/MathOptInterface.jl) Optimizer to
solve [JuMP](https://github.com/JuliaOpt/JuMP.jl) models using
[GAMS](https://www.gams.com/).

GAMS integrates many state-of-the-art solvers. Supported GAMS solvers by GAMS.jl
are:
[ALPHAECP](https://www.gams.com/latest/docs/),
[ANTIGONE](https://www.gams.com/latest/docs/),
[BARON](https://www.gams.com/latest/docs/),
[BDMLP](https://www.gams.com/latest/docs/),
[BONMIN](https://www.gams.com/latest/docs/),
[CBC](https://www.gams.com/latest/docs/),
[CONOPT](https://www.gams.com/latest/docs/),
[COUENNE](https://www.gams.com/latest/docs/),
[CPLEX](https://www.gams.com/latest/docs/),
[DICOPT](https://www.gams.com/latest/docs/),
[GLOMIQO](https://www.gams.com/latest/docs/),
[GUROBI](https://www.gams.com/latest/docs/),
[IPOPT](https://www.gams.com/latest/docs/),
[KNITRO](https://www.gams.com/latest/docs/),
[LGO](https://www.gams.com/latest/docs/),
[LINDO](https://www.gams.com/latest/docs/),
[LINDOGLOBAL](https://www.gams.com/latest/docs/),
[LOCALSOLVER](https://www.gams.com/latest/docs/),
[MINOS](https://www.gams.com/latest/docs/),
[MOSEK](https://www.gams.com/latest/docs/),
[MSNLP](https://www.gams.com/latest/docs/),
[PATH](https://www.gams.com/latest/docs/),
[QUADMINOS](https://www.gams.com/latest/docs/),
[SBB](https://www.gams.com/latest/docs/),
[SCIP](https://www.gams.com/latest/docs/),
[SNOPT](https://www.gams.com/latest/docs/),
[SOPLEX](https://www.gams.com/latest/docs/),
[XA](https://www.gams.com/latest/docs/),
[XPRESS](https://www.gams.com/latest/docs/).

GAMS.jl supports the following JuMP features:
- linear, quadratic and nonlinear (convex and non-convex) objective and constraints
- continuous, binary, integer, semi-continuous and semi-integer variables
- SOS1 and SOS2 sets


## Installation

First, you need to [download GAMS](https://www.gams.com/download/) and obtain a
GAMS license. Add the GAMS system directory to the `PATH` variable.

GAMS.jl can be installed by:
```
using Pkg
Pkg.add("GAMS")
```

## Usage

Using GAMS as optimizer for your JuMP model:
```
using GAMS, JuMP
model = Model(GAMS.Optimizer)
```

### GAMS Options

Choosing a GAMS solver (one of the following):
```
set_optimizer_attribute(model, "solver", "<solver_name>")
set_optimizer_attribute(model, GAMS.solver(), "<solver_name>")
```
Other [GAMS command line options](https://www.gams.com/latest/docs/UG_GamsCall.html#UG_GamsCall_ListOfCommandLineParameters) can be specified the same way. GAMS.jl
supports the command line options
[reslim](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOreslim),
[iterlim](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOiterlim),
[holdfixed](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOholdfixed),
[nodlim](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOnodlim),
[optca](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOoptca),
[optcr](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOoptcr),
[solver](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOsolver),
[threads](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOthreads) and
[logoption](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOlogoption).
Note that `GAMS.reslim()` is equivalent to `MOI.TimeLimitSec()` and
`GAMS.threads()` to `MOI.NumberOfThreads()`.

Specifying GAMS solver options:
```
set_optimizer_attribute(model, "<solver_option_name>", <option_value>)
```
Note that passing a solver option is only valid when exlicitly choosing a GAMS
solver and not using the default.

GAMS.jl will automatically choose a [GAMS model
type](https://www.gams.com/latest/docs/UG_ModelSolve.html#UG_ModelSolve_ModelClassificationOfModels)
for you. Choosing a different model type:
```
set_optimizer_attribute(model, GAMS.type(), "<model_type>")
```
Supported [GAMS model
types](https://www.gams.com/latest/docs/UG_ModelSolve.html#UG_ModelSolve_ModelClassificationOfModels)
are LP, MIP, RMIP, NLP, MINLP, RMINLP, QCP, MIQCP and RMIQCP.

### Checking Solver Support

In order to check, if a GAMS solver is licensed (and supports a given [GAMS
model
type](https://www.gams.com/latest/docs/UG_ModelSolve.html#UG_ModelSolve_ModelClassificationOfModels)),
do
```
GAMS.check_solver(GAMS.GAMSWorkspace(), "<solver_name>")
GAMS.check_solver(GAMS.GAMSWorkspace(), "<solver_name>", "<model_type>")
```

## Support, Bug Reports And Feature Requests

TODO
