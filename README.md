
# GAMS.jl

GAMS.jl provides a
[MathOptInterface](https://github.com/JuliaOpt/MathOptInterface.jl) Optimizer to
solve [JuMP](https://github.com/JuliaOpt/JuMP.jl) models using
[GAMS](https://www.gams.com/).

GAMS integrates many state-of-the-art solvers. Supported GAMS solvers by GAMS.jl
are:
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
[PATH](https://www.gams.com/latest/docs/S_PATH.html),
[QUADMINOS](https://www.gams.com/latest/docs/S_MINOS.html),
[SBB](https://www.gams.com/latest/docs/S_SBB.html),
[SCIP](https://www.gams.com/latest/docs/S_SCIP.html),
[SNOPT](https://www.gams.com/latest/docs/S_SNOPT.html),
[SOPLEX](https://www.gams.com/latest/docs/S_SOPLEX.html),
[XA](https://www.gams.com/latest/docs/S_XA.html),
[XPRESS](https://www.gams.com/latest/docs/S_XPRESS.html).

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

GAMS.jl will automatically choose a [GAMS model
type](https://www.gams.com/latest/docs/UG_ModelSolve.html#UG_ModelSolve_ModelClassificationOfModels)
for you. Choosing a different model type:
```
set_optimizer_attribute(model, GAMS.type(), "<model_type>")
```
Supported [GAMS model
types](https://www.gams.com/latest/docs/UG_ModelSolve.html#UG_ModelSolve_ModelClassificationOfModels)
are LP, MIP, RMIP, NLP, MINLP, RMINLP, QCP, MIQCP and RMIQCP.

### GAMS Solver Options

Specifying GAMS solver options:
```
set_optimizer_attribute(model, "<solver_option_name>", <option_value>)
```
Note that passing a solver option is only valid when exlicitly choosing a GAMS
solver and not using the default.

### Checking Solver Support

In order to check, if a GAMS solver is licensed (and supports a given [GAMS
model
type](https://www.gams.com/latest/docs/UG_ModelSolve.html#UG_ModelSolve_ModelClassificationOfModels)),
do
```
GAMS.check_solver(GAMS.GAMSWorkspace(), "<solver_name>")
GAMS.check_solver(GAMS.GAMSWorkspace(), "<solver_name>", "<model_type>")
```
