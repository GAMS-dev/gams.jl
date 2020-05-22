
const LINE_BREAK = 120

mutable struct GAMSTranslateStream
   io::IOStream
   n_line::Int
end

GAMSTranslateStream(io::IOStream) = GAMSTranslateStream(io, 0)

function write(
   io::GAMSTranslateStream,
   str::String
)
   n = length(str)
   if io.n_line + n > LINE_BREAK
      idx = n+1
      while true
         idx = findprev(isequal(' '), str, idx-1)
         if idx == nothing || io.n_line + idx <= LINE_BREAK
            break
         end
      end
      if idx == nothing
         Base.write(io.io, "\n  ")
         io.n_line = Base.write(io.io, str)
      else
         Base.write(io.io, str[1:idx-1])
         Base.write(io.io, "\n ")
         Base.write(io.io, str[idx+1:end])
         io.n_line = n-idx
      end
   else
      Base.write(io.io, str)
      io.n_line += n
   end
end

function writeln(
   io::GAMSTranslateStream,
   str::String
)
   write(io, str)
   Base.write(io.io, "\n")
   io.n_line = 0
end

function print_float(
   f::Float64
)
   return replace(@sprintf("%.15e", f), r"(0+e)" => "e")
end

function translate_header(
   io::GAMSTranslateStream
)
   writeln(io, "*\n* GAMS Model generated by GAMS.jl\n*\n")
   writeln(io, "\$offlisting")
end

function translate_defsets(
   io::GAMSTranslateStream,
   model::Optimizer
)
   n = length(model.sos1_constraints) + length(model.sos2_constraints)
   if n == 0
      return
   elseif n == 1
      writeln(io, "Set")
   else
      writeln(io, "Sets")
   end
   write(io, "  ")

   first = true
   for (i, con) = enumerate(model.sos1_constraints)
      translate_defsets(io, model, i, con.func, con.set, first=first)
      first = false
   end
   for (i, con) = enumerate(model.sos2_constraints)
      translate_defsets(io, model, i, con.func, con.set, first=first)
      first = false
   end
   writeln(io, "\n");
end

function translate_defsets(
   io::GAMSTranslateStream,
   model::Optimizer,
   idx::Int,
   func::MOI.VectorOfVariables,
   set::Union{MOI.SOS1{Float64}, MOI.SOS2{Float64}};
   first::Bool=true
)
   if ! first
      write(io, ", ")
   end

   if typeof(set) == MOI.SOS1{Float64}
      write(io, "s1s$idx / ")
   elseif typeof(set) == MOI.SOS2{Float64}
      write(io, "s2s$idx / ")
   end

   first_elem = true
   for vi in func.variables
      if ! first_elem
         write(io, ", ")
      end
      write(io, "$(vi.value)")
      first_elem = false
   end

   write(io, " /")
end

function translate_defvars(
   io::GAMSTranslateStream,
   model::Optimizer
)
   translate_defvars(io, model, nothing)
   if model.n_binary > 0
      translate_defvars(io, model, VARTYPE_BINARY)
   end
   if model.n_integer > 0
      translate_defvars(io, model, VARTYPE_INTEGER)
   end
   if model.n_semicont > 0
      translate_defvars(io, model, VARTYPE_SEMICONT)
   end
   if model.n_semiint > 0
      translate_defvars(io, model, VARTYPE_SEMIINT)
   end
   if length(model.sos1_constraints) > 0
      translate_defvars(io, model, VARTYPE_SOS1)
   end
   if length(model.sos2_constraints) > 0
      translate_defvars(io, model, VARTYPE_SOS2)
   end
end

