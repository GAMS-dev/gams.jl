# GDX library bindings for GAMS.jl
# Low-level C API wrappers for reading and writing GDX files

if Sys.iswindows()
    const LIBGDX = "gdxdclib64"
else
    const LIBGDX = "libgdxdclib64"
end

# =============================================================================
# Constants
# =============================================================================

const GMS_MAX_INDEX_DIM = 20
const GMS_SSSIZE = 256
const GMS_VAL_MAX = 5

# =============================================================================
# GDX Handle
# =============================================================================

mutable struct GDXHandle
    cptr::Ref{Ptr{Cvoid}}
    cival::Ref{Cint}
    cival2::Ref{Cint}
    cival3::Ref{Cint}
    civec::Vector{Cint}
    crvec::Vector{Cdouble}
    buf::Vector{Vector{UInt8}}
    cbuf::Vector{Ptr{UInt8}}

    function GDXHandle()
        cptr = Ref{Ptr{Cvoid}}(C_NULL)
        buf = Vector{Vector{UInt8}}(undef, GMS_MAX_INDEX_DIM)
        for i in 1:GMS_MAX_INDEX_DIM
            buf[i] = Vector{UInt8}(undef, GMS_SSSIZE)
            buf[i] .= UInt8(' ')
        end
        cbuf = pointer.(buf)
        crvec = Vector{Cdouble}(undef, GMS_VAL_MAX)
        civec = Vector{Cint}(undef, GMS_MAX_INDEX_DIM)
        return new(cptr, Ref{Cint}(-1), Ref{Cint}(-1), Ref{Cint}(-1), civec, crvec, buf, cbuf)
    end
end

struct GDXException <: Exception
    msg::String
    n_err::Int
end

Base.showerror(io::IO, e::GDXException) = print(io, "GDX failed: $(e.msg) ($(e.n_err))")

# =============================================================================
# Core handle management
# =============================================================================

function gdx_create(gdx_ptr::Ref{Ptr{Cvoid}})
    ccall((:xcreate, LIBGDX), Cvoid, (Ptr{Ptr{Cvoid}},), gdx_ptr)
    if gdx_ptr[] == C_NULL
        throw(GDXException("Can't create GAMS GDX object", 0))
    end
    return
end

gdx_create(gdx::GDXHandle) = gdx_create(gdx.cptr)

function gdx_free(gdx_ptr::Ref{Ptr{Cvoid}})
    ccall((:xfree, LIBGDX), Cvoid, (Ptr{Ptr{Cvoid}},), gdx_ptr)
    return
end

gdx_free(gdx::GDXHandle) = gdx_free(gdx.cptr)

# =============================================================================
# File operations
# =============================================================================

function gdx_open_read(gdx_ptr::Ptr{Cvoid}, file::String, n_err::Ref{Cint})
    return ccall(
        (:cgdxopenread, LIBGDX),
        Cint,
        (Ptr{Cvoid}, Cstring, Ref{Cint}),
        gdx_ptr,
        file,
        n_err,
    )
end

function gdx_open_read(gdx::GDXHandle, file::String)
    rc = gdx_open_read(gdx.cptr[], file, gdx.cival)
    if gdx.cival[] != 0 || rc != 1
        throw(GDXException("Can't open file '$file'", gdx.cival[]))
    end
    return
end

function gdx_open_write(gdx_ptr::Ptr{Cvoid}, file::String, producer::String, n_err::Ref{Cint})
    return ccall(
        (:cgdxopenwrite, LIBGDX),
        Cint,
        (Ptr{Cvoid}, Cstring, Cstring, Ref{Cint}),
        gdx_ptr,
        file,
        producer,
        n_err,
    )
end

function gdx_open_write(gdx::GDXHandle, file::String, producer::String="GAMS.jl")
    rc = gdx_open_write(gdx.cptr[], file, producer, gdx.cival)
    if gdx.cival[] != 0 || rc != 1
        throw(GDXException("Can't open file '$file' for writing", gdx.cival[]))
    end
    return
end

gdx_close(gdx_ptr::Ptr{Cvoid}) = ccall((:gdxclose, LIBGDX), Cint, (Ptr{Cvoid},), gdx_ptr)

