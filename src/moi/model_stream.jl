
const LINE_BREAK = 120

mutable struct ModelStream
    io::IOStream
    n_line::Int
end

ModelStream(io::IOStream) = ModelStream(io, 0)

num2str(value::Number) = @sprintf("%.16g", value)

coeff2str(coeff::Float64, first::Bool = false) =
    if first && coeff == -1.0
        return "-"
    elseif first && coeff == 1.0
        return ""
    elseif first && coeff < 0.0
        return "-" * num2str(-coeff) * " * "
    elseif first && coeff > 0.0
        return num2str(coeff) * " * "
    elseif coeff == -1.0
        return " - "
    elseif coeff == 1.0
        return " + "
    elseif coeff < 0
        return " - " * num2str(-coeff) * " * "
    elseif coeff > 0
        return " + " * num2str(coeff) * " * "
    else
        return ""
    end

function write(io::ModelStream, str::String)
    n = length(str)
    if io.n_line + n > LINE_BREAK
        idx = n + 1
        while true
            idx = findprev(isequal(' '), str, idx - 1)
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
            io.n_line = n - idx
        end
    else
        Base.write(io.io, str)
        io.n_line += n
    end
end

function writeln(io::ModelStream, str::String)
    write(io, str)
    Base.write(io.io, "\n")
    return io.n_line = 0
end

#####################################################################
##  Terms                                                          ##
#####################################################################

write(io::ModelStream, term::MOI.VariableIndex) = write(io, gms_name(term))

function write(io::ModelStream, terms::Vector{MOI.ScalarAffineTerm{Float64}})
    first = true
    for (j, term) in enumerate(terms)
        if term.coefficient != 0.0
            write(io, coeff2str(term.coefficient, first))
            write(io, gms_name(term.variable))
            first = false
        end
    end
    if first
        write(io, "0.0")
    end
end

#####################################################################
##  Functions                                                      ##
#####################################################################

function write(io::ModelStream, func::MOI.ScalarAffineFunction{Float64})
    write(io, func.terms)
    if func.constant < 0.0
        write(io, " - " * num2str(-func.constant))
    elseif func.constant > 0.0
        write(io, " + " * num2str(func.constant))
    end
end

function write(io::ModelStream, func::MOI.ScalarQuadraticFunction{Float64})
    if length(func.affine_terms) + length(func.quadratic_terms) == 0
        write(io, num2str(func.constant))
        return
    end

    # linear term
    first = true
    if length(func.affine_terms) > 0
        write(io, func.affine_terms)
        first = false
    end

    # quadratic term
    for (i, term) in enumerate(func.quadratic_terms)
        coeff = term.coefficient
        if coeff == 0.0
            continue
        end
        if term.variable_1 == term.variable_2
            coeff /= 2.0
        end
        write(
            io,
            coeff2str(coeff, first) * gms_name(term.variable_1) * " * " * gms_name(term.variable_2),
        )
        first = false
    end

    # constant term
    if func.constant < 0.0
        write(io, " - " * num2str(-func.constant))
    elseif func.constant > 0.0
        write(io, " + " * num2str(func.constant))
    end
end

#####################################################################
##  Sets                                                           ##
#####################################################################

write(io::ModelStream, set::MOI.GreaterThan{Float64}) = write(io, " =G= " * num2str(set.lower))

write(io::ModelStream, set::MOI.LessThan{Float64}) = write(io, " =L= " * num2str(set.upper))

write(io::ModelStream, set::MOI.EqualTo{Float64}) = write(io, " =E= " * num2str(set.value))

#####################################################################
##  Expressions                                                    ##
#####################################################################

write(io::ModelStream, num::Number) = write(io, num2str(num))

