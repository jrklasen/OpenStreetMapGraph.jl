""" Use day of week and hour of day and return the hour of week
"""
function hoursofweek(
        hours::Array{<:Integer,1}=Integer[],
        days::Array{<:Integer,1}=Integer[], 
        specialdays::Array{<:AbstractString,1}=AbstractString[]
    )::Array{UInt8,1}
    nd = length(days)
    nh = length(hours)
    nsd = length(specialdays)

    # if days and hours are empty return empty array
    # if days are empty but specialdays are not, return empty array
    if nd == 0 && nh == 0 || nd == 0 && nsd != 0
        return Array{UInt8,1}[]
    # if only days are empty generate all days
    elseif nd == 0 && nsd == 0
        days = collect(UInt8, 1:7)
        nd = length(days)
    # if hours are empty generate all hours
    elseif nh == 0
        hours = collect(UInt8, 0:23)
        nh = length(hours)
    end
    daysashours = (days .- 1) .* 24
    
    # hours per day
    out = reshape((daysashours' .+ hours), nd * nh)

    return out
end