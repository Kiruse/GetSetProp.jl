include("./src/GetSetProp.jl")

using StaticArrays
using .GetSetProp

updater() = println("Updated! :D")

mutable struct Foo
    size::SVector{2, Float64}
end
Foo() = Foo(SVector(0, 0))

@generate_properties Foo begin
    @get width = self.size[1]
    @set width = self.size = SVector(value, self.size[2])
    
    @get height = self.size[2]
    @set height = self.size = SVector(self.size[1], value)
end

foo = Foo()
(function()
    @time foo.size = SVector(2, 4)
    @time foo.size = SVector(2, 4)
end)()
