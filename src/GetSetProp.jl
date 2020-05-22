module GetSetProp

export @generate_properties, @get, @set

const Optional{T} = Union{T, Nothing}
const GetterSetterBody = Tuple{Optional{LineNumberNode}, Expr}

macro generate_properties(T, block)
    if !isa(block, Expr) || block.head != :block
        throw(ArgumentError("Second argument to @generate_properties must be a block"))
    end
    
    props  = Dict{Symbol, NTuple{2, Optional{GetterSetterBody}}}()
    symget = Symbol("@get")
    symset = Symbol("@set")
    symeq  = Symbol("=")
    
    lastlinenumber = nothing
    for expr ∈ block.args
        if isa(expr, LineNumberNode)
            lastlinenumber = expr
        else
            if expr.head != :macrocall || expr.args[1] ∉ (symget, symset)
                throw(ArgumentError("Every line must be a call to either @get or @set"))
            end
            
            args = filterlinenumbers(expr.args)
            if args[2].head != symeq throw(ArgumentError("Getter/Setter not an assignment")) end
            prop, body = filterlinenumbers(args[2].args)
            body = replace_self(body)
            
            if !haskey(props, prop)
                props[prop] = (nothing, nothing)
            end
            
            if expr.args[1] == symget
                props[prop] = ((lastlinenumber, body), props[prop][2])
            elseif expr.args[1] == symset
                props[prop] = (props[prop][1], (lastlinenumber, body))
            end
            
            lastlinenumber = nothing
        end
    end
    
    block = Expr(:block)
    
    propsymbols = Set(keys(props))
    push!(block.args, :(@generated Base.propertynames(::$T) = tuple(union($propsymbols, fieldnames($T))...)))
    
    # Generate Getters
    fnexpr = :(function Base.getproperty(self::$T, prop::Symbol) end)
    generate_branches(fnexpr, ((prop, getter) for (prop, (getter, _)) ∈ props), :(getfield(self, prop)))
    push!(block.args, fnexpr) # Attach to returned code
    
    # Generate Setters
    fnexpr = :(function Base.setproperty!(self::$T, prop::Symbol, value) end)
    generate_branches(fnexpr, ((prop, setter) for (prop, (_, setter)) ∈ props), :(setfield!(self, prop, value)))
    push!(block.args, fnexpr) # Attach to returned code
    
    esc(block)
end

macro get(args...) end
macro set(args...) end

filterlinenumbers(exprs) = filter(expr->!isa(expr, LineNumberNode), exprs)

replace_self(expr) = expr
function replace_self(expr::Expr)
    if expr.head == :(=)
        lhs, rhs = expr.args
        
        if isa(expr.args[1], Expr) && expr.args[1].head == :.
            prop = lhs.args[2]
            expr = :(setfield!(self, $prop, $rhs))
        end
    elseif expr.head == :.
        if expr.args[1] == :self
            prop = expr.args[2]
            expr = :(getfield(self, $prop))
        end
    end
    expr.args = map(replace_self, expr.args)
    expr
end

function generate_branches(fnexpr::Expr, props, elsebranch)
    firstbranchexpr = nothing
    lastbranchexpr  = nothing
    
    for (prop, fn) ∈ props
        if fn !== nothing
            linenumber, body = fn
            
            comparison = Expr(:call, :(==), :prop, Expr(:call, :Symbol, string(prop)))
            if linenumber === nothing
                subblock = body
            else
                subblock = Expr(:block, linenumber, body)
            end
            branchexpr = Expr(:elseif, comparison, subblock)
            
            if lastbranchexpr === nothing
                firstbranchexpr = branchexpr
                branchexpr.head = :if
            else
                push!(lastbranchexpr.args, branchexpr)
            end
            lastbranchexpr = branchexpr
        end
    end
    
    if firstbranchexpr !== nothing
        push!(fnexpr.args[2].args, firstbranchexpr) # Attach if-elseif-else branches to function body
        push!(lastbranchexpr.args, elsebranch) # Final else branch
    else
        # Fallback if no getters/setters available
        push!(fnexpr.args[2].args, elsebranch)
    end
    fnexpr
end

end # module
