module EulerAngles
using LinearAlgebra
export Angles, Matrix

mutable struct Angles{T, VT<:AbstractVector{T}}
    θs::VT
    function Angles(v::VT) where VT
        n_angles = size(v,1)
        n_dims = Int((sqrt(8*n_angles+1) - 1) * 0.5)
        @assert n_dims >= 1 "number of angles should be at least 1"
        return new{eltype(VT), VT}(v)
    end
end

"""
    Angles(n::Int)

Generate a set of random Euler angles representing a n-dimensional orthonormal matrix.
"""
function Angles(n::Int)
    @assert n >= 2  "dimension of orthogonal matrix should be at least 2"
    n_angles::Int = n*(n-1)/2
    angles = (rand(Float64, n_angles) .- 0.5) * π
    layered = flat_to_layered(angles)
    for agl in layered
        agl[end] = (rand(Float64) - 0.5) * 2π
    end
    return Angles(layered_to_flat(layered))
end

function layered_to_flat(θl::Vector{Vector{T}}) where T
    n = length(θl)
    flat = Vector{T}(undef, Int(n*(n+1)//2))
    head = 1
    for (i, len) = zip(1:n, n:-1:1)
        flat[head:head+len-1] = θl[i]
        head += len
    end
    return flat
end

function flat_to_layered(flat::AbstractVector{T}) where T
    L = size(flat, 1)
    n = Int((sqrt(8*L+1) - 1) * 0.5)
    θl::Vector{Vector{T}} = []
    head = 1
    for i =n:-1:1
        push!(θl, flat[head:head+i-1])
        head += i
    end
    return θl
end

function angles_t(t::Matrix{T}) where T
    ν = size(t, 1)
    tν = t[:, end]
    agls = zeros(T, ν)
    # last angle is always π/2
    agls[ν] = π/2
    agls[1] = asin(clamp(tν[1], -1, 1))
    Σcos::T = 1.
    for k = 2:ν-1
        Σcos *= cos(agls[k-1])
        agls[k] = asin(clamp(tν[k] / Σcos, -1, 1))
        if agls[k] ≈ π/2 || cos(agls[k]) ≈ 0.
            return agls
        end
    end
    agls[ν-1] = atan(t[ν-1, ν], t[ν, ν])
    return agls
end

function matrix_a(agls::Vector{T}) where T
    n = size(agls, 1)
    ma = diagm(ones(T, n))
    for i = 1:n-1
        ma[i, i] = cos(agls[i])
        ma[i, n] = tan(agls[i])
        for j = 1:i
            ma[i, n] *= cos(agls[j])
        end
    end

    for i = 1:n
        for k = 1:n-1
            if i > k
                ma[i, k] = -tan(agls[i]) * tan(agls[k])
                for l = k:i
                    ma[i, k] *= cos(agls[l])
                end
            end
        end
    end
    
    ma[n, n] = tan(agls[n])
    for j = 1:n
        ma[n, n] *= cos(agls[j])
    end
    return ma
end
    
"""
    Angles(t::Matrix{T})

Construct Euler Angles from a orthonormal matrix `t`.
"""
function Angles(t::Matrix{T}) where T
    @assert [norm(t[:,i]) for i in 1:size(t, 2)] ≈ ones(size(t, 1))
    n = size(t, 1)
    res::Vector{Vector{T}} = []
    mat_t = deepcopy(t)
    for _ = 2:n
        agls = angles_t(mat_t)
        a = matrix_a(agls) 
        tmp = similar(mat_t)
        mul!(tmp, a', mat_t) 
        mat_t = tmp[1:end-1, 1:end-1]
        # remove the last angle π/2
        push!(res, agls[1:end-1])
    end
    flat = layered_to_flat(res)
    return Angles(flat)
end
    
"""
    Matrix(angles::Angles{T})

Generate the orthonormal matrix represented by a set of Euler Angles.
"""
function Base.Matrix(angles::Angles{T}) where T
    flat = angles.θs
    agls = flat_to_layered(flat)
    n = size(agls, 1) + 1
    b_mat = diagm(ones(T, n))
    for i = 1:n-1
        size_a = size(agls[i], 1) + 1
        tmp_agl = deepcopy(agls[i])
        push!(tmp_agl, π/2)
        padded = Matrix{T}(I, n, n)
        padded[1:size_a,1:size_a] = matrix_a(tmp_agl)
        b_mat = b_mat * padded
    end
    return b_mat
end

end # module EulerAngles