function translate_defvars(
   io::GAMSTranslateStream,
   model::Optimizer,
   filter::Union{GAMSVarType, Nothing}
)
   if filter == VARTYPE_SOS1
      n = length(model.sos1_constraints)
   elseif filter == VARTYPE_SOS2
      n = length(model.sos2_constraints)
   else
      n = length(model.variable_info)
   end

   if filter == VARTYPE_BINARY
      write(io, "Binary ")
   elseif filter == VARTYPE_INTEGER
      write(io, "Integer ")
   elseif filter == VARTYPE_SEMICONT
      write(io, "SemiCont ")
   elseif filter == VARTYPE_SEMIINT
      write(io, "SemiInt ")
   elseif filter == VARTYPE_SOS1
      write(io, "SOS1 ")
   elseif filter == VARTYPE_SOS2
      write(io, "SOS2 ")
   end
   if n == 1
      writeln(io, "Variable")
   else
      writeln(io, "Variables")
   end
   write(io, "  ")

   first = true
   if model.objvar && (isnothing(filter) || filter == VARTYPE_FREE)
      if n == 0
         write(io, "objvar;")
         return
      end
      write(io, "objvar")
      first = false
   end

   for i in 1:n
      if ! isnothing(filter) && model.variable_info[i].type != filter
         continue
      end
      if ! first
         write(io, ", ")
      end
      translate_variable(io, model, i)
      first = false
   end

   # add sos1 variables
   if isnothing(filter) || filter == VARTYPE_SOS1
      for i in 1:length(model.sos1_constraints)
         if ! first
            write(io, ", ")
         end
         write(io, "s1x$i(s1s$(i))")
         first = false
      end
   end

   # add sos2 variables
   if isnothing(filter) || filter == VARTYPE_SOS2
      for i in 1:length(model.sos2_constraints)
         if ! first
            write(io, ", ")
         end
         write(io, "s2x$i(s2s$(i))")
         first = false
      end
   end
   writeln(io, ";\n")
end

function translate_defequs(
   io::GAMSTranslateStream,
   model::Optimizer
)
   m = model.m + length(model.sos1_constraints)

   if m == 0 && ! model.objvar
      return
   end

   if m == 1
      writeln(io, "Equation")
   else m > 1
      writeln(io, "Equations")
   end
   write(io, "  ")

   if model.objvar && m == 0
      writeln(io, "obj;\n")
      return
   end

   first = true
   if model.objvar
      write(io, "obj")
      first = false
   end

   for i in 1:model.m
      if ! first
         write(io, ", ")
      end
      write(io, "eq$i")
      first = false
   end

   # add sos1 constrains
   for i in 1:length(model.sos1_constraints)
      if ! first
         write(io, ", ")
      end
      write(io, "s1eq$(i)(s1s$(i))")
      first = false
   end

   # add sos2 constrains
   for i in 1:length(model.sos2_constraints)
      if ! first
         write(io, ", ")
      end
      write(io, "s2eq$(i)(s2s$(i))")
      first = false
   end

   writeln(io, ";\n")
end

function translate_coefficient(
   io::GAMSTranslateStream,
   coef::Float64;
   first::Bool=false
)
   if coef < 0.0
      if first && coef == -1.0
         write(io, "-")
      elseif first
         write(io, "-" * print_float(-coef) * " * ")
      elseif coef == -1.0
         write(io, " - ")
      else
         write(io, " - " * print_float(-coef) * " * ")
      end
   elseif coef > 0.0
      if first && coef == 1.0
      elseif first
         write(io, print_float(coef) * " * ")
      elseif coef == 1.0
         write(io, " + ")
      else
         write(io, " + " * print_float(coef) * " * ")
      end
   end
   return
end

function translate_variable(
   io::GAMSTranslateStream,
   model::Optimizer,
   idx::Int
)
   if model.variable_info[idx].type == VARTYPE_FREE
      write(io, "x$idx")
   elseif model.variable_info[idx].type == VARTYPE_BINARY
      write(io, "b$idx")
   elseif model.variable_info[idx].type == VARTYPE_INTEGER
      write(io, "i$idx")
   elseif model.variable_info[idx].type == VARTYPE_SEMICONT
      write(io, "sc$idx")
   elseif model.variable_info[idx].type == VARTYPE_SEMIINT
      write(io, "si$idx")
   end
end

function translate_function(
   io::GAMSTranslateStream,
   model::Optimizer,
   func::MOI.SingleVariable
)
   translate_variable(io, model, func.variable.value)
