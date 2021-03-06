# Model structure
# Author: Philipp Witte, pwitte@eos.ubc.ca
# Date: January 2017
#

const IntTuple = Union{Tuple{Integer,Integer}, Tuple{Integer,Integer,Integer},Array{Int64,1},Array{Int32,1}}
const RealTuple = Union{Tuple{Real,Real}, Tuple{Real,Real,Real},Array{Float64,1},Array{Float32,1}}

export Model, Modelall, Model_TTI, get_dt

###################################################################################################
# Isotropic acoustic

"""
    Model
        n::IntTuple
        d::RealTuple
        o::RealTuple
        nb::Integer
        m::Array
        rho::Array

Model structure for seismic velocity models.

`n`: number of gridpoints in (x,y,z) for 3D or (x,z) for 2D

`d`: grid spacing in (x,y,z) or (x,z) (in meters)

`o`: origin of coordinate system in (x,y,z) or (x,z) (in meters)

`nb`: number of absorbing boundary points in each direction

`m`: velocity model in slowness squared (s^2/km^2)

`rho`: density (g / m^3)


Constructor
===========

The parameters `n`, `d`, `o` and `m` are mandatory, whith `nb` and `rho` being optional input arguments.

    Model(n, d, o, m; nb=40, rho=ones(n))


"""
mutable struct Model
    n::IntTuple
    d::RealTuple
    o::RealTuple
    nb::Integer # number of absorbing boundaries points on each side
    m   # slowness squared
    rho # density in g / m^3 (1 for water)
end


###################################################################################################
# Pseudo-acoustic VTI/TTI

"""
    Model_TTI
        n::IntTuple
        d::RealTuple
        o::RealTuple
        nb::Integer
        m::Array
        epsilon::Array
        delta::Array
        theta::Array
        phi::Array
        rho::Array

Model_TTI structure for seismic velocity models.

`n`: number of gridpoints in (x,y,z) for 3D or (x,z) for 2D

`d`: grid spacing in (x,y,z) or (x,z) (in meters)

`o`: origin of coordinate system in (x,y,z) or (x,z) (in meters)

`nb`: number of absorbing boundary points in each direction

`m`: velocity model in slowness squared (s^2/km^2)

`epsilon`: Epsilon thomsen parameter ( between -1 and 1)

`delta`: Delta thomsen parameter ( between -1 and 1 and delta < epsilon)

`theta`: Anisotopy dip in radian

`phi`: Anisotropy asymuth in radian

`rho`: density (g / m^3)

Constructor
===========

The parameters `n`, `d`, `o` and `m` are mandatory, whith `nb` and `rho` being optional input arguments.

    Model_TTI(n, d, o, m; nb=40, epsilon=0, delta=0, theta=0, phi=0, rho=ones(n))
"""
# Object for velocity/slowness models
mutable struct Model_TTI
    n::IntTuple
    d::RealTuple
    o::RealTuple
    nb::Integer # number of absorbing boundaries points on each side
    m   # slowness squared
    epsilon
    delta
    theta
    phi
    rho
end


###################################################################################################
# Constructors


function Model(n::IntTuple, d::RealTuple, o::RealTuple, m;
    epsilon=nothing, delta=nothing, theta=nothing, phi=nothing, rho=nothing, nb=40)

    # Default density
    isnothing(rho) && (rho = 1)

    # VTI/TTI or pure isotropic?
    if ~isnothing(epsilon) || ~isnothing(delta) || ~isnothing(theta) || ~isnothing(phi)
        
        # Default arguments
        isnothing(epsilon) && (epsilon = 0)
        isnothing(delta) && (delta = 0)
        isnothing(theta) && (theta = 0)
        isnothing(phi) && (phi = 0)

        return Model_TTI(n, d, o, nb, m, epsilon, delta, theta, phi, rho)
    else
        return Model(n, d, o, nb, m, rho)
    end
end

function Model(n::IntTuple, d::RealTuple, o::RealTuple, m, rho; nb=40)
    isnothing(rho) && (rho = 1)
    return Model(n, d, o, nb, m, rho)
end

const Modelall = Union{Model_TTI, Model}

get_dt(Model::Modelall) = calculate_dt(Model)
