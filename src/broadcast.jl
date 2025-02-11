@static if VERSION < v"1.2"
    Base.size(bc::Broadcasted) = map(length, axes(bc))
    Base.length(bc::Broadcasted) = prod(size(bc))
end

# patches
LinearAlgebra.fzero(S::IMatrix) = zero(eltype(S))

Broadcast.BroadcastStyle(::Type{<:IMatrix}) = StructuredMatrixStyle{Diagonal}()

# specialize identity
Broadcast.broadcasted(
    ::AbstractArrayStyle{2},
    ::typeof(*),
    a::IMatrix{T},
    b::IMatrix,
) where {T} = IMatrix{T}(a.n)
Broadcast.broadcasted(
    ::AbstractArrayStyle{2},
    ::typeof(*),
    a::IMatrix,
    b::AbstractVecOrMat,
) = Diagonal(b)
Broadcast.broadcasted(
    ::AbstractArrayStyle{2},
    ::typeof(*),
    a::AbstractVecOrMat,
    b::IMatrix,
) = Diagonal(a)

Broadcast.broadcasted(
    ::AbstractArrayStyle{2},
    ::typeof(*),
    a::IMatrix,
    b::Number,
) = Diagonal(fill(b, a.n))
Broadcast.broadcasted(
    ::AbstractArrayStyle{2},
    ::typeof(*),
    a::Number,
    b::IMatrix,
) where {S} = Diagonal(fill(a, b.n))

# specialize perm matrix
function _broadcast_perm_prod(A::PermMatrix, B::AbstractMatrix)
    dest = similar(A, Base.promote_op(*, eltype(A), eltype(B)))
    i = 1
    @inbounds for j in dest.perm
        dest[i, j] = A[i, j] * B[i, j]
        i += 1
    end
    return dest
end

Broadcast.broadcasted(
    ::AbstractArrayStyle{2},
    ::typeof(*),
    A::PermMatrix,
    B::AbstractMatrix,
) = _broadcast_perm_prod(A, B)
Broadcast.broadcasted(
    ::AbstractArrayStyle{2},
    ::typeof(*),
    A::AbstractMatrix,
    B::PermMatrix,
) = _broadcast_perm_prod(B, A)
Broadcast.broadcasted(::AbstractArrayStyle{2}, ::typeof(*), A::PermMatrix, B::PermMatrix) =
    _broadcast_perm_prod(A, B)

Broadcast.broadcasted(::AbstractArrayStyle{2}, ::typeof(*), A::PermMatrix, B::IMatrix) =
    Diagonal(A)
Broadcast.broadcasted(::AbstractArrayStyle{2}, ::typeof(*), A::IMatrix, B::PermMatrix) =
    Diagonal(B)

function _broadcast_diag_perm_prod(A::Diagonal, B::PermMatrix)
    dest = similar(A)
    i = 1
    @inbounds for j in B.perm
        if i == j
            dest[i, i] = A[i, i] * B[i, i]
        else
            dest[i, i] = 0
        end
        i += 1
    end
    return dest
end

Broadcast.broadcasted(::AbstractArrayStyle{2}, ::typeof(*), A::PermMatrix, B::Diagonal) =
    _broadcast_diag_perm_prod(B, A)
Broadcast.broadcasted(::AbstractArrayStyle{2}, ::typeof(*), A::Diagonal, B::PermMatrix) =
    _broadcast_diag_perm_prod(A, B)

# TODO: commit this upstream
# specialize Diagonal .* SparseMatrixCSC
Broadcast.broadcasted(
    ::AbstractArrayStyle{2},
    ::typeof(*),
    A::Diagonal,
    B::SparseMatrixCSC,
) = Broadcast.broadcasted(*, A, Diagonal(B))

Broadcast.broadcasted(
    ::AbstractArrayStyle{2},
    ::typeof(*),
    A::SparseMatrixCSC,
    B::Diagonal,
) = Broadcast.broadcasted(*, Diagonal(A), B)

Broadcast.broadcasted(
    ::AbstractArrayStyle{2},
    ::typeof(*),
    a::PermMatrix,
    b::Number,
) = PermMatrix(a.perm, a.vals .* b)

Broadcast.broadcasted(
    ::AbstractArrayStyle{2},
    ::typeof(*),
    a::Number,
    b::PermMatrix,
) = PermMatrix(b.perm, a .* b.vals)