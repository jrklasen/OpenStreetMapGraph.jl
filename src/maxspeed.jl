# A dictionary of speed limits for interpreting the `maxspeedword`
maxspeedword = Dict(
    :none => 130, 
    :motorway => 130, 
    :signals => nothing, # nothing is replased by highway 
    :sign => nothing, # nothing is replased by highway 
    :rural => 100, 
    :trunk => 100, 
    :urban => 50, 
    :bicycle_road => 30, 
    :walk => 7
)

# A dictionary of speed limits for `highway` types (in this case for germany)
highwaymaxspeed = Dict(
    :rural => Dict(
        :motorway => 130, 
        :link => 80, 
        :trunk => 100, 
        :primary => 100, 
        :secondary => 100, 
        :tertiary => 100, 
        :unclassified => 100, 
        :residential => 100, 
        :living_street => 7,
        :service => 30
    ),
    :urban => Dict(
        :motorway => 130, 
        :link => 80, 
        :trunk => 50, 
        :primary => 50, 
        :secondary => 50, 
        :tertiary => 50, 
        :unclassified => 50, 
        :residential => 50, 
        :living_street => 7,
        :service => 30
    )
)


"""for now we ignore special days  
hour per week granularity
"""
function maxspeedinterpreter(
        waytags, 
        maxspeedword=maxspeedword, 
        urban=true, 
        highwaymaxspeed=highwaymaxspeed
    )::Dict{Symbol, Union{AbstractArray, Real}}

    maxspeed = parsemaxspeedkeys(
        waytags, 
        maxspeedword,
        "both", 
        urban, 
        highwaymaxspeed
    )
    maxspeedtagconditional = get(waytags, "maxspeed:conditional", "_")
    if maxspeedtagconditional != "_"
        if maxspeed == nothing
            maxspeed = missing
        end
        maxspeed = maxspeedconditionalinterpreter(maxspeedtagconditional, maxspeed)
    end
    uvmaxspeed = parsemaxspeedkeys(
        waytags, 
        maxspeedword, 
        "forward", 
        urban, 
        highwaymaxspeed
    )
    vumaxspeed = parsemaxspeedkeys(
        waytags, 
        maxspeedword, 
        "backward", 
        urban, 
        highwaymaxspeed
    )

    out = Dict{Symbol, Union{AbstractArray, Real}}()
    if uvmaxspeed != nothing
        out[:uvmaxspeed] = uvmaxspeed
    end
    if vumaxspeed != nothing
        out[:vumaxspeed] = vumaxspeed
    end
    if maxspeed != nothing
        out[:maxspeed] = maxspeed
    end

    return out
end


"""
"""
function maxspeedconditionalinterpreter(
        maxspeedconditional::AbstractString, 
        maxspeed::Union{Real,Missing}=missing,
        maxspeedword::Dict=maxspeedword
    )
    conditions = parseconditionaltag(maxspeedconditional)
    condikeys = collect(keys(conditions))

    maxspeed = repeat(Union{Real,Missing}[maxspeed], 168)
    for c = condikeys
        condi = conditions[c]
        value = parsemaxspeed(condi[:value], maxspeedword)
        hours = ruleshursofweek(condi[:rules])
        maxspeed[hours .+ 1] .=  value
    end
    return maxspeed

end


""" Search for  tags which give the maxspeed of a way
"""
function parsemaxspeedkeys(
        waytags, 
        maxspeedword=maxspeedword, 
        direction="both", 
        urban=true, 
        highwaymaxspeed=highwaymaxspeed
    )::Union{Real, Nothing}
    # if direction is given check for directional maxspeed
    if direction == "forward"
        dir = ":forward"
    elseif direction == "backward"
        dir = ":backward"
    elseif direction == "both"
        dir = ""
    end
    maxspeedtag = get(waytags, "maxspeed" * dir, "_")
    if maxspeedtag != "_"
        maxspeed = parsemaxspeed(maxspeedtag, maxspeedword)
        if maxspeed != nothing
            return maxspeed
        end
    end
    sourcemaxspeedtag = get(waytags, "source:maxspeed" * dir, "_")
    if sourcemaxspeedtag != "_"
        maxspeed = parsemaxspeed(sourcemaxspeedtag, maxspeedword)
        if maxspeed != nothing
            return maxspeed
        end
    end
    zonemaxspeedtag = get(waytags, "zone:maxspeed" * dir, "_")
    if zonemaxspeedtag != "_"
        maxspeed = parsemaxspeed(zonemaxspeedtag, maxspeedword)
        if maxspeed != nothing
            return maxspeed
        end
    end
    highwaytag = get(waytags, "highway", "_")
    if highwaytag != "_" && length(dir) == 0
        maxspeed = parsehighwaymaxspeed(highwaytag, urban, highwaymaxspeed)
        if maxspeed != nothing
            return maxspeed
        end
    end
    return nothing