function gdx_close(gdx::GDXHandle)
    gdx_close(gdx.cptr[])
    return
end

# =============================================================================
# System and symbol information
# =============================================================================

function gdx_system_info(gdx_ptr::Ptr{Cvoid}, sym_count::Ref{Cint}, uel_count::Ref{Cint})
    return ccall(
        (:gdxsysteminfo, LIBGDX),
        Cint,
        (Ptr{Cvoid}, Ref{Cint}, Ref{Cint}),
        gdx_ptr,
        sym_count,
        uel_count,
    )
end

function gdx_system_info(gdx::GDXHandle)
    rc = gdx_system_info(gdx.cptr[], gdx.cival, gdx.cival2)
    if rc != 1
        throw(GDXException("Can't read system info", 0))
    end
    return Int(gdx.cival[]), Int(gdx.cival2[])
end

function gdx_symbol_info(
    gdx_ptr::Ptr{Cvoid},
    sym_id::Int,
    name::Ptr{UInt8},
    dim::Ref{Cint},
    type::Ref{Cint},
)
    return ccall(
        (:cgdxsymbolinfo, LIBGDX),
        Cint,
        (Ptr{Cvoid}, Cint, Ptr{UInt8}, Ref{Cint}, Ref{Cint}),
        gdx_ptr,
        sym_id,
        name,
        dim,
        type,
    )
end

function gdx_symbol_info(gdx::GDXHandle, sym_id::Int)
    gdx.buf[1][1] = UInt8('\0')
    rc = gdx_symbol_info(gdx.cptr[], sym_id, gdx.cbuf[1], gdx.cival, gdx.cival2)
    if rc != 1
        throw(GDXException("Can't read symbol info", 0))
    end
    return unsafe_string(gdx.cbuf[1]), Int(gdx.cival[]), Int(gdx.cival2[])
end

function gdx_symbol_info_x(
    gdx_ptr::Ptr{Cvoid},
    sym_id::Int,
    count::Ref{Cint},
    user_info::Ref{Cint},
    text::Ptr{UInt8},
)
    return ccall(
        (:cgdxsymbolinfox, LIBGDX),
        Cint,
        (Ptr{Cvoid}, Cint, Ref{Cint}, Ref{Cint}, Ptr{UInt8}),
        gdx_ptr,
        sym_id,
        count,
        user_info,
        text,
    )
end

function gdx_symbol_info_x(gdx::GDXHandle, sym_id::Int)
    gdx.buf[1][1] = UInt8('\0')
    rc = gdx_symbol_info_x(gdx.cptr[], sym_id, gdx.cival, gdx.cival2, gdx.cbuf[1])
    if rc != 1
        throw(GDXException("Can't read extended symbol info", 0))
    end
    return Int(gdx.cival[]), Int(gdx.cival2[]), unsafe_string(gdx.cbuf[1])
end

function gdx_find_symbol(gdx_ptr::Ptr{Cvoid}, name::String, sym_nr::Ref{Cint})
    return ccall(
        (:gdxfindsymbol, LIBGDX),
        Cint,
        (Ptr{Cvoid}, Cstring, Ref{Cint}),
        gdx_ptr,
        name,
        sym_nr,
    )
end

function gdx_find_symbol(gdx::GDXHandle, name::String)
    rc = gdx_find_symbol(gdx.cptr[], name, gdx.cival)
    return rc == 1, Int(gdx.cival[])
end

function gdx_symbol_get_domain_x(gdx_ptr::Ptr{Cvoid}, sym_nr::Int, domains::Vector{Ptr{UInt8}})
    return ccall(
        (:cgdxsymbolgetdomainx, LIBGDX),
        Cint,
        (Ptr{Cvoid}, Cint, Ptr{Ptr{UInt8}}),
        gdx_ptr,
        sym_nr,
        domains,
    )
end

function gdx_symbol_get_domain_x(gdx::GDXHandle, sym_nr::Int, dim::Int)
    for i in 1:dim
        gdx.buf[i][1] = UInt8('\0')
    end
    rc = gdx_symbol_get_domain_x(gdx.cptr[], sym_nr, gdx.cbuf)
    domains = Vector{String}(undef, dim)
    for i in 1:dim
        domains[i] = unsafe_string(gdx.cbuf[i])
    end
    return domains
