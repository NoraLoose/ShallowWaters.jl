struct Constants{T<:AbstractFloat}

    # RUNGE-KUTTA COEFFICIENTS 3rd/4th order including timestep Δt
    RKaΔt::Array{T,1}
    RKbΔt::Array{T,1}

    # BOUNDARY CONDITIONS
    one_minus_α::T      # tangential boundary condition for the ghost-point copy

    # PHYSICAL CONSTANTS
    g::T                    # gravity
    cD::T                   # quadratic bottom friction - incl grid spacing
    rD::T                   # linear bottom friction - incl grid spacing
    γ::T                    # frequency of interface relaxation
    cSmag::T                # Smagorinsky constant
    νB::T                   # biharmonic diffusion coefficient
    rSST::T                 # tracer restoring timescale
    jSST::T                 # tracer consumption timescale
    SSTmin::T               # tracer minimum
end

"""Generator function for the mutable struct Constants."""
function Constants{T}(P::Parameter,G::Grid) where {T<:AbstractFloat}

    # Runge-Kutta 3rd/4th order coefficients including time step Δt
    # (which includes the grid spacing Δ too)
    if P.RKo == 3     # version 2
        RKaΔt = T.([1/4,0.,3/4]*G.dtint/G.Δ)
        RKbΔt = T.([1/3,2/3]*G.dtint/G.Δ)
    elseif P.RKo == 4
        RKaΔt = T.([1/6,1/3,1/3,1/6]*G.dtint/G.Δ)
        RKbΔt = T.([.5,.5,1.]*G.dtint/G.Δ)
    end

    one_minus_α = T(1-P.α)    # for the ghost point copy/tangential boundary conditions
    g = T(P.g)                # gravity - for Bernoulli potential

    # BOTTOM FRICTION COEFFICENTS
    # incl grid spacing Δ for non-dimensional gradients
    cD = T(-G.Δ*P.cD)             # quadratic drag [m]
    rD = T(-G.Δ/(P.τD*24*3600))   # linear drag [m/s]

    # INTERFACE RELAXATION FREQUENCY
    # incl grid spacing Δ for non-dimensional gradients
    γ = T(G.Δ/(P.t_relax*3600*24))    # [m/s]

    # BIHARMONIC DIFFUSION
    cSmag = T(-P.cSmag)   # Smagorinsky coefficient
    νB = T(-P.νB/30000)   # linear scaling based on 540m^s/s at Δ=30km

    # TRACER ADVECTION
    rSST = T(G.dtadvint/(P.τSST*3600*24))    # tracer restoring [1]
    jSST = T(G.dtadvint/(P.jSST*3600*24))    # tracer consumption [1]
    SSTmin = T(P.SSTmin)

    return Constants{T}(RKaΔt,RKbΔt,one_minus_α,g,cD,rD,γ,cSmag,νB,rSST,jSST,SSTmin)
end
