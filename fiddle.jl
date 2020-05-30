include("./src/GetSetProp.jl")

using StaticArrays
using .GetSetProp

mutable struct Size
    width::Float64
    height::Float64
end

mutable struct Foo
    size::Size
    bar::Float32
    dirty::Bool
end
Foo() = Foo(Size(0, 0), 42, false)

@generate_properties Foo begin
    @get width = self.size.width
    @set width = self.size = Size(value, self.size.height)
    
    @get height = self.size.height
    @set height = self.size = Size(self.size.width, value)
    
    @set bar = (self.dirty = true; self.bar = value)
end

foo = Foo()