end

# =============================================================================
# UEL (Unique Element List) operations
# =============================================================================

function gdx_um_uel_get(gdx_ptr::Ptr{Cvoid}, uel_nr::Int, uel::Ptr{UInt8}, uel_map::Ref{Cint})
    return ccall(
        (:cgdxumuelget, LIBGDX),
        Cint,
        (Ptr{Cvoid}, Cint, Ptr{UInt8}, Ref{Cint}),
        gdx_ptr,
        uel_nr,
        uel,
        uel_map,
    )
end

function gdx_um_uel_get(gdx::GDXHandle, uel_nr::Int)
    gdx.buf[1][1] = UInt8('\0')
    rc = gdx_um_uel_get(gdx.cptr[], uel_nr, gdx.cbuf[1], gdx.cival)
    if rc != 1
        throw(GDXException("Can't get UEL #$uel_nr", 0))
    end
    return unsafe_string(gdx.cbuf[1])
end

function gdx_uel_register_str_start(gdx_ptr::Ptr{Cvoid})
    return ccall((:gdxuelregisterstrstart, LIBGDX), Cint, (Ptr{Cvoid},), gdx_ptr)
end

function gdx_uel_register_str_start(gdx::GDXHandle)
    rc = gdx_uel_register_str_start(gdx.cptr[])
    if rc != 1
        throw(GDXException("Can't start UEL string registration", 0))
    end
    return
end

function gdx_uel_register_str(gdx_ptr::Ptr{Cvoid}, uel::String, uel_nr::Ref{Cint})
    return ccall(
        (:gdxuelregisterstr, LIBGDX),
        Cint,
        (Ptr{Cvoid}, Cstring, Ref{Cint}),
        gdx_ptr,
        uel,
        uel_nr,
    )
end

function gdx_uel_register_str(gdx::GDXHandle, uel::String)
    rc = gdx_uel_register_str(gdx.cptr[], uel, gdx.cival)
    return Int(gdx.cival[])
end

function gdx_uel_register_done(gdx_ptr::Ptr{Cvoid})
    return ccall((:gdxuelregisterdone, LIBGDX), Cint, (Ptr{Cvoid},), gdx_ptr)
end

function gdx_uel_register_done(gdx::GDXHandle)
    rc = gdx_uel_register_done(gdx.cptr[])
    if rc != 1
        throw(GDXException("Can't finish UEL registration", 0))
    end
    return
end

# =============================================================================
# Reading data (raw integer interface)
# =============================================================================

function gdx_data_read_raw_start(gdx_ptr::Ptr{Cvoid}, start::Int, n_rec::Ref{Cint})
    return ccall(
        (:gdxdatareadrawstart, LIBGDX),
        Cint,
        (Ptr{Cvoid}, Cint, Ref{Cint}),
        gdx_ptr,
        start,
        n_rec,
    )
end

function gdx_data_read_raw_start(gdx::GDXHandle, start::Int)
    rc = gdx_data_read_raw_start(gdx.cptr[], start, gdx.cival)
    if rc != 1
        throw(GDXException("Can't start GDX read", 0))
    end
    return Int(gdx.cival[])
end

function gdx_data_read_raw(
    gdx_ptr::Ptr{Cvoid},
    idx::Vector{Cint},
    vals::Vector{Cdouble},
    dim::Ref{Cint},
)
    return ccall(
        (:gdxdatareadraw, LIBGDX),
        Cint,
        (Ptr{Cvoid}, Ptr{Cint}, Ptr{Cdouble}, Ref{Cint}),
        gdx_ptr,
        idx,
        vals,
        dim,
    )
end

function gdx_data_read_raw(gdx::GDXHandle, idx::Vector{Int}, vals::Vector{Float64})
    @assert(length(idx) <= length(gdx.civec))
    @assert(length(vals) <= length(gdx.crvec))

    rc = gdx_data_read_raw(gdx.cptr[], gdx.civec, gdx.crvec, gdx.cival)
    if rc != 1
        throw(GDXException("Reading raw data failed", 0))
    end

    for i in 1:length(idx)
        idx[i] = gdx.civec[i]
    end
    for i in 1:length(vals)
        vals[i] = gdx.crvec[i]
    end
    return
end

