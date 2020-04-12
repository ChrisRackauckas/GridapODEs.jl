# Toy linear ODE with 2 DOFs
# u_1_t - a * u_1 = 0
# u_2_t - b * u_1 - c * u_2 = 0

import GridapTimeStepper.ODETools: ODEOperator
import GridapTimeStepper.ODETools: allocate_cache
import GridapTimeStepper.ODETools: update_cache!
import GridapTimeStepper.ODETools: allocate_residual
import GridapTimeStepper.ODETools: jacobian!
import GridapTimeStepper.ODETools: jacobian_t!
import GridapTimeStepper.ODETools: allocate_jacobian
import GridapTimeStepper.ODETools: residual!

struct ODEOperatorMock{T<:Real} <: ODEOperator
  a::T
  b::T
  c::T
end

function residual!(r::AbstractVector,op::ODEOperatorMock,t::Real,u::AbstractVector,u_t::AbstractVector,op_cache)
  r .= 0
  r[1] = u_t[1] - op.a * u[1]
  r[2] = u_t[2] - op.b * u[1] - op.c * u[2]
  r
end

function allocate_residual(op::ODEOperatorMock,u::AbstractVector,cache)
  zeros(2)
end

function jacobian!(J::AbstractMatrix,op::ODEOperatorMock,t::Real,u::AbstractVector,u_t::AbstractVector,op_cache)
  J[1,1] += -op.a
  J[2,1] += -op.b
  J[2,2] += -op.c
  J
end

function jacobian_t!(J::AbstractMatrix,op::ODEOperatorMock,t::Real,u::AbstractVector,u_t::AbstractVector,du_t_u::Real,op_cache)
  J[1,1] += 1.0*du_t_u
  J[2,2] += 1.0*du_t_u
  J
end

function allocate_jacobian(op::ODEOperatorMock,u::AbstractVector,cache)
  zeros(2,2)
end

allocate_cache(op::ODEOperatorMock) = nothing
update_cache!(cache,op::ODEOperatorMock,t::Real) = nothing
