
if Sys.iswindows()
   const LIBGDX = "gdxdclib64"
else
   const LIBGDX = "libgdxdclib64"
end

mutable struct GDXHandle
   cptr::Ref{Ptr{Cvoid}}
   cival::Ref{Cint}
   cival2::Ref{Cint}
   civec::Vector{Cint}
   crvec::Vector{Cdouble}
   buf::Vector{Vector{UInt8}}
   cbuf::Vector{Cstring}

   function GDXHandle()
      cptr = Ref{Ptr{Cvoid}}(C_NULL)
      buf = Vector{Vector{UInt8}}(undef, 20)
      for i = 1:20
         buf[i] = Vector{UInt8}(undef, 256)
         buf[i] .= ' '
      end
      cbuf = pointer.(buf)
      crvec = Vector{Cdouble}(undef, 5)
      civec = Vector{Cint}(undef, 5)
      new(cptr, Ref{Cint}(-1), Ref{Cint}(-1), civec, crvec, buf, cbuf)
   end
end

struct GDXException <: Exception
   msg::String
   n_err::Int
end

Base.showerror(io::IO, e::GDXException) = print(io, "GDX failed: $(e.msg) ($(e.n_err))")

function gdx_create(
   gdx_ptr::Ref{Ptr{Cvoid}}
)
   ccall((:xcreate, LIBGDX), Cvoid,
      (Ptr{Ptr{Cvoid}},),
      gdx_ptr
   )
   if gdx_ptr[] == C_NULL
      throw(GDXException("Can't create GAMS GDX object", 0))
   end
   return
end

function gdx_create(
   gdx::GDXHandle
)
   gdx_create(gdx.cptr)
end

function gdx_free(
   gdx_ptr::Ref{Ptr{Cvoid}}
)
   ccall((:xfree, LIBGDX), Cvoid, (Ptr{Ptr{Cvoid}},), gdx_ptr)
   return
end

function gdx_free(
   gdx::GDXHandle
)
   gdx_free(gdx.cptr)
end

function gdx_open_read(
   gdx_ptr::Ptr{Cvoid},
   file::String,
   n_err::Ref{Cint}
)
   return ccall((:cgdxopenread, LIBGDX), Cint,
      (Ptr{Cvoid}, Cstring, Ref{Cint}),
      gdx_ptr, file, n_err
   )
end

function gdx_open_read(
   gdx::GDXHandle,
   file::String
)
   rc = gdx_open_read(gdx.cptr[], file, gdx.cival)
   if gdx.cival[] != 0 || rc != 1
      throw(GDXException("Can't open file '$file'", gdx.cival[]))
   end
   return
end

function gdx_system_info(
   gdx_ptr::Ptr{Cvoid},
   sym_count::Ref{Cint},
   uel_count::Ref{Cint}
)
   return ccall((:gdxsysteminfo, LIBGDX), Cint,
      (Ptr{Cvoid}, Ref{Cint}, Ref{Cint}),
      gdx_ptr, sym_count, uel_count)
end

function gdx_system_info(
   gdx::GDXHandle
)
   rc = gdx_system_info(gdx.cptr[], gdx.cival, gdx.cival2)
   if rc != 1
      throw(GDXException("Can't read system info", 0))
   end
   return Int(gdx.cival[]), Int(gdx.cival2[])
end

function gdx_symbol_info(
   gdx_ptr::Ptr{Cvoid},
   sym_id::Int,
   name::Cstring,
   dim::Ref{Cint},
   type::Ref{Cint}
)
   return ccall((:cgdxsymbolinfo, LIBGDX), Cint,
      (Ptr{Cvoid}, Cint, Cstring, Ref{Cint}, Ref{Cint}),
      gdx_ptr, sym_id, name, dim, type)
end

function gdx_symbol_info(
   gdx::GDXHandle,
   sym_id::Int
)
   gdx.buf[1][1] = '\0'
   rc = gdx_symbol_info(gdx.cptr[], sym_id, gdx.cbuf[1], gdx.cival, gdx.cival2)
   if rc != 1
      throw(GDXException("Can't read symbol info", 0))
   end
   return unsafe_string(gdx.cbuf[1]), Int(gdx.cival[]), Int(gdx.cival2[])