end

function translate_function(
   io::GAMSTranslateStream,
   model::Optimizer,
   terms::Vector{MOI.ScalarAffineTerm{Float64}}
)
   if length(terms) == 0
      write(io, "0.0")
      return
   end

   first = true
   for (j, term) in enumerate(terms)
      if term.coefficient == 0.0
         continue
      end
      translate_coefficient(io, term.coefficient, first=first)
      translate_variable(io, model, term.variable_index.value)
      first = false
   end
end

function translate_function(
   io::GAMSTranslateStream,
   model::Optimizer,
   func::MOI.ScalarAffineFunction{Float64}
)
   translate_function(io, model, func.terms)
   if func.constant < 0.0
      write(io, " - " * print_float(-func.constant))
   elseif func.constant > 0.0
      write(io, " + " * print_float(func.constant))
   end
end

function translate_function(
   io::GAMSTranslateStream,
   model::Optimizer,
   func::MOI.ScalarQuadraticFunction{Float64}
)
   naff = length(func.affine_terms)

   if naff + length(func.quadratic_terms) == 0
      write(io, "0.0")
      return
   end

   first = true
   if naff > 0
      translate_function(io, model, func.affine_terms)
      first = false
   end

   for (j, term) in enumerate(func.quadratic_terms)
      if term.coefficient == 0.0
         continue
      end
      idx1 = term.variable_index_1
      idx2 = term.variable_index_2
      if idx1 == idx2
         translate_coefficient(io, term.coefficient / 2.0, first=first)
      else
         translate_coefficient(io, term.coefficient, first=first)
      end
      translate_variable(io, model, idx1.value)
      write(io, " * ")
      translate_variable(io, model, idx2.value)
      first = false
   end

   if func.constant < 0.0
      write(io, " - " * print_float(-func.constant))
   elseif func.constant > 0.0
      write(io, " + " * print_float(func.constant))
   end
end

function translate_function(
   io::GAMSTranslateStream,
   model::Optimizer,
   func::Expr;
   is_parenthesis::Bool = false
)
   if length(func.args) == 0
      write(io, "0.0")
      return
   end

   op = func.args[1]

   if op in (:+, :-)
      @assert length(func.args) >= 2
      if ! is_parenthesis
         write(io, "(")
      end
      if length(func.args) == 2
         write(io, "(" * string(op))
         translate_function(io, model, func.args[2], is_parenthesis=false)
         write(io, ")")
      else
         translate_function(io, model, func.args[2], is_parenthesis=true)
         for i in 3:length(func.args)
            write(io, " " * string(op) * " ")
            translate_function(io, model, func.args[i], is_parenthesis=true)
         end
      end
      if ! is_parenthesis
         write(io, ")")
      end

   elseif op in (:*, :/)
      @assert length(func.args) >= 3
      if ! is_parenthesis
         write(io, "(")
      end
      translate_function(io, model, func.args[2], is_parenthesis=false)
      for i in 3:length(func.args)
         write(io, " " * string(op) * " ")
         translate_function(io, model, func.args[i], is_parenthesis=false)
      end
      if ! is_parenthesis
         write(io, ")")
      end

   elseif op == :^
      @assert length(func.args) == 3
      if func.args[3] == 1.0
         translate_function(io, model, func.args[2])
      elseif func.args[3] == 2.0
         write(io, "sqr(")
         translate_function(io, model, func.args[2], is_parenthesis=true)
         write(io, ")")
      elseif func.args[3] isa Real && func.args[3] == round(func.args[3])
         write(io, "power(")
         translate_function(io, model, func.args[2], is_parenthesis=true)
         write(io, ", ")
         translate_function(io, model, func.args[3], is_parenthesis=true)
         write(io, ")")
      else
         translate_function(io, model, func.args[2], is_parenthesis=false)
         write(io, "**")
         translate_function(io, model, func.args[3], is_parenthesis=false)
      end

   elseif op in (:sqrt, :log, :log10, :log2, :exp, :sin, :sinh, :cos, :cosh, :tan, :tanh, :abs)
      @assert length(func.args) == 2
      write(io, string(op) * "(")
      translate_function(io, model, func.args[2], is_parenthesis=true)
      write(io, ")")

   elseif op in (:max, :min)
      @assert length(func.args) >= 2
      write(io, string(op) * "(")
      translate_function(io, model, func.args[2], is_parenthesis=true)
      for i in 3:length(func.args)
         write(io, ", ")
         translate_function(io, model, func.args[i], is_parenthesis=true)
      end
      write(io, ")")

   elseif typeof(op) == Symbol && func.args[2] isa MOI.VariableIndex
      translate_variable(io, model, func.args[2].value)
   else
      error("Unrecognized operation ($op)")
   end
