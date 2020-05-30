######################################################################
# GetSetProp
# ----------
# Provides macros to generate getters and setters for virtual properties.

module GetSetProp

export @generate_properties, @get, @set

const Optional{T} = Union{T, Nothing}
const GetterSetterBody = Tuple{Optional{LineNumberNode}, Expr}

struct StructProp{S, F} end
struct StructField{S, F} end

assign(inst, field::Symbol, value) = assign(getfieldtype(typeof(inst), field), inst, field, value)
assign(T::Type{StructProp{ S, F}}, inst::S, value) where {S, F} = assign(StructField{S, F}, inst, value)
assign(T::Type{StructField{S, F}}, inst::S, value) where {S, F} = assign(getfieldtype(T), inst, F, value)
assign(T::Type, inst, field::Symbol, value)                                       = setfield!(inst, field, convert(T, value))
assign(::Type{T1}, inst, field::Symbol, value::T2) where {T1, T2<:T1}             = setfield!(inst, field, value)
assign(::Type{T1}, inst, field::Symbol, value::T2) where {T1<:Number, T2<:Number} = setfield!(inst, field, T1(value))

retrieve(inst, field::Symbol) = retrieve(StructField{typeof(inst), field}, inst)
retrieve(::Type{StructProp{ S, F}}, inst::S) where {S, F} = retrieve(StructField{S, F}, inst)
retrieve(::Type{StructField{S, F}}, inst::S) where {S, F} = getfield(inst, F)

getfieldtype(S::Type, F::Symbol) = getfieldtype(StructField{S, F})
@generated function getfieldtype(::Type{StructField{S, F}}) where {S, F}
    T = S.types[findfirst(field->field==F, fieldnames(S))]
    :($T)
end

macro generate_properties(T, block)
    if !isa(block, Expr) || block.head != :block
        throw(ArgumentError("Second argument to @generate_properties must be a block"))
    end
    
    result = Expr(:block)
    props  = Set{Symbol}()
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
            body = replace_self(T, body)
            push!(props, prop)
            
            if expr.args[1] == symget
                push!(result.args, generate_getter(T, prop, lastlinenumber, body))
            elseif expr.args[1] == symset
                push!(result.args, generate_setter(T, prop, lastlinenumber, body))
            end
            
            lastlinenumber = nothing
        end
    end
    
    # Generate propertynames
    push!(result.args, quote
        @generated function Base.propertynames(::$T)
            res = tuple(union($props, fieldnames($T))...)
            :($res)
        end
    end)
    
    push!(result.args, :(Base.getproperty(self::$T, prop::Symbol) = GetSetProp.retrieve(GetSetProp.StructProp{$T, prop}, self)))
    push!(result.args, :(Base.setproperty!(self::$T, prop::Symbol, value) = GetSetProp.assign(GetSetProp.StructProp{$T, prop}, self, value)))
    
    esc(result)
end

macro get(args...) end
macro set(args...) end

filterlinenumbers(exprs) = filter(expr->!isa(expr, LineNumberNode), exprs)

replace_self(T::Symbol, expr) = expr
function replace_self(T::Symbol, expr::Expr)
    if expr.head == :(=)
        lhs, rhs = expr.args
        
        if isa(lhs, Expr) && lhs.head == :. && lhs.args[1] == :self
            prop = lhs.args[2]::QuoteNode
            expr = :(GetSetProp.assign(self, $rhs))
            insert!(expr.args, 2, structfieldexpr(T, prop))
        end
    elseif expr.head == :.
        if expr.args[1] == :self
            prop = expr.args[2]::QuoteNode
            expr = :(GetSetProp.retrieve(self))
            insert!(expr.args, 2, structfieldexpr(T, prop))
        end
    end
    expr.args = map(sub->replace_self(T, sub), expr.args)
    expr
end

function generate_getter(T::Symbol, prop::Symbol, linenumber::Optional{LineNumberNode}, body)
    block = Expr(:block)
    if linenumber !== nothing push!(block.args, linenumber) end
    push!(block.args, body)
    
    fnexpr = :(GetSetProp.retrieve(self::$T) = $block)
    insert!(fnexpr.args[1].args, 2, argtypeexpr(structpropexpr(T, prop)))
    fnexpr
end

function generate_setter(T::Symbol, prop::Symbol, linenumber::Optional{LineNumberNode}, body)
    block = Expr(:block)
    if linenumber !== nothing push!(block.args, linenumber) end
    push!(block.args, body)
    
    fnexpr = :(GetSetProp.assign(self::$T, value) = $block)
    insert!(fnexpr.args[1].args, 2, argtypeexpr(structpropexpr(T, prop)))
    fnexpr
end

structfieldexpr(T::Symbol, prop::QuoteNode) = Expr(:curly, :(GetSetProp.StructField), T, prop)
structfieldexpr(T::Symbol, prop::Symbol)    = structfieldexpr(T, QuoteNode(prop))
structpropexpr( T::Symbol, prop::QuoteNode) = Expr(:curly, :(GetSetProp.StructProp),  T, prop)
structpropexpr( T::Symbol, prop::Symbol)    = structpropexpr(T, QuoteNode(prop))

function argtypeexpr(type::Expr)
    Expr(:(::), Expr(:curly, :Type, type))
end

end # module
