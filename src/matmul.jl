function check_compatible_sizes(C, A, B)
    n, m = size(C)
    a, k = size(A)
    b, c = size(B)
    @assert (n == a) && (m == c) && (k == b) "matrices of size $(size(C)), $(size(A)), $(size(B)) are incompatible"
    nothing
end

mul!(args...) = LinearAlgebra.mul!(args...)
(*)(args...)  = Base.:(*)(args...)

function (*)(A::MatTypes, B::MatTypes)
    T = promote_type(eltype(A), eltype(B))
    C = Matrix{T}(undef, size(A,1), size(B,2))
    mul!(C, A, B)
    C
end

function mul!(C::MatTypes{T}, A::MatTypes{T}, B::MatTypes{T};
              block_size = nothing, sizecheck=true) where {T <: Eltypes}
    sizecheck && check_compatible_sizes(C, A, B)
    if isnothing(block_size)
        if size(C, 1) >= 72
            block_size = 48
        else
            block_size = 32
        end
    end
    GC.@preserve C A B _mul!(PtrMatrix(C), PtrMatrix(A), PtrMatrix(B), block_size)
    C
end

function (*)(A::StructArray{Complex{T}, 2}, B::StructArray{Complex{T}, 2}) where {T <: Eltypes}
    C = StructArray{Complex{T}}((Matrix{T}(undef, size(A, 1), size(B,2)),
                                 Matrix{T}(undef, size(A, 1), size(B,2))))
    mul!(C, A, B)
    C
end

function mul!(C::StructArray{Complex{T}, 2}, A::StructArray{Complex{T}, 2}, B::StructArray{Complex{T}, 2};
              block_size = DEFAULT_BLOCK_SIZE, sizecheck=true) where {T <: Eltypes}
    sizecheck && check_compatible_sizes(C, A, B)
    
    if isnothing(block_size)
        if size(C, 1) >= 72
            block_size = 48
        else
            block_size = 32
        end
    end
    
    GC.@preserve C A B begin
        Cre, Cim = PtrMatrix(C.re), PtrMatrix(C.im)
        Are, Aim = PtrMatrix(A.re), PtrMatrix(A.im)
        Bre, Bim = PtrMatrix(B.re), PtrMatrix(B.im)
        # Cre, Cim = C.re, C.im
        # Are, Aim = A.re, A.im
        # Bre, Bim = B.re, B.im
        
        _mul!(    Cre, Are, Bre,  block_size)            # C.re = A.re * B.re
        _mul_add!(Cre, Aim, Bim,  block_size; factor=-1) # C.re = C.re - A.im * B.im
        _mul!(    Cim, Are, Bim,  block_size)            # C.im = A.re * B.im
        _mul_add!(Cim, Aim, Bre,  block_size)            # C.im = C.im + A.im * B.re
    end
    C
end


# function (*)(A::StructArray{Rational{T}, 2}, B::StructArray{Rational{T}, 2}) where {T <: Eltypes}
#     C = StructArray{Rational{T}}((Matrix{T}(undef, size(A, 1), size(B,2)),
#                                   Matrix{T}(undef, size(A, 1), size(B,2))))
#     mul!(C, A, B)
#     C
# end

# function mul!(C::StructArray{Rational{T}, 2}, A::StructArray{Rational{T}, 2},
#               B::StructArray{Rational{T}, 2};
#               block_size = DEFAULT_BLOCK_SIZE, sizecheck=true) where {T <: Eltypes}
#     sizecheck && check_compatible_sizes(C, A, B)

#     if isnothing(block_size)
#         if size(C, 1) >= 72
#             block_size = 48
#         else
#             block_size = 32
#         end
#     end
    
#     GC.@preserve C A B begin
#         # Cnum, Cden = PtrMatrix(C.num), PtrMatrix(C.den)
#         # Anum, Aden = PtrMatrix(A.num), PtrMatrix(A.den)
#         # Bnum, Bden = PtrMatrix(B.num), PtrMatrix(B.den)

#         Cnum, Cden = C.num, C.den
#         Anum, Aden = A.num, C.den
#         Bnum, Bden = B.num, C.den
        
#         _mul!(Cnum, Anum, Bnum, block_size) #this is wrong
#         _mul!(Cden, Aden, Bden, block_size)
#     end
#     C
# end


function _mul!(C, A, B, sz)
    n, k, m = size(C, 1), size(A, 2), size(C, 2)
    
    if n >= sz+8 && m >= sz+8 && k >= sz+8
        block_mat_mat_mul!(C, A, B, sz)
    elseif n >= sz+8 && k >= sz+8 && m <  sz+8
        block_mat_vec_mul!(C, A, B, sz)
    elseif n <  sz+8 && k >= sz+8 && m >= sz+8
        block_covec_mat_mul!(C, A, B, sz)
    elseif n >= sz+8 && k <  sz+8 && m >= sz+8
        block_vec_covec_mul!(C, A, B, sz)
    elseif n <  sz+8 && k >= sz+8 && m <  sz+8
        block_covec_vec_mul!(C, A, B, sz)
    else
        gemm_kernel!(C, A, B)
    end
end

function _mul_add!(C, A, B, sz; factor=1)
    n, k, m = size(C, 1), size(A, 2), size(C, 2)
    if n >= sz+8 && m >= sz+8 && k >= sz+8
        block_mat_mat_mul_add!(C, A, B, sz; factor=factor)
    elseif n >= sz+8 && k >= sz+8 && m <  sz+8
        block_mat_vec_mul_add!(C, A, B, sz; factor=factor)
    elseif n <  sz+8 && k >= sz+8 && m >= sz+8
        block_covec_mat_mul_add!(C, A, B, sz; factor=factor)
    elseif n >= sz+8 && k <  sz+8 && m >= sz+8
        block_vec_covec_mul_add!(C, A, B, sz; factor=factor)
    elseif n <  sz+8 && k >= sz+8 && m <  sz+8
        block_covec_vec_mul_add!(C, A, B, sz; factor=factor)
    else
        add_gemm_kernel!(C, A, B, factor)
    end
end