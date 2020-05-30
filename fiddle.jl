include("./src/GetSetProp.jl")

using StaticArrays
using .GetSetProp

abstract type SuperType end

struct Subtype1 <: SuperType end
struct Subtype2 <: SuperType end

mutable struct Foo
    size::Vector{Float64}
    bar::SuperType
end
Foo() = Foo([0, 0], Subtype1())

@generate_properties Foo begin
    @get width = self.size[1]
    @set width = self.size = SVector(value, self.size[2])
    
    @get height = self.size[2]
    @set height = self.size = SVector(self.size[1], value)
end

foo = Foo()
(function()
    @time Foo.types[findfirst(field->field==:bar, fieldnames(Foo))]
    @time Foo.types[findfirst(field->field==:bar, fieldnames(Foo))]
    @time GetSetProp.getfieldtype(Foo, :bar)
    @time GetSetProp.getfieldtype(Foo, :bar)
end)()
