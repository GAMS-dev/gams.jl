# High-level GDX file API for GAMS.jl
# User-friendly interface for reading and writing GDX files

using DataFrames

# =============================================================================
# Symbol types
# =============================================================================

abstract type GDXSymbol end

"""
    GDXSet

A GAMS set with its elements and optional explanatory text.
"""
struct GDXSet <: GDXSymbol
    name::String
    description::String
    domain::Vector{String}
    records::DataFrame
end

"""
    GDXParameter

A GAMS parameter with domain and values.
"""
struct GDXParameter <: GDXSymbol
    name::String
    description::String
    domain::Vector{String}
    records::DataFrame
end

"""
    GDXVariable

A GAMS variable with level, marginal, lower, upper, and scale values.
"""
struct GDXVariable <: GDXSymbol
    name::String
    description::String
    domain::Vector{String}
    vartype::Int
    records::DataFrame
end

"""
    GDXEquation

A GAMS equation with level, marginal, lower, upper, and scale values.
"""
struct GDXEquation <: GDXSymbol
    name::String
    description::String
    domain::Vector{String}
    equtype::Int
    records::DataFrame
end

# =============================================================================
# GDXFile container
# =============================================================================

"""
    GDXFile

Container for GDX file contents. Provides dictionary-like access to symbols.

# Example
```julia
gdx = read_gdx("model.gdx")
gdx[:demand]  # Access parameter as DataFrame
list_parameters(gdx)  # List all parameters
```
"""
struct GDXFile
    path::String
    symbols::Dict{Symbol, GDXSymbol}
end

function Base.show(io::IO, gdx::GDXFile)
    println(io, "GDXFile: ", gdx.path)
    sets = list_sets(gdx)
    params = list_parameters(gdx)
    vars = list_variables(gdx)
    eqns = list_equations(gdx)
    isempty(sets) || println(io, "  Sets ($(length(sets))): ", join(sets, ", "))
    isempty(params) || println(io, "  Parameters ($(length(params))): ", join(params, ", "))
    isempty(vars) || println(io, "  Variables ($(length(vars))): ", join(vars, ", "))
    isempty(eqns) || println(io, "  Equations ($(length(eqns))): ", join(eqns, ", "))
end

# Symbol listing functions
list_sets(gdx::GDXFile) = Symbol[k for (k, v) in gdx.symbols if v isa GDXSet]
list_parameters(gdx::GDXFile) = Symbol[k for (k, v) in gdx.symbols if v isa GDXParameter]
list_variables(gdx::GDXFile) = Symbol[k for (k, v) in gdx.symbols if v isa GDXVariable]
list_equations(gdx::GDXFile) = Symbol[k for (k, v) in gdx.symbols if v isa GDXEquation]
list_symbols(gdx::GDXFile) = collect(keys(gdx.symbols))

# Dictionary-like access
Base.getindex(gdx::GDXFile, sym::Symbol) = gdx.symbols[sym].records
Base.getindex(gdx::GDXFile, sym::String) = gdx[Symbol(sym)]
Base.haskey(gdx::GDXFile, sym::Symbol) = haskey(gdx.symbols, sym)
Base.keys(gdx::GDXFile) = keys(gdx.symbols)

# Property access for tab completion
function Base.propertynames(gdx::GDXFile, private::Bool=false)
    (fieldnames(GDXFile)..., keys(gdx.symbols)...)
end

function Base.getproperty(gdx::GDXFile, sym::Symbol)
    sym in fieldnames(GDXFile) && return getfield(gdx, sym)
    haskey(gdx.symbols, sym) && return gdx.symbols[sym].records
    error("Symbol :$sym not found in GDX file")
end

# =============================================================================
# Reading GDX files
# =============================================================================

"""
    read_gdx(filepath::String; parse_integers=true) -> GDXFile

Read a GDX file and return a GDXFile container with all symbols.

# Arguments
- `filepath`: Path to the GDX file
- `parse_integers`: If true, attempt to parse set elements that look like integers as Int

# Example
```julia
gdx = read_gdx("transport.gdx")
demand = gdx[:demand]  # Get parameter as DataFrame
```
"""
function read_gdx(filepath::String; parse_integers::Bool=true)
    gdx = GDXHandle()
    gdx_create(gdx)

    try
        gdx_open_read(gdx, filepath)
        symbols = Dict{Symbol, GDXSymbol}()

        n_syms, n_uels = gdx_system_info(gdx)

        for sym_nr in 1:n_syms
            sym_name, sym_dim, sym_type = gdx_symbol_info(gdx, sym_nr)
            sym_count, sym_user_info, sym_description = gdx_symbol_info_x(gdx, sym_nr)

            sym_key = Symbol(sym_name)

            if sym_type == GMS_DT_SET
                symbols[sym_key] = _read_set(gdx, sym_nr, sym_name, sym_dim, sym_description)
            elseif sym_type == GMS_DT_PAR
                symbols[sym_key] = _read_parameter(gdx, sym_nr, sym_name, sym_dim, sym_description, parse_integers)
            elseif sym_type == GMS_DT_VAR
                symbols[sym_key] = _read_variable(gdx, sym_nr, sym_name, sym_dim, sym_description, sym_user_info, parse_integers)
            elseif sym_type == GMS_DT_EQU
                symbols[sym_key] = _read_equation(gdx, sym_nr, sym_name, sym_dim, sym_description, sym_user_info, parse_integers)
            end
            # Skip aliases (GMS_DT_ALIAS)
        end

        gdx_close(gdx)
        return GDXFile(filepath, symbols)
    finally
        gdx_free(gdx)
    end
