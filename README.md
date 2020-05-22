# GetSetProp.jl
A microlibrary providing a single macro and two submacros to automatically generate `Base.getproperty`,
`Base.setproperty!` and `Base.propertynames`.

# Syntax
```julia
@generate_properties <typename> begin
    @get <propertyname> = <propertygetter>
    @set <propertyname> = <propertysetter>
end
```

In its current state the macro is severely limited. The typename must be named first, followed by a code block.
This code block contains a single `@get` or `@set` macro per line, excluding blank lines. Other expressions are not
permitted.

Getters and setters always start with the property name, followed by an assignment and the getter's or setter's body.
The body implicitly is converted into a function of the signature:

```julia
function getter(self, prop) end
function setter(self, prop, value) end
```

When several commands are required, either a semi-colon separated list of expressions or another code block can be used.
In either case, the assignment must be maintained. This restriction may be lifted in the future.

# Examples

```julia
mutable struct Foo
    size::NTuple{2, Int}
    padding::NTuple{4, Int}
    dirty::Bool
end

@generate_properties Foo begin
    @get width = self.size[1]
    @set width = self.size[1] = (value, self.size[2])
    
    @get height = self.size[2]
    @set height = (self.dirty = true; self.size[2] = (self.size[1], value))
    
    @get padding = self.padding
    @set padding = begin
        if value === nothing
            throw(ArgumentError("Padding cannot be nothing"))
        end
        self.padding = normalize_padding(padding)
    end
end

normalize_padding(padding) = identity(padding)
```
