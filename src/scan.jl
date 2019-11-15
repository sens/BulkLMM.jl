###########################################################
# genome scan function; no covariates, two genotype groups
###########################################################

using Distributed
using Random
using LinearAlgebra
using SharedArrays

include("lmm.jl")
include("util.jl")


function scan(y::Array{Float64,2},g::Array{Float64,2},
                   K::Array{Float64,2},reml::Bool,method::String="null")
    if(method=="null")
        return scan_null(y,g,K,reml)
    elseif(method=="alt")
        return scan_alt(y,g,K,reml)
    end
end

###
# scan markers under the null
###

function scan_null(y::Array{Float64,2},g::Array{Float64,2},
                   K::Array{Float64,2},reml::Bool)

    # number of markers
    (n,m) = size(g)
    # make intercept
    intcpt = ones(n,1)
    # rotate data
    (y0,X0,lambda0) = rotateData(y,[intcpt g],K)
    # fit null lmm
    out00 = flmm(y0,reshape(X0[:,1], :, 1),lambda0,reml)
    # weights proportional to the variances
    wts = makeweights( out00.h2,lambda0 )
    # rescale by weights
    rowDivide!(y0,sqrt.(wts))
    rowDivide!(X0,sqrt.(wts))

    # perform genome scan
    out0 = rss(y0,reshape(X0[:,1],n,1))
    lod = zeros(m)
    X = zeros(n,2)
    X[:,1] = X0[:,1]
    for i = 1:m
        X[:,2] = X0[:,i+1]
        out1 = rss(y0,X)
        lod[i] = (n/2)*(log10(out0[1]) - log10(out1[1]))
    end

    return ( out00.sigma2, out00.h2, lod )

end

## re-estimate variance components under alternative

function scan_alt(y::Array{Float64,2},g::Array{Float64,2},
                   K::Array{Float64,2},reml::Bool)

    # number of markers
    (n,m) = size(g)
    # make intercept
    intcpt = ones(n,1)
    # rotate data
    (y0,X0,lambda0) = rotateData(y,[intcpt g],K)

    X00 = reshape(X0[:,1], :, 1)
    # fit null lmm
    # out00 = flmm(y0,X00,lambda0,reml)
    out00 = flmm(y0,X00,lambda0,10)
    

    lod = zeros(m)
    X = zeros(n,2)
    X[:,1] = X0[:,1]
    for i = 1:m
        X[:,2] = X0[:,i+1]
        # out11 = flmm(y0,X,lambda0,reml, h20=out00.h2, d=1.0)
        out11 = flmm(y0,X,lambda0,10)
        lod[i] = (out11.ell-out00.ell)/log(10)
    end

    return ( out00.sigma2, out00.h2, lod )

end

## genome scan with permutations
## no covariates
## one-df tests    
function scan(y::Array{Float64,2},g::Array{Float64,2},
              K::Array{Float64,2},nperm::Int64=1024,
              rndseed::Int64=0,reml::Bool=true)

    # number of markers
    (n,m) = size(g)
    # make intercept
    intcpt = ones(n,1)
    # rotate data
    (y0,X0,lambda0) = rotateData(y,[intcpt g],K)
    # fit null lmm
    vc = flmm(y0,reshape(X0[:,1], :, 1),lambda0,reml)
    # weights proportional to the variances
    wts = makeweights( vc.h2,lambda0 )
    # rescale by weights; now these have same mean/variance and are independent
    rowDivide!(y0,sqrt.(wts))
    rowDivide!(X0,sqrt.(wts))

    ## random permutations; the first column is the original data
    rng = MersenneTwister(rndseed);
    y0perm = shuffleVector(rng,y0[:,1],nperm,original=true)

    ## null rss vector
    rss00 = rss(y0perm,reshape(X0[:,1],n,1))
    rss1 = similar(out0)
    ## make array to hold LOD scores
    lod = zeros(nperm+1,m)
    ## initialize covariate matrix
    X = zeros(n,2)
    X[:,1] = X0[:,1]
    ## loop over markers
    for i = 1:m
        ## change the second column of covariate matrix X
        X[:,2] = X0[:,i+1]
        ## alternative rss
        rss1[:] = rss(y0perm,X)
        ## calculate LOD score and assign
        lod[:,i] = (n/2)*(log10.(rss0) .- log10.(rss1))
    end

    return lod

end

## genome scan with permutations
## more than 1df tests
function scan(y::Array{Float64,2},g::Array{Float64,3},
              K::Array{Float64,2},nperm::Int64=1024,
              rndseed::Int64=0,reml::Bool=true)

    # number of markers
    (n,m,p) = size(g)
    # flatted genotypes
    g = permutedims(g,(1,3,2))
    flatg = reshape(g,(n,p*m))
    # make intercept
    intcpt = ones(n,1)
    # rotate data
    (y0,X0,lambda0) = rotateData(y,[intcpt flatg],K)
    # fit null lmm
    vc = flmm(y0,reshape(X0[:,1], :, 1),lambda0,reml)
    # weights proportional to the variances
    wts = makeweights( vc.h2,lambda0 )
    # rescale by weights; now these have same mean/variance and are independent
    rowDivide!(y0,sqrt.(wts))
    rowDivide!(X0,sqrt.(wts))

    ## random permutations; the first column is the original data
    rng = MersenneTwister(rndseed);
    y0perm = shuffleVector(rng,y0[:,1],nperm,original=true)

    ## null rss vector
    rss00 = rss(y0perm,reshape(X0[:,1],n,1))
    rss1 = similar(out0)
    ## make array to hold LOD scores
    lod = zeros(nperm+1,m)
    ## initialize covariate matrix
    X = zeros(n,p)
    X[:,1] = X0[:,1]
    ## loop over markers
    for i = 1:m
        ## change the rest of the elements of covariate matrix X
        idx = 1+((i-1)*p):(i*p-1)
        X[:,2:(p-1)] = X0[:,idx]
        ## alternative rss
        rss1[:] = rss(y0perm,X)
        ## calculate LOD score and assign
        lod[:,i] = (n/2)*(log10.(rss0) .- log10.(rss1))
    end

    return lod

end



