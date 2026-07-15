module DataProcessor

using HTTP, JSON3, StructTypes, Dates, Statistics
using Pkg: TOML

const TS_FORMAT = dateformat"yyyy-mm-ddTHH:MM:SS.sss"
parse_ts(s::AbstractString) = DateTime(s, TS_FORMAT)
format_ts(t::DateTime) = Dates.format(t, TS_FORMAT)

# Other services in this deployment sit behind an authenticating proxy, so
# outgoing requests need a bearer token. The token lives in the Julia
# package server auth file for whichever server JULIA_PKG_SERVER points at.
function auth_header()
    server = get(ENV, "JULIA_PKG_SERVER", "")
    isempty(server) && return Pair{String,String}[]
    path = joinpath(homedir(), ".julia", "servers", server, "auth.toml")
    isfile(path) || return Pair{String,String}[]
    token = get(TOML.parsefile(path), "access_token", nothing)
    token === nothing && return Pair{String,String}[]
    return ["Authorization" => "Bearer $token"]
end

struct RawReading
    instrument_id::String
    timestamp::String
    value::Float64
end
StructTypes.StructType(::Type{RawReading}) = StructTypes.Struct()

struct ProcConfig
    instrument_id::String
    dbservice_url::String
    poll_interval::Float64
    window_size::Int
end

function config_from_env()
    return ProcConfig(
        get(ENV, "INSTRUMENT_ID", "inst-1"),
        get(ENV, "DBSERVICE_URL", "https://dbservice.apps.nkottary.juliahub.dev"),
        parse(Float64, get(ENV, "POLL_INTERVAL_SECONDS", "1.0")),
        parse(Int, get(ENV, "WINDOW_SIZE", "10")),
    )
end

function fetch_new_readings(cfg::ProcConfig, since::Union{Nothing,String})
    query = "instrument_id=$(HTTP.escapeuri(cfg.instrument_id))&limit=1000"
    if since !== nothing
        query *= "&since=$(HTTP.escapeuri(since))"
    end
    resp = HTTP.get("$(cfg.dbservice_url)/raw?$query", auth_header(); readtimeout = 5)
    return JSON3.read(String(resp.body), Vector{RawReading})
end

function post_processed(cfg::ProcConfig, timestamp::String, window::Vector{Float64})
    body = JSON3.write((
        instrument_id = cfg.instrument_id,
        timestamp = timestamp,
        rolling_avg = mean(window),
        rolling_min = minimum(window),
        rolling_max = maximum(window),
        window_size = length(window),
    ))
    headers = ["Content-Type" => "application/json"; auth_header()]
    HTTP.post("$(cfg.dbservice_url)/processed", headers, body; readtimeout = 5)
end

function main()
    cfg = config_from_env()
    @info "DataProcessor starting" instrument_id = cfg.instrument_id dbservice_url = cfg.dbservice_url window_size = cfg.window_size

    window = Float64[]
    last_ts = nothing

    while true
        try
            readings = fetch_new_readings(cfg, last_ts)
            for r in readings
                push!(window, r.value)
                if length(window) > cfg.window_size
                    popfirst!(window)
                end
                post_processed(cfg, r.timestamp, window)
                last_ts = r.timestamp
            end
            if !isempty(readings)
                @info "processed batch" instrument_id = cfg.instrument_id count = length(readings) last_ts
            end
        catch e
            @warn "processing cycle failed" exception = (e, catch_backtrace())
        end
        sleep(cfg.poll_interval)
    end
end

end # module DataProcessor