# =============================================================================
# Reading data (string interface)
# =============================================================================

function gdx_data_read_str_start(gdx_ptr::Ptr{Cvoid}, start::Int, n_err::Ref{Cint})
    return ccall(
        (:gdxdatareadstrstart, LIBGDX),
        Cint,
        (Ptr{Cvoid}, Cint, Ref{Cint}),
        gdx_ptr,
        start,
        n_err,
    )
end

function gdx_data_read_str_start(gdx::GDXHandle, start::Int)
    rc = gdx_data_read_str_start(gdx.cptr[], start, gdx.cival)
    if rc != 1
        throw(GDXException("Can't start GDX read", 0))
    end
    return Int(gdx.cival[])
end

function gdx_data_read_str(
    gdx_ptr::Ptr{Cvoid},
    keystr::Vector{Ptr{UInt8}},
    vals::Vector{Cdouble},
    dim_first::Ref{Cint},
)
    return ccall(
        (:cgdxdatareadstr, LIBGDX),
        Cint,
        (Ptr{Cvoid}, Ptr{Ptr{UInt8}}, Ptr{Cdouble}, Ref{Cint}),
        gdx_ptr,
        keystr,
        vals,
        dim_first,
    )
end

function gdx_data_read_str(gdx::GDXHandle, keystr::Vector{String}, vals::Vector{Float64})
    @assert(length(keystr) <= length(gdx.cbuf))
    @assert(length(vals) <= length(gdx.crvec))

    for b in gdx.buf
        b[1] = UInt8('\0')
    end

    rc = gdx_data_read_str(gdx.cptr[], gdx.cbuf, gdx.crvec, gdx.cival)
    if rc != 1
        throw(GDXException("Failed to read GDX record", 0))
    end

    for i in 1:length(keystr)
        keystr[i] = unsafe_string(gdx.cbuf[i])
    end
    for i in 1:length(vals)
        vals[i] = gdx.crvec[i]
    end
    return
end

function gdx_data_read_done(gdx_ptr::Ptr{Cvoid})
    return ccall((:gdxdatareaddone, LIBGDX), Cint, (Ptr{Cvoid},), gdx_ptr)
end

function gdx_data_read_done(gdx::GDXHandle)
    gdx_data_read_done(gdx.cptr[])
    return
end

# =============================================================================
# Writing data
# =============================================================================

function gdx_data_write_str_start(
    gdx_ptr::Ptr{Cvoid},
    name::String,
    text::String,
    dim::Int,
    typ::Int,
    user_info::Int,
)
    return ccall(
        (:cgdxdatawritestrstart, LIBGDX),
        Cint,
        (Ptr{Cvoid}, Cstring, Cstring, Cint, Cint, Cint),
        gdx_ptr,
        name,
        text,
        dim,
        typ,
        user_info,
    )
end

function gdx_data_write_str_start(gdx::GDXHandle, name::String, text::String, dim::Int, typ::Int, user_info::Int=0)
    rc = gdx_data_write_str_start(gdx.cptr[], name, text, dim, typ, user_info)
    if rc != 1
        throw(GDXException("Can't start writing symbol '$name'", 0))
    end
    return
end

function gdx_data_write_str(gdx_ptr::Ptr{Cvoid}, keys::Vector{String}, vals::Vector{Float64})
    return ccall(
        (:cgdxdatawritestr, LIBGDX),
        Cint,
        (Ptr{Cvoid}, Ptr{Cstring}, Ptr{Cdouble}),
        gdx_ptr,
        keys,
        vals,
    )
end

function gdx_data_write_str(gdx::GDXHandle, keys::Vector{String}, vals::Vector{Float64})
    rc = gdx_data_write_str(gdx.cptr[], keys, vals)
    if rc != 1
        throw(GDXException("Can't write record", 0))
    end
    return
end

function gdx_data_write_done(gdx_ptr::Ptr{Cvoid})
    return ccall((:gdxdatawritedone, LIBGDX), Cint, (Ptr{Cvoid},), gdx_ptr)
end

function gdx_data_write_done(gdx::GDXHandle)
    rc = gdx_data_write_done(gdx.cptr[])
    if rc != 1
        throw(GDXException("Can't finish writing symbol", 0))
    end
    return
end
