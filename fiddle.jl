include("./src/GetSetProp.jl")

using .GetSetProp

updater() = println("Updated! :D")

mutable struct Foo
    size::NTuple{2, Int}
    padding::NTuple{4, Int}
    dirty::Bool
    update
end
Foo() = Foo((0, 0), (0, 0, 0, 0), false, updater)

@generate_properties Foo begin
    @get width = self.size[1]
    @set width = self.size = (value, self.size[2])
    
    @get height = self.size[2]
    @set height = (self.dirty = true; self.size = (self.size[1], value))
    
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

foo = Foo((1, 2), (3, 4, 5, 6), true, updater)
