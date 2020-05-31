include("./src/GetSetProp.jl")

using StaticArrays
using .GetSetProp

mutable struct Foo{T<:Real}
    size::NTuple{2, T}
    dirty::Bool
end
Foo{T}() where T = Foo{T}((0, 0), false)
Foo() = Foo{Float64}()

@generate_properties Foo begin
    @get width = self.size[1]
    @set width = begin
        self.dirty = true
        self.size = (value, self.size[2])
    end
    
    @get height = self.size[2]
    @set height = begin
        self.dirty = true
        self.size = (self.size[1], value)
    end
end

foo = Foo()

foo.width = 42
foo.height = 69
