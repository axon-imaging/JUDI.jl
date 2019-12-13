############################################################
# judiLRWF #################################################
############################################################

# Authors: Philipp Witte (pwitte@eos.ubc.ca), Henryk Modzelewski (hmodzelewski@eos.ubc.ca)
# Date: January 2017

export judiLRWF, judiLRWFexception

############################################################

# Type for linear operator representing  Pr*A(m)^-1*Ps,
# i.e. it includes source and receiver projections
struct judiLRWF{DDT<:Number,RDT<:Number} <: joAbstractLinearOperator{DDT,RDT}
    name::String
    m::Integer
    n::Integer
    info::Info
    wavelet
end


mutable struct judiLRWFexception <: Exception
    msg :: String
end


############################################################
## Constructor
"""
    judiLRWF(info, geometry)

Low-rank wavefield operator which injects a wavelet q at every point of the subsurface. \\
`info` is an `Info` structure and `wavelet` is a cell array containing the wavelet(s).

Examples
========

`F` is a modeling operator of type `judiModeling` and `w` is a weighting matrix of type `judiWeights`:

    Pr = judiProjection(info, rec_geometry)
    Pw = judiLRWF(info, q.data)

    dobs = Pr*F*Pw'*w
    dw = Pw*F'*Pr'*dobs

"""
function judiLRWF(info::Info, data; DDT::DataType=Float32, RDT::DataType=DDT)
    (DDT == Float32 && RDT == Float32) || throw(judiProjectionException("Domain and range types not supported"))
    m = info.n * info.nsrc
    n = info.n * sum(info.nt)
    wavelet = Array{Array}(undef, info.nsrc)
    for j=1:info.nsrc
        wavelet[j] = data
    end
    return judiLRWF{Float32,Float32}("restriction operator",m,n,info,wavelet)
end


function judiLRWF(info::Info, wavelet::Array{Array}; DDT::DataType=Float32, RDT::DataType=DDT)
    (DDT == Float32 && RDT == Float32) || throw(judiProjectionException("Domain and range types not supported"))
    m = info.n * info.nsrc
    n = info.n * sum(info.nt)
    return judiLRWF{Float32,Float32}("restriction operator",m,n,info,wavelet)
end



############################################################
## overloaded Base functions

# conj(judiProjection)
conj(A::judiLRWF{DDT,RDT}) where {DDT,RDT} =
    judiLRWF{DDT,RDT}("conj("*A.name*")",A.m,A.n,A.info,A.wavelet)

# transpose(judiProjection)
transpose(A::judiLRWF{DDT,RDT}) where {DDT,RDT} =
    judiLRWF{DDT,RDT}("injection operator",A.n,A.m,A.info,A.wavelet)

adjoint(A::judiLRWF{DDT,RDT}) where {DDT,RDT} =
    judiLRWF{DDT,RDT}("injection operator",A.n,A.m,A.info,A.wavelet)

############################################################
## overloaded Base *(...judiProjection...)

# *(judiLRWF,judiVector)
function *(A::judiLRWF{ADDT,ARDT},v::judiWeights{vDT}) where {ADDT,ARDT,vDT}
    A.n == size(v,1) || throw(judiLRWFexception("shape mismatch"))
    jo_check_type_match(ADDT,vDT,join(["DDT for *(judiLRWF,judiVector):",A.name,typeof(A),vDT]," / "))
    V = judiExtendedSource(A.info,A.wavelet,v.weights)
    jo_check_type_match(ARDT,eltype(V),join(["RDT from *(judiLRWF,judiWeights):",A.name,typeof(A),eltype(V)]," / "))
    return V
end

# # *(judiLRWF,judiModeling)
# function *(A::judiLRWF{CDT,ARDT},B::judiModeling{BDDT,CDT}) where {ARDT,BDDT,CDT}
#     A.n == size(B,1) || throw(judiLRWFexception("shape mismatch"))
#     compareInfo(A.info, B.info) == true || throw(judiProjectionException("info mismatch"))
#     if typeof(A.geometry) == GeometryOOC
#         m = sum(A.geometry.nsamples)
#     else
#         m = 0; for j=1:B.info.nsrc m+= length(A.geometry.xloc[j])*A.geometry.nt[j] end
#     end
#     n = B.info.n * sum(B.info.nt)
#     return judiPDE("judiProjection*judiModeling",B.info,B.model,A.geometry;options=B.options,DDT=CDT,RDT=ARDT)
# end
#
# function *(A::judiLRWF{CDT,ARDT},B::judiModelingAdjoint{BDDT,CDT}) where {ARDT,BDDT,CDT}
#     A.n == size(B,1) || throw(judiProjectionException("shape mismatch"))
#     compareInfo(A.info, B.info) == true || throw(judiProjectionException("info mismatch"))
#     if typeof(A.geometry) == GeometryOOC
#         m = sum(A.geometry.nsamples)
#     else
#         m = 0; for j=1:B.info.nsrc m+= length(A.geometry.xloc[j])*A.geometry.nt[j] end
#     end
#     n = B.info.n * sum(B.info.nt)
#     return judiPDEadjoint("judiProjection*judiModelingAdjoint",B.info,B.model,A.geometry;options=B.options,DDT=CDT,RDT=ARDT)
# end

############################################################
## Additional overloaded functions

# Subsample Modeling operator
function subsample(P::judiLRWF{ADDT,ARDT}, srcnum) where {ADDT,ARDT}
    info = Info(P.info.n, length(srcnum), P.info.nt[srcnum])
    return judiLRWF(info, P.wavelet[srcnum];DDT=ADDT,RDT=ARDT)
end

getindex(P::judiLRWF,a) = subsample(P,a)
