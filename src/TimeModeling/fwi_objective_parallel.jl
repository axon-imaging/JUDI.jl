# Parallel instance of fwi_objective function # Author: Philipp Witte, pwitte@eos.ubc.ca
# Date: January 2017
#

"""
    fwi_objective(model, source, dobs; options=Options())

Evaluate the full-waveform-inversion (reduced state) objective function. Returns a tuple with function value and vectorized \\
gradient. `model` is a `Model` structure with the current velocity model and `source` and `dobs` are the wavelets and \\
observed data of type `judiVector`.

Example
=======

    function_value, gradient = fwi_objective(model, source, dobs)

"""
function fwi_objective(model::Modelall, source::judiVector, dObs::judiVector; options=Options())
# fwi_objective function for multiple sources. The function distributes the sources and the input data amongst the available workers.

    p = default_worker_pool()
    fwi_objective_par = remote(TimeModeling.fwi_objective)
    fwi_objective = retry(fwi_objective_par)

    results = Array{Any}(undef, dObs.nsrc)

    @sync begin
        for j=1:dObs.nsrc
            opt_local = subsample(options,j)
            @async results[j] = fwi_objective(model, source[j], dObs[j], j; options=opt_local)
        end
    end

    # Collect and reduce gradients
    gradient = zeros(Float32, prod(model.n) + 1)

    for j=1:dObs.nsrc
        gradient += results[j]; results[j] = []
    end

    # first value corresponds to function value, the rest to the gradient
    return gradient[1], gradient[2:end]
end