function write(io::ModelStream, expr::Union{Expr, MOI.ScalarNonlinearFunction})
    if expr isa MOI.ScalarNonlinearFunction
        head = expr.head
        args = expr.args
    else
        if length(expr.args) == 0
            write(io, "0.0")
            return
        end
        head = expr.args[1]
        args = expr.args[2:end]
    end

    if head in (:+, :-)
        @assert length(args) >= 1
        if length(args) == 1
            write(io, "(" * string(head) * "(")
            write(io, args[1])
            write(io, "))")
        else
            write(io, args[1])
            for i in 2:length(args)
                write(io, " " * string(head) * " ")
                if head == :-
                    write(io, "(")
                end
                write(io, args[i])
                if head == :-
                    write(io, ")")
                end
            end
        end

    elseif head in (:*, :/)
        @assert length(args) >= 2
        write(io, "(")
        write(io, args[1])
        write(io, ")")
        for i in 2:length(args)
            write(io, " " * string(head) * " (")
            write(io, args[i])
            write(io, ")")
        end

    elseif head == :^
        @assert length(args) == 2
        if args[2] == 1.0
            write(io, args[2])
        elseif args[2] == 2.0
            write(io, "sqr(")
            write(io, args[1])
            write(io, ")")
        elseif args[2] isa Real && args[2] == round(args[2])
            write(io, "power(")
            write(io, args[1])
            write(io, ", ")
            write(io, args[2])
            write(io, ")")
        else
            write(io, "(")
            write(io, args[1])
            write(io, ")**(")
            write(io, args[2])
            write(io, ")")
        end

    elseif head in
           (:sqrt, :log, :log10, :log2, :exp, :sin, :sinh, :cos, :cosh, :tan, :tanh, :abs, :sign)
        @assert length(args) == 1
        write(io, string(head) * "(")
        write(io, args[1])
        write(io, ")")

    elseif head in (:acos,)
        @assert length(args) == 1
        write(io, "arccos(")
        write(io, args[1])
        write(io, ")")

    elseif head in (:asin,)
        @assert length(args) == 1
        write(io, "arcsin(")
        write(io, args[1])
        write(io, ")")

    elseif head in (:atan,)
        @assert length(args) == 1
        write(io, "arctan(")
        write(io, args[1])
        write(io, ")")

    elseif head in (:max, :min, :mod)
        @assert length(args) >= 1
        write(io, string(head) * "(")
        write(io, args[1])
        for i in 2:length(args)
            write(io, ", ")
            write(io, args[i])
        end
        write(io, ")")

    elseif typeof(head) == Symbol && args[1] isa MOI.VariableIndex
        write(io, args[1])

    else
        throw(MOI.UnsupportedNonlinearOperator(head))
    end
end

#####################################################################
##  Model                                                          ##
#####################################################################