end

function gdx_data_read_raw_start(
   gdx_ptr::Ptr{Cvoid},
   start::Int,
   n_rec::Ref{Cint}
)
   return ccall((:gdxdatareadrawstart, LIBGDX), Cint,
      (Ptr{Cvoid}, Cint, Ref{Cint}),
      gdx_ptr, start, n_rec
   )
end

function gdx_data_read_raw_start(
   gdx::GDXHandle,
   start::Int
)
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
   dim::Ref{Cint}
)
   return ccall((:gdxdatareadraw, LIBGDX), Cint,
      (Ptr{Cvoid}, Ptr{Cint}, Ptr{Cdouble}, Ref{Cint}),
      gdx_ptr, idx, vals, dim
   )
end

function gdx_data_read_raw(
   gdx::GDXHandle,
   idx::Vector{Int},
   vals::Vector{Float64}
)
   @assert(length(idx) <= length(gdx.civec))
   @assert(length(vals) <= length(gdx.crvec))

   rc = gdx_data_read_raw(gdx.cptr[], gdx.civec, gdx.crvec, gdx.cival)
   if rc != 1
      throw(GDXException("Reading raw data failed", 0))
   end

   for i = 1:length(idx)
      idx[i] = gdx.civec[i]
   end
   for i = 1:length(vals)
      vals[i] = gdx.crvec[i]
   end
   return
end

function gdx_data_read_str_start(
   gdx_ptr::Ptr{Cvoid},
   start::Int,
   n_err::Ref{Cint}
)
   return ccall((:gdxdatareadstrstart, LIBGDX), Cint,
      (Ptr{Cvoid}, Cint, Ref{Cint}),
      gdx_ptr, start, n_err
   )
end

function gdx_data_read_str_start(
   gdx::GDXHandle,
   start::Int
)
   rc = gdx_data_read_str_start(gdx.cptr[], start, gdx.cival)
   if rc != 1
      throw(GDXException("Can't start GDX read", 0))
   end
   return gdx.cival[]
end

function gdx_data_read_str(
   gdx_ptr::Ptr{Cvoid},
   keystr::Vector{Cstring},
   vals::Vector{Cdouble},
   dim_first::Ref{Cint}
)
   return ccall((:cgdxdatareadstr, LIBGDX), Cint,
      (Ptr{Cvoid}, Ptr{Cstring}, Ptr{Cdouble}, Ref{Cint}),
      gdx_ptr, keystr, vals, dim_first
   )
end

function gdx_data_read_str(
   gdx::GDXHandle,
   keystr::Vector{String},
   vals::Vector{Float64}
)
   @assert(length(keystr) <= length(gdx.cbuf))
   @assert(length(vals) <= length(gdx.crvec))

   for b in gdx.buf
      b[1] = '\0'
   end

   rc = gdx_data_read_str(gdx.cptr[], gdx.cbuf, gdx.crvec, gdx.cival)
   if rc != 1
      throw(GDXException("Reading raw data failed", 0))
   end

   for i = 1:length(keystr)
      keystr[i] = unsafe_string(gdx.cbuf[i])
   end
   for i = 1:length(vals)
      vals[i] = gdx.crvec[i]
   end
   return
end

function gdx_data_read_done(
   gdx_ptr::Ptr{Cvoid},
)
   return ccall((:gdxdatareaddone, LIBGDX), Cint, (Ptr{Cvoid},), gdx_ptr)
end

function gdx_data_read_done(
   gdx::GDXHandle
)
   gdx_data_read_done(gdx.cptr[])
   return
end

function gdx_close(
   gdx_ptr::Ptr{Cvoid},
)
   return ccall((:gdxclose, LIBGDX), Cint, (Ptr{Cvoid},), gdx_ptr)
end

function gdx_close(
   gdx::GDXHandle
)
   gdx_close(gdx.cptr[])
   return
end