end

function translate_function(
   io::GAMSTranslateStream,
   model::Optimizer,
   func::Float64;
   is_parenthesis::Bool = false
)
   if is_parenthesis && func > 0.0
      write(io, print_float(func))
   else
      write(io, "(" * print_float(func) * ")")
   end
end

function translate_function(
   io::GAMSTranslateStream,
   model::Optimizer,
   func::Int;
   is_parenthesis::Bool = false
)
   write(io, "$func")
end

function translate_objective(
   io::GAMSTranslateStream,
   model::Optimizer
)
   # do nothing if we don't need objective variable
   if ! model.objvar
      if ! (typeof(model.objective) == MOI.SingleVariable)
         error("GAMS needs obj variable")
      end
      return
   end

   if model.sense == MOI.MIN_SENSE
      write(io, "obj.. objvar =G= ")
   elseif model.sense == MOI.MAX_SENSE
      write(io, "obj.. objvar =L= ")
   else
      writeln(io, "obj.. objvar =E= 0.0;");
      return
   end

   if ! isnothing(model.nlp_data) && model.nlp_data.has_objective
      obj_expr = MOI.objective_expr(model.nlp_data.evaluator)
      translate_function(io, model, obj_expr, is_parenthesis=true)
   else
      translate_function(io, model, model.objective)
   end

   writeln(io, ";")
   return
end

function translate_equations(
   io::GAMSTranslateStream,
   model::Optimizer
)
   for (i, con) in enumerate(model.linear_le_constraints)
      translate_equations(io, model, i + offset_linear_le(model), con.func, con.set)
   end
   for (i, con) in enumerate(model.linear_ge_constraints)
      translate_equations(io, model, i + offset_linear_ge(model), con.func, con.set)
   end
   for (i, con) in enumerate(model.linear_eq_constraints)
      translate_equations(io, model, i + offset_linear_eq(model), con.func, con.set)
   end
   for (i, con) in enumerate(model.quadratic_le_constraints)
      translate_equations(io, model, i + offset_quadratic_le(model), con.func, con.set)
   end
   for (i, con) in enumerate(model.quadratic_ge_constraints)
      translate_equations(io, model, i + offset_quadratic_ge(model), con.func, con.set)
   end
   for (i, con) in enumerate(model.quadratic_eq_constraints)
      translate_equations(io, model, i + offset_quadratic_eq(model), con.func, con.set)
   end
   for i in 1:model.m_nonlin
      translate_equations(io, model, i + offset_nonlin(model), MOI.constraint_expr(model.nlp_data.evaluator, i))
   end
   writeln(io, "")
   for (i, con) in enumerate(model.sos1_constraints)
      translate_equations(io, model, i, con.func, con.set)
   end
   for (i, con) in enumerate(model.sos2_constraints)
      translate_equations(io, model, i, con.func, con.set)
   end
   writeln(io, "")
   return
end

function translate_equations(
   io::GAMSTranslateStream,
   model::Optimizer,
   idx::Int,
   func::Union{MOI.ScalarAffineFunction{Float64}, MOI.ScalarQuadraticFunction{Float64}},
   set::MOI.LessThan{Float64}
)
   write(io, "eq$idx.. ")
   translate_function(io, model, func)
   writeln(io, " =L= " * print_float(set.upper) * ";")
   return
