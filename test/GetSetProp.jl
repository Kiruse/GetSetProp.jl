include("../src/GetSetProp.jl")

using Test
using .GetSetProp

mutable struct Foo1DSimple
    size::NTuple{2, Float32}
end
Foo1DSimple() = Foo1DSimple((0, 0))
@generate_properties Foo1DSimple begin
    @get width = self.size[1]
    @set width = self.size = (value, self.size[2])
    @get height = self.size[2]
    @set height = self.size = (self.size[1], value)
end

mutable struct Foo1DComplex
    size::NTuple{2, Float32}
    dirty::Bool
    callback
end
Foo1DComplex() = Foo1DComplex((0, 0), false, nothing)
@generate_properties Foo1DComplex begin
    @get width = self.size[1]
    @set width = begin
        self.dirty = true
        self.size = (value, self.size[2])
        if self.callback !== nothing self.callback() end
        value
    end
    
    @get height = self.size[2]
    @set height = begin
        self.dirty = true
        self.size = (self.size[1], value)
        if self.callback !== nothing self.callback() end
        value
    end
end

mutable struct SizeSimple
    width::Float64
    height::Float64
end
mutable struct SizeParam{T<:Real}
    width::T
    height::T
end
SizeParam(width, height) = SizeParam{promote_type(typeof(width), typeof(height))}(width, height)
Base.convert(::Type{SizeParam{T}}, size::SizeParam) where T = SizeParam{T}(size.width, size.height)

mutable struct Foo2DSimple
    size::SizeSimple
end
Foo2DSimple() = Foo2DSimple(SizeSimple(0, 0))
@generate_properties Foo2DSimple begin
    @get width = self.size.width
    @set width = self.size.width = value
    @get height = self.size.height
    @set height = self.size.height = value
    @get size = (self.size.width, self.size.height)
    @set size = self.size = SizeSimple(value[1], value[2])
end

mutable struct Foo2DComplex
    size::SizeSimple
    dirty::Bool
    callback
end
Foo2DComplex() = Foo2DComplex(SizeSimple(0, 0), false, nothing)
@generate_properties Foo2DComplex begin
    @get width = self.size.width
    @set width = begin
        self.size.width = value
        self.dirty = true
        if self.callback !== nothing self.callback() end
        value
    end
    
    @get height = self.size.height
    @set height = begin
        self.size.height = value
        self.dirty = true
        if self.callback !== nothing self.callback() end
        value
    end
    
    @get size = (self.size.width, self.size.height)
    @set size = self.size = SizeSimple(value[1], value[2])
end

mutable struct FooParamSimple{T<:Real}
    size::NTuple{2, T}
end
FooParamSimple{T}() where T = FooParamSimple{T}((0, 0))
FooParamSimple() = FooParamSimple{Float64}()
@generate_properties FooParamSimple begin
    @get width = self.size[1]
    @set width = self.size = (value, self.size[2])
    @get height = self.size[2]
    @set height = self.size = (self.size[1], value)
end

mutable struct FooParamComplex{T<:Real}
    size::SizeParam{T}
    dirty::Bool
    callback
end
FooParamComplex{T}() where T = FooParamComplex{T}(SizeParam{T}(0, 0), false, nothing)
FooParamComplex() = FooParamComplex{Float64}()
@generate_properties FooParamComplex begin
    @get width = self.size.width
    @set width = begin
        self.size.width = value
        self.dirty = true
        if self.callback !== nothing self.callback() end
        value
    end
    
    @get height = self.size.height
    @set height = begin
        self.size.height = value
        self.dirty = true
        if self.callback !== nothing self.callback() end
        value
    end
    
    @get size = (self.size.width, self.size.height)
    @set size = self.size = SizeParam(value[1], value[2])
end


function test_simple(T::Type)
    foo = T()
    @assert foo.width == 0 && foo.height == 0
    
    foo.width = 69
    @assert foo.width == 69
    
    foo.height = 420
    @assert foo.height == 420
    
    foo.size = (1, 2)
    @assert foo.size == (1, 2)
    @assert foo.width == 1
    @assert foo.height == 2
    
    return true
end

function test_complex(T::Type)
    foo = T()
    flag = false
    @assert foo.width == 0 && foo.height == 0 && foo.dirty == false && foo.callback == nothing
    
    foo.width = 69
    @assert foo.width == 69
    @assert foo.dirty == true
    
    foo.dirty = false
    @assert foo.dirty == false
    
    foo.callback = () -> flag = true
    foo.height = 420
    @assert foo.height == 420
    @assert foo.dirty == true
    @assert flag == true
    
    return true
end

@testset "GetSetProp" begin
    @test test_simple( Foo1DSimple)
    @test test_complex(Foo1DComplex)
    @test test_simple( Foo2DSimple)
    @test test_complex(Foo2DComplex)
    @test test_simple( FooParamSimple{Float64})
    @test test_simple( FooParamSimple)
    @test test_complex(FooParamComplex{Float64})
    @test test_complex(FooParamComplex)
end
