"""
    zerooutsparse(S)

Zero out the stored entries of the matrix. The sparsity pattern is not affected. 
"""
function zerooutsparse(S)
    S.nzval .= zero(eltype(S.nzval))
    return S
end

function _binary_search(array::Array{IT,1}, target::IT, left::IT, right::IT) where {IT}
    @inbounds while left <= right # Generating the middle element position 
        mid = fld((left + right), 2) # If element > mid, then it can only be present in right subarray
        if array[mid] < target
            left = mid + 1 # If element < mid, then it can only be present in left subarray 
        elseif array[mid] > target
            right = mid - 1 # If element is present at the middle itself 
        else # == 
            return mid
        end
    end
    return 0
end

function _updroworcol!(nzval, i, v, st, fi, r_or_c)
    k = _binary_search(r_or_c, i, st, fi)
    if k > 0
        nzval[k] += v
    end
end

"""
    addtosparse(S::T, I, J, V) where {T<:SparseArrays.SparseMatrixCSC}

Add values to sparse CSC matrix.

Add the values from the array `V` given the row and column indexes in the arrays
`I` and `J`. The expectation is that the indexes respect the sparsity pattern of
the sparse array `S`. 
"""
function addtosparse(S::T, I, J, V) where {T<:SparseArrays.SparseMatrixCSC}
    nzval = S.nzval
    colptr = S.colptr
    rowval = S.rowval
    Threads.@threads for t in eachindex(J)
        j = J[t]
        _updroworcol!(nzval, I[t], V[t], colptr[j], colptr[j+1] - 1, rowval)
    end
    return S
end

"""
    addtosparse(S::T, I, J, V) where {T<:SparseMatricesCSR.SparseMatrixCSR}

Add values to sparse CSR matrix.

Add the values from the array `V` given the row and column indexes in the arrays
`I` and `J`. The expectation is that the indexes respect the sparsity pattern of
the sparse array `S`. 
"""
function addtosparse(S::T, I, J, V) where {T<:SparseMatricesCSR.SparseMatrixCSR}
    nzval = S.nzval
    rowptr = S.rowptr
    colval = S.colval
    Threads.@threads for t in eachindex(I)
        i = I[t]
        _updroworcol!(nzval, J[t], V[t], rowptr[i], rowptr[i+1] - 1, colval)
    end
    return S
end

"""
    add_to_matrix!(
        S,
        assembler::AT
    ) where {AT<:AbstractSysmatAssembler}

Update the global matrix.

Use the sparsity pattern in `S`, and the COO data collected in the assembler.
"""
function add_to_matrix!(S, assembler::AT) where {AT<:AbstractSysmatAssembler}
    # At this point all data is in the buffer
    assembler._buffer_pointer = assembler._buffer_length + 1
    setnomatrixresult(assembler, false)
    return addtosparse(S, assembler._rowbuffer, assembler._colbuffer, assembler._matbuffer)
end