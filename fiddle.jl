include("./src/GetSetProp.jl")

using .GetSetProp

updater() = println("Updated! :D")

mutable struct Size
    width::Int
    height::Int
end
Size() = Size(0, 0)

mutable struct Foo
    size::Size
    padding::NTuple{4, Int}
    dirty::Bool
    update
end
Foo() = Foo(Size(0, 0), (0, 0, 0, 0), false, updater)

@generate_properties Foo begin
    @get width = self.size.width
    @set width = self.size.width = value
    
    @get height = self.size.height
    @set height = (self.dirty = true; self.size.height = value)
    
    @get padding = self.padding
    @set padding = self.padding = begin
        if value === nothing || length(value) == 0 throw(ArgumentError("No padding given")) end
        len = length(value)
        if len == 1
            value = (value, value, value, value)
        elseif len == 2
            value = (value[1], value[2], value[1], value[2])
        elseif len == 3
            value = (value[1], value[2], value[3], value[1])
        else
            value = (value[1], value[2], value[3], value[4])
        end
        self.update()
        self.padding = value
    end
end

foo = Foo(Size(1, 2), (3, 4, 5, 6), true, updater)
foo.width = 2
println(foo.size.height)
