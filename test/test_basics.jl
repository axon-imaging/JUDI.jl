# Author: Mathias Louboutin, mlouboutin3@gatech.edu
# Date: May 2020
#

using JUDI.TimeModeling, PyCall, LinearAlgebra, PyPlot, Test

ftol = 1f-6

function test_model(ndim; tti=false)
    n = Tuple(121 for i=1:ndim)
    o = Tuple(0. for i=1:ndim)
    d = Tuple(10. for i=1:ndim)
    m = .5f0 .+ rand(Float32, n...)
    if !tti
        model = Model(n, d, o, m; nb=10)
        model2 = Model(n, d, o, m, nothing; nb=10)
        @test model.n == model2.n
        @test model.d == model2.d
        @test model.o == model2.o
        @test model.m == model2.m
        @test model.rho == 1
        @test model2.rho == 1
    else
        epsilon = .1f0 * m
        delta = .1f0 * m
        theta = .1f0 * m
        phi = .1f0 * m
        model = Model(n, d, o, m; nb=10, epsilon=epsilon, delta=delta, theta=theta, phi=phi)
    end
    return model
end

# Test padding and its adjoint
function test_padding(ndim)

    model = test_model(ndim; tti=false)
    modelPy = devito_model(model, Options())

    v0 = sqrt.(1f0 ./model.m)
    cut = remove_padding(deepcopy(modelPy.vp.data), modelPy.padsizes; true_adjoint=true)
    vpdata = deepcopy(modelPy.vp.data)

    @show dot(v0, cut)/dot(vpdata, vpdata)
    @test isapprox(dot(v0, cut), dot(vpdata, vpdata))
end

function test_limit_m(ndim, tti)
    model = test_model(ndim; tti=tti)
    srcGeometry = example_src_geometry()
    recGeometry = example_rec_geometry(cut=true)
    dm = rand(Float32, model.n...)
    new_mod, dm_n = limit_model_to_receiver_area(srcGeometry, recGeometry, deepcopy(model), 100f0; pert=dm)

    # check inds
    inds = ndim == 3 ? [6:116, 1:11, 1:121] : [6:116, 1:121]
    @test new_mod.n[1] == 111
    @test new_mod.n[end] == 121
    if ndim == 3
        @test new_mod.n[2] == 11
    end

    @test isapprox(new_mod.m, model.m[inds...]; rtol=ftol)
    @test isapprox(dm_n, vec(dm[inds...]); rtol=ftol)
    if tti
        @test isapprox(new_mod.epsilon, model.epsilon[inds...]; rtol=ftol)
        @test isapprox(new_mod.delta, model.delta[inds...]; rtol=ftol)
        @test isapprox(new_mod.theta, model.theta[inds...]; rtol=ftol)
        @test isapprox(new_mod.phi, model.phi[inds...]; rtol=ftol)
    end

    ex_dm = extend_gradient(model, new_mod, dm_n)
    @test size(ex_dm) == size(dm)

end

@testset "Test basic utilities" begin
    for ndim=[2, 3]
        test_padding(ndim)
    end
    opt = Options(frequencies=[[2.5, 4.5], [3.5, 5.5]])
    @test subsample(opt, 1).frequencies[1] == [2.5, 4.5]
    @test subsample(opt, 2).frequencies[1] == [3.5, 5.5]

    for ndim=[2, 3]
        for tti=[true, false]
            test_limit_m(ndim, tti)
        end
    end

    # Test model
    for ndim=[2, 3]
        for tti=[true, false]
            model =  test_model(ndim; tti=tti)

            # Default dt
            modelPy = devito_model(model, Options())
            @test get_dt(model) == calculate_dt(model)
            @test isapprox(modelPy.critical_dt, calculate_dt(model))
            @test isapprox(calculate_dt(model; dt=.5f0), .5f0)

            # Input dt
            modelPy = devito_model(model, Options(dt_comp=.5f0))
            @test modelPy.critical_dt == .5f0

            # Verify nt
            srcGeometry = example_src_geometry()
            recGeometry = example_rec_geometry(cut=true)
            nt1 = get_computational_nt(srcGeometry, recGeometry, model)
            nt2 = get_computational_nt(srcGeometry, model)
            nt3 = get_computational_nt(srcGeometry, recGeometry, model; dt=1f0)
            nt4 = get_computational_nt(srcGeometry, model::Modelall; dt=1f0)
            @test all(nt1 .== (trunc(Int64, 1000f0 / calculate_dt(model)) + 1))
            @test all(nt1 .== nt2)
            @test all(nt3 .== 1001)
            @test all(nt4 .== 1001)
        end
    end
end