function write(io::ModelStream, model::Optimizer)
    writeln(io, "*\n* GAMS Model generated by GAMS.jl\n*\n")
    writeln(io, "\$offlisting\n")

    # check model characteristics
    is_discrete = length(model.sos_constraints) > 0
    if !is_discrete
        for v in model.variables
            if v.type in [:Binary, :Integer, :SemiCont, :SemiInt]
                is_discrete = true
                break
            end
        end
    end
    is_quadratic = typeof(model.objective) == MOI.ScalarQuadraticFunction{Float64}
    if !is_quadratic
        for c in model.constraints
            if typeof(c.func) == MOI.ScalarQuadraticFunction{Float64}
                is_quadratic = true
                break
            end
        end
    end
    is_nonlinear =
        typeof(model.objective) == MOI.ScalarNonlinearFunction ||
        !isnothing(model.nlp_data) &&
        (length(model.nlp_data.constraint_bounds) > 0 || model.nlp_data.has_objective)
    if !is_nonlinear
        for c in model.constraints
            if typeof(c.func) == MOI.ScalarNonlinearFunction
                is_nonlinear = true
                break
            end
        end
    end
    is_compl = length(model.compl_constraints) > 0

    # detect model type
    model_type = model.type
    if isnothing(model_type)
        if is_compl
            model_type = :MPEC
        elseif is_nonlinear && is_discrete
            model_type = :MINLP
        elseif is_nonlinear
            model_type = :NLP
        elseif is_quadratic && is_discrete
            model_type = :MIQCP
        elseif is_quadratic
            model_type = :QCP
        elseif is_discrete
            model_type = :MIP
        else
            model_type = :LP
        end
    else
        if model_type == :LP
            if is_compl
                model_type = :MPEC
            elseif is_quadratic
                model_type = :QCP
            elseif is_nonlinear
                model_type = :NLP
            elseif is_discrete
                model_type = :MIP
            end
        end
        if model_type == :MIP
            if is_compl
                model_type = :MPEC
            elseif is_quadratic
                model_type = :MIQCP
            elseif is_nonlinear
                model_type = :MINLP
            end
        end
        if model_type == :QCP
            if is_compl
                model_type = :MPEC
            elseif is_nonlinear
                model_type = :NLP
            elseif is_discrete
                model_type = :MIQCP
            end
        end
        if model_type == :MIQCP
            if is_compl
                model_type = :MPEC
            elseif is_nonlinear
                model_type = :MINLP
            end
        end
        if model_type == :NLP
            if is_compl
                model_type = :MPEC
            elseif is_discrete
                model_type = :MINLP
            end
        end
    end

    # sos constraints definitions
    has_sos = length(model.sos_constraints) > 0
    if has_sos
        sos_ci = [[], []]

        # set definitions for sos constraints
        writeln(io, "Sets")
        write(io, "  ")
        first = true
        for (i, c) in enumerate(model.sos_constraints)
            ci = MOI.ConstraintIndex{typeof(c.func), typeof(c.set)}(i)
            name = gms_name(ci) * "_s / "
            write(io, first ? name : ", " * name)
            first_elem = true
            for vi in c.func.variables
                write(io, first_elem ? "$(vi.value)" : ", $(vi.value)")
                first_elem = false
            end
            write(io, " /")
            first = false
            if typeof(c.set) == MOI.SOS1{Float64}
                push!(sos_ci[1], ci)
            else
                push!(sos_ci[2], ci)
            end
        end
        writeln(io, ";\n")

        # variable definitions for sos constraints
        for k in [1, 2]
            if length(sos_ci[k]) > 0
                writeln(io, "SOS$k Variables")
                write(io, "  ")
                first = true
                for ci in sos_ci[k]
                    name = gms_name(ci) * "_x(" * gms_name(ci) * "_s)"
                    write(io, first ? name : ", " * name)
                    first = false
                end
                writeln(io, ";\n")
            end
        end

        # constraint definitions for sos constraints
        writeln(io, "Equations")
        write(io, "  ")
        first = true
        for (i, c) in enumerate(model.sos_constraints)
            ci = MOI.ConstraintIndex{typeof(c.func), typeof(c.set)}(i)
            name = gms_name(ci) * "(" * gms_name(ci) * "_s)"
            write(io, first ? name : ", " * name)
            first = false
        end
        writeln(io, ";\n")
    end

    # group variables by type
    variables_by_type = Dict{Symbol, Vector{MOI.VariableIndex}}()
    for (i, v) in enumerate(model.variables)
        vi = MOI.VariableIndex(i)
        if haskey(variables_by_type, v.type)
            push!(variables_by_type[v.type], vi)
        else
            variables_by_type[v.type] = [vi]
        end
    end

    # variable definition
    for (type, vis) in variables_by_type
        write(io, string(type))
        writeln(io, " Variables")
        write(io, "  ")
        first = true
        for vi in vis
            write(io, first ? gms_name(vi) : ", " * gms_name(vi))
            first = false
        end
        writeln(io, ";\n")
    end

    # objective variable definition
    has_objective =
        !isnothing(model.objective) || (!isnothing(model.nlp_data) && model.nlp_data.has_objective)
    has_var_objective = has_objective && typeof(model.objective) == MOI.VariableIndex
    has_dummy_objective = !has_objective && model_type != :MCP && model_type != :CNS
    if has_objective || has_dummy_objective
        writeln(io, "Free Variable")
        writeln(io, "  objvar;\n")
    end

    # constraint definition
    if length(model.constraints) > 0
        writeln(io, "Equations")
        write(io, "  ")
        first = true
        for (i, c) in enumerate(model.constraints)
            ci = MOI.ConstraintIndex{typeof(c.func), typeof(c.set)}(i)
            write(io, first ? gms_name(ci) : ", " * gms_name(ci))
            first = false
        end
        writeln(io, ";\n")
    end

    # nonlinear constraint definition
    n_nonlin_block = isnothing(model.nlp_data) ? 0 : length(model.nlp_data.constraint_bounds)
    if n_nonlin_block > 0
        writeln(io, "Equations")
        write(io, "  ")
        first = true
        for i in 1:n_nonlin_block
            write(io, first ? "nlp_eq$i" : ", nlp_eq$i")
            first = false
        end
        writeln(io, ";\n")
    end

    # complementarity constraint definition
    if length(model.compl_constraints) > 0
        writeln(io, "Equations")
        write(io, "  ")
        first = true
        for (i, c) in enumerate(model.compl_constraints)
            for j in 1:(c.set.dimension÷2)
                write(io, first ? "compl_eq$(i)_$(j)" : ", compl_eq$(i)_$(j)")
            end
            first = false
        end
        writeln(io, ";\n")
    end

    # objective definition
    if has_objective || has_dummy_objective
        writeln(io, "Equation")
        writeln(io, "  obj;\n")
    end

    equation_names = []
    list_equation_names = false

    # objective
    if has_objective || has_dummy_objective
        push!(equation_names, "obj")
        if model.sense == MOI.MIN_SENSE
            write(io, "obj.. objvar =G= ")
        elseif model.sense == MOI.MAX_SENSE
            write(io, "obj.. objvar =L= ")
        else
            write(io, "obj.. objvar =E= ")
        end
        if has_dummy_objective
            write(io, "0.0")
        elseif !isnothing(model.nlp_data) && model.nlp_data.has_objective
            write(io, MOI.objective_expr(model.nlp_data.evaluator))
        elseif has_objective
            write(io, model.objective)
        else
            write(io, "0.0")
        end
        writeln(io, ";\n")
    end

    # sos constraints
    if has_sos
        for (i, c) in enumerate(model.sos_constraints)
            ci = MOI.ConstraintIndex{typeof(c.func), typeof(c.set)}(i)
            name = gms_name(ci)
            push!(equation_names, name)
            write(io, name * "(" * name * "_s).. " * name * "_x(" * name * "_s) =e= ")
            for (j, vi) in enumerate(c.func.variables)
                if j > 1
                    write(io, " + ")
                end
                write(io, gms_name(vi) * "\$sameas('$(vi.value)', " * name * "_s)")
            end
            writeln(io, ";")
        end
        writeln(io, "")
    end

    # constraints
    if length(model.constraints) > 0
        for (i, c) in enumerate(model.constraints)
            ci = MOI.ConstraintIndex{typeof(c.func), typeof(c.set)}(i)
            name = gms_name(ci)
            push!(equation_names, name)
            write(io, name * ".. ")
            write(io, model.constraints[ci.value].func)
            write(io, model.constraints[ci.value].set)
            writeln(io, ";")
        end
        writeln(io, "")
    end

    # nonlinear constraints
    if n_nonlin_block > 0
        for i in 1:n_nonlin_block
            name = "nlp_eq$i"
            push!(equation_names, name)
            write(io, name * ".. ")
            expr = MOI.constraint_expr(model.nlp_data.evaluator, i)
            @assert(length(expr.args) == 3)
            write(io, expr.args[2])
            if expr.args[1] == :(==)
                write(io, " =E= ")
            elseif expr.args[1] == :(<=)
                write(io, " =L= ")
            else
                write(io, " =G= ")
            end
            write(io, expr.args[3])
            writeln(io, ";")
        end
        writeln(io, "")
    end

    # complementarity constraints
    if length(model.compl_constraints) > 0
        list_equation_names = true
        for (i, c) in enumerate(model.compl_constraints), j in 1:c.set.dimension÷2
            name = "compl_eq$(i)_$(j)"
            write(io, name * ".. ")
            terms = filter(term -> term.output_index == j, c.func.terms)
            write(io, [term.scalar_term for term in terms])
            constant_sign = c.func.constants[j] < 0 ? " - " : " + "
            writeln(io, constant_sign * num2str(abs(c.func.constants[j])) * " =N= 0;")
            terms = filter(term -> term.output_index == j + c.set.dimension ÷ 2, c.func.terms)
            @assert length(terms) == 1
            push!(equation_names, name * "." * gms_name(terms[1].scalar_term.variable))
        end
        writeln(io, "")
    end

    # variable bound constraints / variable start
    for (i, v) in enumerate(model.variables)
        has_written = false
        if !isinf(v.lower_bound)
            write(io, gms_name(MOI.VariableIndex(i)) * ".lo = " * num2str(v.lower_bound) * "; ")
            has_written = true
        end
        if !isnothing(v.start)
            write(io, gms_name(MOI.VariableIndex(i)) * ".l = " * num2str(v.start) * "; ")
            has_written = true
        end
        if !isinf(v.upper_bound)
            write(io, gms_name(MOI.VariableIndex(i)) * ".up = " * num2str(v.upper_bound) * ";")
            has_written = true
        end
        if has_written
            writeln(io, "")
        end
    end
    writeln(io, "")

    # model statement
    write(io, "Model $(model.name) / ")
    if list_equation_names
        first = true
        for name in equation_names
            write(io, first ? name : ", " * name)
            first = false
        end
    else
        write(io, "all")
    end
    writeln(io, " /;")

    # solve statement
    write(io, "Solve $(model.name) using " * string(model_type))
    if has_objective || has_dummy_objective
        write(io, model.sense == MOI.MAX_SENSE ? " maximizing " : " minimizing ")
        if has_var_objective
            write(io, gms_name(model.objective))
        else
            write(io, "objvar")
        end
    end
    return writeln(io, ";\n")
end

write(filename::String, model::Optimizer) =
    open(filename, "w") do fio
        return write(ModelStream(fio), model)
    end