end

function _read_set(gdx::GDXHandle, sym_nr::Int, name::String, dim::Int, description::String)
    domains = dim > 0 ? gdx_symbol_get_domain_x(gdx, sym_nr, dim) : String[]

    n_recs = gdx_data_read_str_start(gdx, sym_nr)

    keys = Vector{String}(undef, max(dim, 1))
    vals = Vector{Float64}(undef, GMS_VAL_MAX)
    columns = [Vector{String}(undef, n_recs) for _ in 1:dim]

    for i in 1:n_recs
        gdx_data_read_str(gdx, keys, vals)
        for d in 1:dim
            columns[d][i] = keys[d]
        end
    end
    gdx_data_read_done(gdx)

    df = DataFrame()
    for (d, domain) in enumerate(domains)
        col_name = domain == "*" ? "dim$d" : domain
        df[!, col_name] = columns[d]
    end

    return GDXSet(name, description, domains, df)
end

function _read_parameter(gdx::GDXHandle, sym_nr::Int, name::String, dim::Int, description::String, parse_integers::Bool)
    domains = dim > 0 ? gdx_symbol_get_domain_x(gdx, sym_nr, dim) : String[]

    n_recs = gdx_data_read_str_start(gdx, sym_nr)

    keys = Vector{String}(undef, max(dim, 1))
    vals = Vector{Float64}(undef, GMS_VAL_MAX)
    columns = [Vector{String}(undef, n_recs) for _ in 1:dim]
    values = Vector{Float64}(undef, n_recs)

    for i in 1:n_recs
        gdx_data_read_str(gdx, keys, vals)
        for d in 1:dim
            columns[d][i] = keys[d]
        end
        values[i] = parse_gdx_value(vals[GAMS_VALUE_LEVEL])
    end
    gdx_data_read_done(gdx)

    df = DataFrame()
    for (d, domain) in enumerate(domains)
        col_name = domain == "*" ? "dim$d" : domain
        col_data = columns[d]
        if parse_integers
            col_data = _try_parse_integers(col_data)
        end
        df[!, col_name] = col_data
    end
    df[!, :value] = values

    metadata!(df, "name", name, style=:default)
    metadata!(df, "description", description, style=:default)

    return GDXParameter(name, description, domains, df)
end

function _read_variable(gdx::GDXHandle, sym_nr::Int, name::String, dim::Int, description::String, user_info::Int, parse_integers::Bool)
    domains = dim > 0 ? gdx_symbol_get_domain_x(gdx, sym_nr, dim) : String[]

    n_recs = gdx_data_read_str_start(gdx, sym_nr)

    keys = Vector{String}(undef, max(dim, 1))
    vals = Vector{Float64}(undef, GMS_VAL_MAX)
    columns = [Vector{String}(undef, n_recs) for _ in 1:dim]
    level = Vector{Float64}(undef, n_recs)
    marginal = Vector{Float64}(undef, n_recs)
    lower = Vector{Float64}(undef, n_recs)
    upper = Vector{Float64}(undef, n_recs)
    scale = Vector{Float64}(undef, n_recs)

    for i in 1:n_recs
        gdx_data_read_str(gdx, keys, vals)
        for d in 1:dim
            columns[d][i] = keys[d]
        end
        level[i] = parse_gdx_value(vals[GAMS_VALUE_LEVEL])
        marginal[i] = parse_gdx_value(vals[GAMS_VALUE_MARGINAL])
        lower[i] = parse_gdx_value(vals[GAMS_VALUE_LOWER])
        upper[i] = parse_gdx_value(vals[GAMS_VALUE_UPPER])
        scale[i] = parse_gdx_value(vals[GAMS_VALUE_SCALE])
    end
    gdx_data_read_done(gdx)

    df = DataFrame()
    for (d, domain) in enumerate(domains)
        col_name = domain == "*" ? "dim$d" : domain
        col_data = columns[d]
        if parse_integers
            col_data = _try_parse_integers(col_data)
        end
        df[!, col_name] = col_data
    end
    df[!, :level] = level
    df[!, :marginal] = marginal
    df[!, :lower] = lower
    df[!, :upper] = upper
    df[!, :scale] = scale

    metadata!(df, "name", name, style=:default)
    metadata!(df, "description", description, style=:default)

    return GDXVariable(name, description, domains, user_info, df)
