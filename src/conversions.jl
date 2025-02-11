################## To IMatrix ######################
function IMatrix{T}(A::AbstractMatrix) where {T}
    IMatrix{T}(size(A, 1) == size(A, 2) ? size(A, 2) : throw(DimensionMismatch()))
end
function IMatrix(A::AbstractMatrix{T}) where {T}
    IMatrix{T}(size(A, 1) == size(A, 2) ? size(A, 2) : throw(DimensionMismatch()))
end

################## To Diagonal ######################
Diagonal(A::PermMatrix) = Diagonal(diag(A))
Diagonal(A::IMatrix{T}) where {T} = Diagonal{T}(ones(T, A.n))
Diagonal{T}(A::IMatrix) where {T} = Diagonal{T}(ones(T, A.n))

################## To SparseMatrixCSC ######################
SparseMatrixCSC{Tv,Ti}(A::IMatrix) where {Tv,Ti<:Integer} =
    SparseMatrixCSC{Tv,Ti}(I, A.n, A.n)
SparseMatrixCSC{Tv}(A::IMatrix) where {Tv} = SparseMatrixCSC{Tv,Int}(A)
SparseMatrixCSC(A::IMatrix{T}) where {T} = SparseMatrixCSC{T,Int}(I, A.n, A.n)
function SparseMatrixCSC(M::PermMatrix)
    n = size(M, 1)
    #SparseMatrixCSC(n, n, collect(1:n+1), M.perm, M.vals)
    order = invperm(M.perm)
    SparseMatrixCSC(n, n, collect(1:n+1), order, M.vals[order])
end

@static if VERSION < v"1.3-"

    function SparseMatrixCSC(D::Diagonal{T}) where {T}
        m = length(D.diag)
        return SparseMatrixCSC(m, m, Vector(1:(m+1)), Vector(1:m), Vector{T}(D.diag))
    end

end

SparseMatrixCSC{Tv,Ti}(M::PermMatrix{Tv,Ti}) where {Tv,Ti} = SparseMatrixCSC(M)
SparseMatrixCSC(coo::SparseMatrixCOO) = sparse(coo.is, coo.js, coo.vs, coo.m, coo.n)

################## To Dense ######################
Matrix{T}(A::IMatrix) where {T} = Matrix{T}(I, A.n, A.n)
Matrix(A::IMatrix{T}) where {T} = Matrix{T}(I, A.n, A.n)

function Matrix{T}(X::PermMatrix) where {T}
    n = size(X, 1)
    Mf = zeros(T, n, n)
    @simd for i = 1:n
        @inbounds Mf[i, X.perm[i]] = X.vals[i]
    end
    return Mf
end
Matrix(X::PermMatrix{T}) where {T} = Matrix{T}(X)

function Matrix(coo::SparseMatrixCOO{T}) where {T}
    mat = zeros(T, coo.m, coo.n)
    for (i, j, v) in zip(coo.is, coo.js, coo.vs)
        mat[i, j] += v
    end
    mat
end

################## To PermMatrix ######################
PermMatrix{Tv,Ti}(A::IMatrix) where {Tv,Ti} =
    PermMatrix{Tv,Ti}(Vector{Ti}(1:A.n), ones(Tv, A.n))
PermMatrix{Tv}(X::IMatrix) where {Tv} = PermMatrix{Tv,Int}(X)
PermMatrix(X::IMatrix{T}) where {T} = PermMatrix{T,Int}(X)

PermMatrix{Tv,Ti}(A::PermMatrix) where {Tv,Ti} =
    PermMatrix(Vector{Ti}(A.perm), Vector{Tv}(A.vals))

# NOTE: bad implementation!
function _findnz(A::AbstractMatrix)
    I = findall(!iszero, A)
    getindex.(I, 1), getindex.(I, 2), A[I]
end

_findnz(A::AbstractSparseArray) = findnz(A)

function PermMatrix{Tv,Ti}(A::AbstractMatrix) where {Tv,Ti}
    i, j, v = _findnz(A)
    j == collect(1:size(A, 2)) || throw(ArgumentError("This is not a PermMatrix"))
    order = invperm(i)
    PermMatrix{Tv,Ti}(Vector{Ti}(order), Vector{Tv}(v[order]))
end
PermMatrix(A::AbstractMatrix{T}) where {T} = PermMatrix{T,Int}(A)
PermMatrix(A::SparseMatrixCSC{Tv,Ti}) where {Tv,Ti} = PermMatrix{Tv,Ti}(A) # inherit indice type
PermMatrix{Tv,Ti}(A::Diagonal{Tv}) where {Tv,Ti} =
    PermMatrix(Vector{Ti}(1:size(A, 1)), A.diag)
#PermMatrix(A::Diagonal{T}) where T = PermMatrix{T, Int}(A)
# lazy implementation
function PermMatrix{Tv,Ti,Vv,Vi}(
    A::AbstractMatrix,
) where {Tv,Ti<:Integer,Vv<:AbstractVector{Tv},Vi<:AbstractVector{Ti}}
    pm = PermMatrix(PermMatrix{Tv,Ti}(A))
    PermMatrix(Vi(pm.perm), Vv(pm.vals))
end

############## To SparseMatrixCOO ##############
function SparseMatrixCOO(A::Matrix{Tv}; atol = 1e-12) where {Tv}
    m, n = size(A)
    is = Int[]
    js = Int[]
    vs = Tv[]
    for j = 1:n
        for i = 1:m
            if abs(A[i, j]) > atol
                push!(is, i)
                push!(js, j)
                push!(vs, A[i, j])
            end
        end
    end
    SparseMatrixCOO(is, js, vs, m, n)
end

Base.convert(T::Type{<:PermMatrix}, m::AbstractMatrix) = m isa T ? m : T(m)
Base.convert(T::Type{<:IMatrix}, m::AbstractMatrix) = m isa T ? m : T(m)
Base.convert(T::Type{<:Diagonal}, m::AbstractMatrix) = m isa T ? m : T(m)