end


""" maxspeed tag as number
"""
function parsemaxspeed(
        token::AbstractString, 
        maxspeedword=maxspeedword
    )::Union{Real, Nothing}
    regexmaxspeednumber = r"(\d+)"
    number = match(regexmaxspeednumber, token)
    if number != nothing
        number = parse(Int, number.match)
        regexmaxspeedunit = r"(km/h|kmh|kph|mph|knots)$"
        unit = match(regexmaxspeedunit, token)
        if unit === nothing
            return number
        else 
            if unit.match  === nothing
                return number
            elseif unit.match in ["km/h", "kmh", "kph"]
                return number
            elseif unit.match  == "mph"
                return number * 1.609
            elseif unit.match  == "knots"
                return number * 1.852
            end
        end
    else
        regexmaxspeedword = r"(none|no|motorway|signals|sign|trunk|rural|urban|bicycle_road|walk|living_street)"
        word = match(regexmaxspeedword, token)
        if word == nothing
            return nothing
        elseif word.match == "none" || word.match == "no"
            return maxspeedword[:none]
        elseif word.match == "motorway"
            return maxspeedword[:motorway]
        elseif word.match == "signals"
            return maxspeedword[:signals]
        elseif word.match == "sign"
            return maxspeedword[:signals]
        elseif word.match == "rural"
            return maxspeedword[:rural]
        elseif word.match == "trunk"
            return maxspeedword[:trunk]
        elseif word.match == "urban"
            return maxspeedword[:urban]
        elseif word.match == "bicycle_road"
            return maxspeedword[:bicycle_road]
        elseif word.match == "walk" || word.match == "living_street"
            return maxspeedword[:walk]
        else 
            @warn "Unknown maxspeed value." maxspeed=token
            return nothing
        end
    end
end

""" Use the highway tag to gess the maxspeed
"""
function parsehighwaymaxspeed(
        token::AbstractString, 
        urban=true, 
        highwaymaxspeed=highwaymaxspeed
    )::Union{Real, Nothing}
    condkey = urban ? :urban : :rural
    regexhighway = r"(link|motorway|trunk|primary|secondary|tertiary|unclassified|residential|living_street|service)"
    word = match(regexhighway, token)
    if word != nothing
        if word.match == "motorway"
            return highwaymaxspeed[condkey][:motorway]
        elseif word.match == "link"
            return highwaymaxspeed[condkey][:link]
        elseif word.match == "trunk"
            return highwaymaxspeed[condkey][:trunk]
        elseif word.match == "primary"
            return highwaymaxspeed[condkey][:primary]
        elseif word.match == "secondary"
            return highwaymaxspeed[condkey][:secondary]
        elseif word.match == "tertiary"
            return highwaymaxspeed[condkey][:tertiary]
        elseif word.match == "unclassified"
            return highwaymaxspeed[condkey][:unclassified]
        elseif word.match == "residential"
            return highwaymaxspeed[condkey][:residential]
        elseif word.match == "living_street"
            return highwaymaxspeed[condkey][:living_street]
        elseif word.match == "service"
            return highwaymaxspeed[condkey][:service]
        else 
            @warn "Unknown highway maxspeed value." maxspeed=token
            return nothing
        end
    end
end


""" Join rules to hours of week
"""
function ruleshursofweek(rules)
    ruleskeys = collect(keys(rules))

    hours = Integer[]
    # one condition with r rules
    for r = ruleskeys
        rule = rules[r]
        h = hoursofweek(rule[:hoursofday], rule[:daysofweek], rule[:specialdays])
        if rule[:words] == ["off"]
            setdiff!(hours, h)
        elseif rule[:words] == ["signal"] || rule[:words] == ["wet"]
            # leave `hours` as is
        elseif length(rule[:words]) > 0
            @warn "A unhandel word in a conditional tag was observed." word = rule[:words]
        else
            union!(hours, h)
        end
    end
    return hours
end
