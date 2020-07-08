# module DiffEqsWrapperTests

using Gridap
using ForwardDiff
using LinearAlgebra
using Test
using GridapODEs.ODETools
using GridapODEs.TransientFETools
using Gridap.FESpaces: get_algebraic_operator
using GridapODEs
using DifferentialEquations

import Gridap: ∇
import GridapODEs.TransientFETools: ∂t

##

θ = 1.0

# @santiagobadia : u(x,t) = t not working with Sundials solver, not right sol?
u(x,t) = 1.0#(1.0-x[1])*x[1]*(1.0-x[2])*x[2]*t

# @santiagobadia : Even though the problem that we will solve is linear, the
# Sundials solvers seems to have no convergence problems in the nonlinear solver

u(x,t) = t#(1.0-x[1])*x[1]*(1.0-x[2])*x[2]*t



u(t::Real) = x -> u(x,t)
∂tu = ∂t(u)

f(t) = x -> ∂t(u)(x,t)-Δ(u(t))(x)

domain = (0,1,0,1)
partition = (4,4)
model = CartesianDiscreteModel(domain,partition)

order = 1

V0 = FESpace(
  reffe=:Lagrangian, order=order, valuetype=Float64,
  conformity=:H1, model=model, dirichlet_tags="boundary")
U = TransientTrialFESpace(V0,u)

trian = Triangulation(model)
degree = 2*order
quad = CellQuadrature(trian,degree)

#
a(u,v) = ∇(v)⋅∇(u)
b(v,t) = v*f(t)

res(t,u,ut,v) = a(u,v) + ut*v - b(v,t)
jac(t,u,ut,du,v) = a(du,v)
jac_t(t,u,ut,dut,v) = dut*v

t_Ω = FETerm(res,jac,jac_t,trian,quad)
op = TransientFEOperator(U,V0,t_Ω)

t0 = 0.0
tF = 1.0
dt = 0.1

U0 = U(0.0)
uh0 = interpolate_everywhere(U0,u(0.0))

ls = LUSolver()
using Gridap.Algebra: NewtonRaphsonSolver
nls = NLSolver(ls;show_trace=true,method=:newton)
odes = ThetaMethod(ls,dt,θ)
solver = TransientFESolver(odes)
sol_t = Gridap.solve(solver,op,uh0,t0,tF)

#DiffEq wrapper

ode_op = get_algebraic_operator(op)
ode_cache = allocate_cache(ode_op) # Not acceptable in terms of performance

function residual(res,du,u,p,t)
  # Problem with closure if ode_c is named ode_cache
  # @santiagobadia : Clarify this point
  ode_c = GridapODEs.ODETools.update_cache!(ode_cache,ode_op,tθ)
  GridapODEs.ODETools.residual!(res,ode_op,t,u,du,ode_c)
end

function jacobian(jac,du,u,p,gamma,t)
  ode_c = GridapODEs.ODETools.update_cache!(ode_cache,ode_op,tθ)
  z = zero(eltype(jac))
  Gridap.Algebra.fill_entries!(jac,z)
  GridapODEs.ODETools.jacobian_t!(jac,ode_op,t,u,du,gamma,ode_c)
  GridapODEs.ODETools.jacobian!(jac,ode_op,t,u,du,ode_c)
end

#end wrapper

u0 = get_free_values(uh0)
tθ = 1.0
dtθ = dt*θ

r = GridapODEs.ODETools.allocate_residual(ode_op,u0,ode_cache)
J = GridapODEs.ODETools.allocate_jacobian(ode_op,u0,ode_cache)
##
residual(r,u0,u0,nothing,tθ)
jacobian(J,u0,u0,nothing,(1/dtθ),tθ)

using Sundials
tspan = (0.0,1.0)

# To explore the Sundials solver options, e.g., BE with time step dt
f_iip = DAEFunction{true}(residual;jac=jacobian)
prob_iip = DAEProblem{true}(f_iip,u0,u0,tspan,differential_vars=[true])
sol_iip = Sundials.solve(prob_iip, IDA(), reltol=1e-8, abstol=1e-8)
@show sol_iip.u

# or iterator version
integ = init(prob_iip, IDA(), reltol=1e-8, abstol=1e-8)
step!(integ)
step!(integ)

# Show of using integrators as iterators
using Base.Iterators
for i in take(integ,100)
      @show integ.u
end

# Issue 1: No control over the linear solver, we would like to be able to
# provide certainly linear and possibly nonlinear solvers.
# Let us assume that we just want to consider a fixed point algorithm
# and we consider an implicit time integration of a nonlinear PDE.
# Our solvers are efficient since they re-use cache among
# nonlinear steps (e.g., symbolic factorization, arrays for numerical factorization)
# and for the transient case in our library, we can also reuse all this
# between time steps. Could we attain something like this using
# DifferentialEquations?

# Issue 2: We have to call twice to update_cache!, for residual and jacobian
# at each time step

# Issue 3: Iterator-like version as in GridapODEs.
# HOWEVER, is this computation lazy? I don't think so, so we need to store
# all time steps, e.g., for computing time-dependent functionals (drag or lift
# in CFD, etc), which is going to incur in a lot of memory consumption.


l2(w) = w*w

tol = 1.0e-6
_t_n = t0

for (uh_tn, tn) in sol_t
  global _t_n
  _t_n += dt
  e = u(tn) - uh_tn
  el2 = sqrt(sum( integrate(l2(e),trian,quad) ))
  @test el2 < tol
  @show get_free_values(uh_tn)
end

# end #module