end

function translate_equations(
   io::GAMSTranslateStream,
   model::Optimizer,
   idx::Int,
   func::Union{MOI.ScalarAffineFunction{Float64}, MOI.ScalarQuadraticFunction{Float64}},
   set::MOI.GreaterThan{Float64}
)
   write(io, "eq$idx.. ")
   translate_function(io, model, func)
   writeln(io, " =G= " * print_float(set.lower) * ";")
   return
end

function translate_equations(
   io::GAMSTranslateStream,
   model::Optimizer,
   idx::Int,
   func::Union{MOI.ScalarAffineFunction{Float64}, MOI.ScalarQuadraticFunction{Float64}},
   set::MOI.EqualTo{Float64}
)
   write(io, "eq$idx.. ")
   translate_function(io, model, func)
   writeln(io, " =E= " * print_float(set.value) * ";")
   return
end

function translate_equations(
   io::GAMSTranslateStream,
   model::Optimizer,
   idx::Int,
   func::Expr
)
   if length(func.args) == 0
      return
   end
   @assert(length(func.args) == 3)

   write(io, "eq$idx.. ")
   translate_function(io, model, func.args[2], is_parenthesis=true)
   if func.args[1] == :(==)
      write(io, " =E= ")
   elseif func.args[1] == :(<=)
      write(io, " =L= ")
   else
      write(io, " =G= ")
   end
   translate_function(io, model, func.args[3], is_parenthesis=true)
   writeln(io, ";")
   return
end

function translate_equations(
   io::GAMSTranslateStream,
   model::Optimizer,
   idx::Int,
   func::MOI.VectorOfVariables,
   set::MOI.SOS1{Float64}
)
   write(io, "s1eq$idx(s1s$idx).. s1x$idx(s1s$idx) =e= ")
   for (i, vi) in enumerate(func.variables)
      if i > 1
         write(io, " + ")
      end
      translate_variable(io, model, vi.value)
      write(io, "\$sameas('$(vi.value)',s1s$idx)")
   end
   writeln(io, ";")
   return
end

function translate_equations(
   io::GAMSTranslateStream,
   model::Optimizer,
   idx::Int,
   func::MOI.VectorOfVariables,
   set::MOI.SOS2{Float64}
)
   write(io, "s2eq$idx(s2s$idx).. s2x$idx(s2s$idx) =e= ")
   for (i, vi) in enumerate(func.variables)
      if i > 1
         write(io, " + ")
      end
      translate_variable(io, model, vi.value)
      write(io, "\$sameas('$(vi.value)',s2s$idx)")
   end
   writeln(io, ";")
   return
end

function translate_vardata(
   io::GAMSTranslateStream,
   model::Optimizer
)
   for (i, var) in enumerate(model.variable_info)
      if is_fixed(var)
         translate_variable(io, model, i)
         writeln(io, ".fx = " * print_float(var.lower_bound) * ";")
         continue
      end
      if has_lower_bound(var)
         translate_variable(io, model, i)
         writeln(io, ".lo = " * print_float(var.lower_bound) * "; ")
      end
      if has_start(var)
         translate_variable(io, model, i)
         writeln(io, ".l = " * print_float(var.start) * "; ")
      end
      if has_upper_bound(var)
         translate_variable(io, model, i)
         writeln(io, ".up = " * print_float(var.upper_bound) * ";")
      end
   end
   write(io, "\n")
end

function translate_solve(
   io::GAMSTranslateStream,
   model::Optimizer,
   name::String
)
   writeln(io, "Model $name / all /;")
   write(io, "Solve $name using ")
   write(io, label(model.mtype))
   if model.sense == MOI.MAX_SENSE
      write(io, " maximizing ")
   else
      write(io, " minimizing ")
   end
   if model.objvar
      writeln(io, "objvar;\n")
   elseif typeof(model.objective) == MOI.SingleVariable
      translate_variable(io, model, model.objective.variable.value)
      writeln(io, ";\n")
   else
      error("GAMS needs obj variable")
   end
end
