# UpdatedAtariAlgos
Fork of the excellent AtariAlgos by Tom Breloff, updated to work with Julia 1.0. Also removes the dependency on the Reinforce framework.

Setup:
```julia
Pkg.clone("https://github.com/Bmillidgework/UpdatedAtariAlgos.jl")
```

You can use plots to plot a game also!
### Example
```julia
using UpdatedAtariAlgos
using Plots
using StatsBase

# construct game of breakout
game = AtariEnv("path/to/breakout.bin")
s = reset!(game)
A = action_space(game)
rewards = []
@gif for i in 1:100
  global s
  a = sample(A)
  r,s = step!(game, s,a)
  push!(rewards, r)
  plot(plot(game), sticks(rewards,yticks=nothing),  layout=@layout [a;b{0.2h}])
end
```