end

function _read_equation(gdx::GDXHandle, sym_nr::Int, name::String, dim::Int, description::String, user_info::Int, parse_integers::Bool)
    domains = dim > 0 ? gdx_symbol_get_domain_x(gdx, sym_nr, dim) : String[]

    n_recs = gdx_data_read_str_start(gdx, sym_nr)

    keys = Vector{String}(undef, max(dim, 1))
    vals = Vector{Float64}(undef, GMS_VAL_MAX)
    columns = [Vector{String}(undef, n_recs) for _ in 1:dim]
    level = Vector{Float64}(undef, n_recs)
    marginal = Vector{Float64}(undef, n_recs)
    lower = Vector{Float64}(undef, n_recs)
    upper = Vector{Float64}(undef, n_recs)
    scale = Vector{Float64}(undef, n_recs)

    for i in 1:n_recs
        gdx_data_read_str(gdx, keys, vals)
        for d in 1:dim
            columns[d][i] = keys[d]
        end
        level[i] = parse_gdx_value(vals[GAMS_VALUE_LEVEL])
        marginal[i] = parse_gdx_value(vals[GAMS_VALUE_MARGINAL])
        lower[i] = parse_gdx_value(vals[GAMS_VALUE_LOWER])
        upper[i] = parse_gdx_value(vals[GAMS_VALUE_UPPER])
        scale[i] = parse_gdx_value(vals[GAMS_VALUE_SCALE])
    end
    gdx_data_read_done(gdx)

    df = DataFrame()
    for (d, domain) in enumerate(domains)
        col_name = domain == "*" ? "dim$d" : domain
        col_data = columns[d]
        if parse_integers
            col_data = _try_parse_integers(col_data)
        end
        df[!, col_name] = col_data
    end
    df[!, :level] = level
    df[!, :marginal] = marginal
    df[!, :lower] = lower
    df[!, :upper] = upper
    df[!, :scale] = scale

    metadata!(df, "name", name, style=:default)
    metadata!(df, "description", description, style=:default)

    return GDXEquation(name, description, domains, user_info, df)
end

# =============================================================================
# Writing GDX files
# =============================================================================

"""
    write_gdx(filepath::String, symbols::Pair{String, DataFrame}...; producer="GAMS.jl")

Write DataFrames to a GDX file as parameters.

# Example
```julia
df = DataFrame(i=["a", "b", "c"], value=[1.0, 2.0, 3.0])
write_gdx("output.gdx", "demand" => df)
```
"""
function write_gdx(filepath::String, symbols::Pair{String, DataFrame}...; producer::String="GAMS.jl")
    gdx = GDXHandle()
    gdx_create(gdx)

    try
        gdx_open_write(gdx, filepath, producer)

        for (name, df) in symbols
            _write_parameter(gdx, name, df)
        end

        gdx_close(gdx)
    finally
        gdx_free(gdx)
    end
    return filepath
end

function _write_parameter(gdx::GDXHandle, name::String, df::DataFrame)
    description = get(metadata(df), "description", "")

    dim_cols = [n for n in names(df) if n != "value"]
    dim = length(dim_cols)

    gdx_data_write_str_start(gdx, name, description, dim, GMS_DT_PAR)

    keys = Vector{String}(undef, dim)
    vals = zeros(Float64, GMS_VAL_MAX)

    for row in eachrow(df)
        for (i, col) in enumerate(dim_cols)
            keys[i] = string(row[col])
        end
        vals[GAMS_VALUE_LEVEL] = _to_gdx_value(row[:value])
        gdx_data_write_str(gdx, keys, vals)
    end

    gdx_data_write_done(gdx)
    return
end

# =============================================================================
# Utilities
# =============================================================================

function _try_parse_integers(strings::Vector{String})
    all_ints = all(s -> !isnothing(tryparse(Int, s)), strings)
    all_ints && return parse.(Int, strings)
    return strings
end

function _to_gdx_value(val::Float64)
    isnan(val) && return GAMS_SV_NA
    val == Inf && return GAMS_SV_PINF
    val == -Inf && return GAMS_SV_MINF
    return val
end

_to_gdx_value(val::Real) = _to_gdx_value(Float64(val))
