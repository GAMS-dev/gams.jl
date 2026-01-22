# Tests for GDXFile API
# These tests require a GAMS installation with the GDX library available

using GAMS
using Test
using DataFrames
using Libdl

# Create a test GDX file using GAMS command line
function create_test_gdx(filepath::String)
    gams_path = Sys.which("gams")
    isnothing(gams_path) && return false
    
    gms_content = """
Set i /a, b, c/;
Parameter p(i) / a 1.5, b 2.5, c 3.5 /;
Free Variable x(i);
Positive Variable y(i);
x.l(i) = ord(i) * 10;
x.m(i) = ord(i) * 0.1;
y.l(i) = ord(i) * 5;
y.up(i) = 100;
Equation dummy; dummy.. sum(i, x(i)) =e= 0;
execute_unload '$filepath', i, p, x, y;
"""
    
    tmpdir = mktempdir()
    gms_file = joinpath(tmpdir, "create_test.gms")
    open(gms_file, "w") do io
        write(io, gms_content)
    end
    
    try
        run(`$gams_path $gms_file lo=0 curDir=$tmpdir`)
        return isfile(filepath)
    catch e
        @warn "Failed to create test GDX: $e"
        return false
    end
end

@testset "GDXFile API" begin
    # Add GAMS directory to library load path
    gams_path = Sys.which("gams")
    gams_dir = dirname(gams_path)
    push!(Libdl.DL_LOAD_PATH, gams_dir)
    
    # Create test file using GAMS
    test_gdx = joinpath(tempdir(), "gams_jl_test.gdx")
    create_test_gdx(test_gdx)
    
    @testset "Reading GDX file created by GAMS" begin
        gdx = read_gdx(test_gdx)
        
        @test :i in list_sets(gdx)
        @test :p in list_parameters(gdx)
        
        # Check parameter values
        p = gdx[:p]
        @test "value" in names(p)
        @test p.value == [1.5, 2.5, 3.5]
    end
    
    @testset "Reading variables" begin
        gdx = read_gdx(test_gdx)
        
        @test :x in list_variables(gdx)
        @test :y in list_variables(gdx)
        
        # Check variable x (free variable)
        x = gdx[:x]
        @test "level" in names(x)
        @test "marginal" in names(x)
        @test "lower" in names(x)
        @test "upper" in names(x)
        @test x.level == [10.0, 20.0, 30.0]
        @test x.marginal ≈ [0.1, 0.2, 0.3]
        
        # Check variable y (positive variable with upper bound)
        y = gdx[:y]
        @test y.level == [5.0, 10.0, 15.0]
        @test all(y.lower .== 0.0)  # positive variable has lower bound 0
        @test all(y.upper .== 100.0)
        
        rm(test_gdx, force=true)
    end
    
    @testset "Write and read round-trip" begin
        # Create test data
        supply = DataFrame(
            i = ["seattle", "san-diego"],
            value = [350.0, 600.0]
        )
        
        demand = DataFrame(
            j = ["new-york", "chicago", "topeka"],
            value = [325.0, 300.0, 275.0]
        )
        
        # Write to GDX
        outfile = joinpath(tempdir(), "gams_jl_write_test.gdx")
        write_gdx(outfile, "supply" => supply, "demand" => demand)
        
        # Read back
        gdx = read_gdx(outfile)
        
        @test :supply in list_parameters(gdx)
        @test :demand in list_parameters(gdx)
        @test gdx[:supply].value == [350.0, 600.0]
        @test gdx[:demand].value == [325.0, 300.0, 275.0]
        
        # Test property access
        @test gdx.supply == gdx[:supply]
        @test gdx.demand == gdx[:demand]
        
        rm(outfile, force=true)
    end
    
    @testset "Multi-dimensional parameters" begin
        cost = DataFrame(
            i = ["seattle", "seattle", "san-diego", "san-diego"],
            j = ["new-york", "chicago", "new-york", "chicago"],
            value = [2.5, 1.7, 2.5, 1.8]
        )
        
        outfile = joinpath(tempdir(), "gams_jl_2d_test.gdx")
        write_gdx(outfile, "cost" => cost)
        
        gdx = read_gdx(outfile)
        result = gdx[:cost]
        
        @test size(result, 1) == 4
        # Domain names aren't preserved when writing without explicit domains
        # so they come back as dim1, dim2, etc.
        @test length(names(result)) == 3  # 2 dimensions + value
        @test "value" in names(result)
        
        rm(outfile, force=true)
    end
    
    @testset "Integer parsing" begin
        df = DataFrame(year = ["2020", "2021", "2022"], value = [1.0, 2.0, 3.0])
        
        outfile = joinpath(tempdir(), "gams_jl_int_test.gdx")
        write_gdx(outfile, "data" => df)
        
        gdx = read_gdx(outfile, parse_integers=true)
        # Domain names become dim1 when round-tripped through GDX
        @test eltype(gdx[:data].dim1) == Int
        
        gdx = read_gdx(outfile, parse_integers=false)
        @test eltype(gdx[:data].dim1) == String
        
        rm(outfile, force=true)
    end
    
    @testset "GDXFile show and propertynames" begin
        df = DataFrame(i = ["a", "b"], value = [1.0, 2.0])
        outfile = joinpath(tempdir(), "gams_jl_show_test.gdx")
        write_gdx(outfile, "param" => df)
        
        gdx = read_gdx(outfile)
        
        # Test show
        io = IOBuffer()
        show(io, gdx)
        output = String(take!(io))
        @test occursin("GDXFile:", output)
        @test occursin("param", output)
        
        # Test propertynames
        props = propertynames(gdx)
        @test :path in props
        @test :symbols in props
        @test :param in props
        
        rm(outfile, force=true)
    end
    
    @testset "Symbol listing" begin
        df1 = DataFrame(i = ["a"], value = [1.0])
        df2 = DataFrame(j = ["x"], value = [2.0])
        
        outfile = joinpath(tempdir(), "gams_jl_list_test.gdx")
        write_gdx(outfile, "param1" => df1, "param2" => df2)
        
        gdx = read_gdx(outfile)
        
        params = list_parameters(gdx)
        @test :param1 in params
        @test :param2 in params
        @test length(params) == 2
        
        syms = list_symbols(gdx)
        @test length(syms) == 2
        
        rm(outfile, force=true)
    end
end
