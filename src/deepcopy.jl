# Because `deepcopy(mod::Module)` throws an error, we need a safe approach.
# Strategy: wrap the IdDict so that our methods get called rather than Base's.
# It's not guaranteed to work for user types that specialize `deepcopy_internal`,
# but hopefully that's rare.

struct WrappedIdDict
    dict::IdDict
end
Base.getindex(w::WrappedIdDict, key) = w.dict[key]
Base.setindex!(w::WrappedIdDict, val, key) = w.dict[key] = val
Base.haskey(w::WrappedIdDict, k) = haskey(w.dict, k)

function safe_deepcopy(a, args...)
    stackdict = WrappedIdDict(IdDict())
    _safe_deepcopy(stackdict, a, args...)
end
safe_deepcopy() = ()
_safe_deepcopy(stackdict, a, args...) =
    (Base.deepcopy_internal(a, stackdict), _safe_deepcopy(stackdict, args...)...)
_safe_deepcopy(stackdict) = ()

# This is the one method we want to override
Base.deepcopy_internal(x::Module, stackdict::WrappedIdDict) = x

# But the rest are necessary to make it work. This is just a direct copy from Base.
Base.deepcopy_internal(x::Union{Symbol,Core.MethodInstance,Method,GlobalRef,DataType,Union,Task},
                  stackdict::WrappedIdDict) = x
Base.deepcopy_internal(x::Tuple, stackdict::WrappedIdDict) =
    ntuple(i->Base.deepcopy_internal(x[i], stackdict), length(x))

function Base.deepcopy_internal(x::Base.SimpleVector, stackdict::WrappedIdDict)
    if haskey(stackdict, x)
        return stackdict[x]
    end
    y = Core.svec(Any[Base.deepcopy_internal(x[i], stackdict) for i = 1:length(x)]...)
    stackdict[x] = y
    return y
end

function Base.deepcopy_internal(x::String, stackdict::WrappedIdDict)
    if haskey(stackdict, x)
        return stackdict[x]
    end
    y = GC.@preserve x unsafe_string(pointer(x), sizeof(x))
    stackdict[x] = y
    return y
end

function Base.deepcopy_internal(@nospecialize(x), stackdict::WrappedIdDict)
    T = typeof(x)::DataType
    nf = nfields(x)
    (isbitstype(T) || nf == 0) && return x
    if haskey(stackdict, x)
        return stackdict[x]
    end
    y = ccall(:jl_new_struct_uninit, Any, (Any,), T)
    if T.mutable
        stackdict[x] = y
    end
    for i in 1:nf
        if isdefined(x,i)
            ccall(:jl_set_nth_field, Cvoid, (Any, Csize_t, Any), y, i-1,
                  Base.deepcopy_internal(getfield(x,i), stackdict))
        end
    end
    return y::T
end

function Base.deepcopy_internal(x::Array, stackdict::WrappedIdDict)
    if haskey(stackdict, x)
        return stackdict[x]
    end
    _deepcopy_array_t(x, eltype(x), stackdict)
end

function _deepcopy_array_t(@nospecialize(x), T, stackdict::WrappedIdDict)
    if isbitstype(T)
        return (stackdict[x]=copy(x))
    end
    dest = similar(x)
    stackdict[x] = dest
    for i = 1:(length(x)::Int)
        if ccall(:jl_array_isassigned, Cint, (Any, Csize_t), x, i-1) != 0
            xi = ccall(:jl_arrayref, Any, (Any, Csize_t), x, i-1)
            if !isbits(xi)
                xi = Base.deepcopy_internal(xi, stackdict)
            end
            ccall(:jl_arrayset, Cvoid, (Any, Any, Csize_t), dest, xi, i-1)
        end
    end
    return dest
end

function Base.deepcopy_internal(x::Union{Dict,IdDict}, stackdict::WrappedIdDict)
    if haskey(stackdict, x)
        return stackdict[x]::typeof(x)
    end

    if isbitstype(eltype(x))
        return (stackdict[x] = copy(x))
    end

    dest = empty(x)
    stackdict[x] = dest
    for (k, v) in x
        dest[Base.deepcopy_internal(k, stackdict)] = Base.deepcopy_internal(v, stackdict)
    end
    dest
end
