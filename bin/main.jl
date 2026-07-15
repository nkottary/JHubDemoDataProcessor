using Pkg
const BASE_PATH = joinpath(@__DIR__, "..")
Pkg.activate(BASE_PATH)

include(joinpath(BASE_PATH, "src", "DataProcessor.jl"))
using .DataProcessor

DataProcessor.main()
