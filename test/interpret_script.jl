# Test functions for parsing
function fixable1(x)
    return x
end
fixable2(x) = x
function fixable3(A)
    s = 0
    fi = firstindex(A)
    for i in eachindex(A)
        for j in fi:i-1
            s += A[j]
        end
    end
    return s
end
function unfixable1(A)
    s = 0
    fi = firstindex(A)
    for i in eachindex(A)
        for j in fi:i-1
            s += A[j]
        end end
    return s
end

# Generated functions
@generated function generated1(A::AbstractArray{T,N}, val) where {T,N}
    ex = Expr(:tuple)
    for i = 1:N
        push!(ex.args, :val)
    end
    return ex
end
call_generated1(ndims) = generated1(fill(0, ntuple(d->1, ndims)...), 7)

# getproperty is defined in sysimg.jl
getline(lnn) = lnn.line

function f63()
    x = 1 + 1
    @info "hello"
    y = 7
end
