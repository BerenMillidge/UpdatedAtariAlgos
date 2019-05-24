# aim is to allow this to actually use atari algos here and be able to display them using julia
# and wrap them in the standard environment for reinforcement learning... i.e. copying what the guy did for atari algos...
# but brought up to date!

import ArcadeLearningEnvironment
const ALE = ArcadeLearningEnvironment

using Plots
using Reinforce

rom_directory() = joinpath(dirname(@__FILE__), "..", "deps", "rom_files")
rom_directory()
# -----------------------------------------------

abstract type AbstractEnvironment end
"""
Maintains the reference to a ALE rom object. Loads a ROM on construction.
You should `close(game)` explicitly.
"""
mutable struct AtariEnv <: AbstractEnvironment
    ale::ALE.ALEPtr
    lives::Int
    died::Bool
    reward::Float64
    score::Float64
    nframes::Int
    width::Int
    height::Int
    rawscreen::Vector{Cuchar}  # raw screen data from the most recent frame
    state::Vector{Float64}  # the game state... raw screen data converted to Float64
    screen::Matrix{RGB{Float64}}

    function AtariEnv(romfile::AbstractString)
        if !isfile(romfile)
            oldromfile = romfile
            romfile = joinpath(rom_directory(), lowercase(romfile) * ".bin")
            if !isfile(romfile)
                error("Couldn't load rom.  Tried $oldromfile and $romfile")
            end
        end
        ale = ALE.ALE_new()
        ALE.loadROM(ale, romfile)
        w = ALE.getScreenWidth(ale)
        h = ALE.getScreenHeight(ale)
        println("w: $w, h: $h")
        #rawscreen = Array{Cuchar, w * h * 3}
        rawscreen = zeros(UInt8, w*h*3)
        println("rawscreen: $(typeof(rawscreen)) $(size(rawscreen))")
        state = zeros(Float64, w*h*3)
        println("state: $(typeof(state))")
        screen = fill(RGB{Float64}(0,0,0), h, w)
        new(ale, 0, false, 0., 0., 0, w, h, rawscreen, state, screen)
    end
end

Base.string(game::AtariEnv) = "AtariEnv($(game.state)){lives=$(game.lives), died=$(game.died), reward=$(game.reward), score=$(game.score), nframe=$(game.nframes)}"
Base.print(io::IO, game::AtariEnv) = print(io, string(game))

function Base.close(game::AtariEnv)
    game.state = Closed
    ALE.ALE_del(game.ale)
end


# -----------------------------------------------
# display/plot

function update_screen(game::AtariEnv)
    idx = 1
    for i in 1:game.height, j in 1:game.width
        game.screen[i,j] = RGB{Float64}(game.state[idx], game.state[idx+1], game.state[idx+2])
        idx += 3
    end
    game.screen
end

# a Plots recipe which builds an "image" plot from the game screen
@recipe function f(game::AtariEnv)
    ticks := nothing
    foreground_color_border := nothing
    grid := false
    legend := false
    aspect_ratio := 1

    # convert to Image
    update_screen(game)
end

const _canvas = Ref{Any}(nothing)

# NOTE: this uses ImageView/Tk to display the game screen in a standalone window
# but I've found Tk to be horribly buggy and prone to crashing my system, so
# it's not active right now.

# function Base.display(game::AtariEnv)
#     screen = update_screen(game)
#     if _canvas[] == nothing
#         @eval import ImageView
#         _canvas[], _ = ImageView.view(screen)
#     else
#         ImageView.view(_canvas[], screen)
#     end
#     return
# end

# -----------------------------------------------
# to screen will reshape the game state to the size of the screen
# which is good and nice!
function to_screen(game::AtariEnv)
	mat = zeros(game.height, game.width,3)
	idx = 1
	for i in 1:game.height
		for j in 1:game.width
			for k in 0:2
				mat[i,j,k+1] = game.state[idx]
				#println(idx)
				idx +=1
			end
		end
	end
	return mat
end

function update_state(game::AtariEnv, reshape=true)
    # get the raw screen data
    ALE.getScreenRGB(game.ale, game.rawscreen)
    for i in eachindex(game.rawscreen)
        game.state[i] = game.rawscreen[i] / 256
    end
    game.lives = ALE.lives(game.ale)
	if reshape
		return to_screen(game)
	else
		return game.state
	end
end

get_screen(game::AtariEnv,s) = reshape(s,(game.height, game.width,3))


function reset!(game::AtariEnv)
    ALE.reset_game(game.ale)
    game.lives = 0
    game.died = false
    game.reward = 0
    game.score = 0
    game.nframes = 0
    update_state(game)
end

function step!(game::AtariEnv, s, a)
    # act and get the reward and new state
    game.reward = ALE.act(game.ale, a)
    game.score += game.reward
    game.reward, update_state(game)
end

finished(game::AtariEnv, s′) = ALE.game_over(game.ale)
#actions(game::AtariEnv, s) = DiscreteSet(ALE.getMinimalActionSet(game.ale))
actions(game::AtariEnv, s) = ALE.getMinimalActionSet(game.ale)
action_space(game::AtariEnv) = ALE.getMinimalActionSet((game.ale))

# -----------------------------------------------

function download_roms(ask::Bool = true)
    if ask
        println("This function will download Atari roms... you take all responsibility for what the function does.  Type 'OK' if you agree.")
        if chomp(readline()) != "OK"
            return
        end
    end

    dir = dirname(@__FILE__)
    romdir = joinpath(dir, "..", "deps", "rom_files")
    if !isdir(romdir)
        mkdir(romdir)

        # download and unzip the roms, then cleanup zips
        urlbase = "http://www.atariage.com/2600/emulation/RomPacks/"
        for fn in ["Atari2600_A-E.zip",
                   "Atari2600_F-J.zip",
                   "Atari2600_K-P.zip",
                   "Atari2600_Q-S.zip",
                   "Atari2600_T-Z.zip"]
            localfn = joinpath(romdir, fn)
            download(urlbase*fn, localfn)
            run(`unzip -u $localfn -d $romdir`)
            rm(localfn)
        end

        # rename all to lowercase letters
        for fn in readdir(romdir)
            newfn = lowercase(fn)
            if newfn != fn
                try
                    mv(joinpath(romdir, fn), joinpath(romdir, newfn))
                catch
                    throw("Cannot find file!")
                end
            end
        end
    end
end
