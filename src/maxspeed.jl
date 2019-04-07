# A dictionary of speed limits for interpreting the `maxspeedword`
maxspeedword = Dict(
    :no => 130,
    :none => 130, 
    :motorway => 130, 
    :signals => nothing, # nothing is replased by highway 
    :sign => nothing,    # nothing is replased by highway 
    :rural => 100, 
    :trunk => 100, 
    :urban => 50, 
    :bicycle_road => 30, 
    :walk => 5,
    :living_street => 5
)

# A dictionary of speed limits for `highway` types (in this case for germany)
maxspeedhighway = Dict(
    :rural => Dict(
        :motorway => 130, 
        :link => 80, 
        :trunk => 100, 
        :primary => 100, 
        :secondary => 100, 
        :tertiary => 100, 
        :unclassified => 100, 
        :residential => 100, 
        :living_street => 5,
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
        :living_street => 5,
        :service => 30
    )
)


"""for now we ignore special days  
outputs hour per week granularity
"""
function maxspeed(
        tags;
        urban=true, 
        maxspeedword=maxspeedword, 
        maxspeedhighway=maxspeedhighway
    )::Dict{Symbol, Union{Array, Real}}
    maxspeed = parsemaxspeed(
        tags,
        direction="both", 
        urban=urban, 
        maxspeedword=maxspeedword, 
        maxspeedhighway=maxspeedhighway 
    )
    maxspeedtagconditional = get(tags, "maxspeed:conditional", "_")
    if maxspeedtagconditional != "_"
        if maxspeed == nothing
            maxspeed = missing
        end
        maxspeed = parsemaxspeedconditional(maxspeedtagconditional, maxspeed=maxspeed)
        if length(unique(maxspeed)) == 1
            maxspeed = maxspeed[1]
        end
    end
    uvmaxspeed = parsemaxspeed(
        tags, 
        direction="forward",
        urban=urban,
        maxspeedword=maxspeedword, 
        maxspeedhighway=maxspeedhighway
    )
    vumaxspeed = parsemaxspeed(
        tags,
        direction="backward", 
        urban=urban,
        maxspeedword=maxspeedword, 
        maxspeedhighway=maxspeedhighway
    )

    out = Dict{Symbol, Union{Array, Real}}()
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


""" Parse tags which give the maxspeed of a way
"""
function parsemaxspeed(
        tags; 
        direction="both", 
        urban=true, 
        maxspeedword=maxspeedword, 
        maxspeedhighway=maxspeedhighway
    )::Union{Real, Nothing}
    # if direction is given check for directional maxspeed
    if direction == "both"
        direction = ""
    else
        direction = ":" * direction
    end
    
    for tag = ["maxspeed", "source:maxspeed", "zone:maxspeed"]
        maxspeedtag = get(tags, tag * direction, "_")
        if maxspeedtag != "_"
            maxspeed = maxspeednumber(maxspeedtag, maxspeedword=maxspeedword)
            if maxspeed != nothing

                return maxspeed
            end
        end
    end
    
    highwaytag = get(tags, "highway", "_")
    if highwaytag != "_" && length(direction) == 0
        maxspeed = highwaymaxspeenumber(highwaytag, urban, maxspeedhighway)
        if maxspeed != nothing

            return maxspeed
        end
    end

    return nothing
end


""" Parse conditional tags which give the maxspeed of a way
"""
function parsemaxspeedconditional(
        maxspeedconditional::AbstractString;
        maxspeed::Union{Real,Missing}=missing,
        maxspeedword::Dict=maxspeedword
    )
    conditions = parseconditionaltag(maxspeedconditional)
    condikeys = collect(keys(conditions))

    maxspeed = repeat(Union{Real,Missing}[maxspeed], 168)
    for c = condikeys
        condi = conditions[c]
        value = maxspeednumber(condi[:value], maxspeedword=maxspeedword)
        hours = maxspeedconditionhoursofweek(condi[:rules])
        maxspeed[hours .+ 1] .=  value
    end

    return maxspeed
end


""" Maxspeed tag as number
"""
function maxspeednumber(
        tag::AbstractString; 
        maxspeedword=maxspeedword
    )::Union{Real, Nothing}
    regexmaxspeednumber = r"(\d+)"
    number = match(regexmaxspeednumber, tag)
    if number != nothing
        number = parse(Int, number.match)
        regexmaxspeedunit = r"(km/h|kmh|kph|mph|knots)$"
        unit = match(regexmaxspeedunit, tag)
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
        wordkeys = collect(keys(maxspeedword))
        wordkeysstr = string.(wordkeys)

        regexmaxspeedword = Regex("(" * join(wordkeysstr, "|") * ")")
        word = match(regexmaxspeedword, tag)
        
        # if no matching word return nothing
        if word == nothing

            return nothing
        else 
            ki = findall(word.match .== wordkeysstr)[1]
            k = wordkeys[ki]

            return maxspeedword[k]
        end
    end
end

""" Use the highway tag to gess the maxspeed
"""
function highwaymaxspeenumber(
        tag::AbstractString, 
        urban=true, 
        maxspeedhighway=maxspeedhighway
    )::Union{Real, Nothing}
    condkey = urban ? :urban : :rural
    
    wordkeys = collect(keys(maxspeedhighway[condkey]))
    wordkeysstr = string.(wordkeys)

    regexhighway = Regex("(" * join(wordkeysstr, "|") * ")")
    word = match(regexhighway, tag)

    if word == nothing

        return nothing
    else 
        ki = findall(word.match .== wordkeysstr)[1]
        k = wordkeys[ki]

        return maxspeedhighway[condkey][k]
    end
end


""" Join rules to hours of week
"""
function maxspeedconditionhoursofweek(rules)
    ruleskeys = collect(keys(rules))

    hours = Integer[]
    # one condition with r rules
    for r = ruleskeys
        rule = rules[r]
        if rule[:words] == ["off"]
            setdiff!(hours, rule[:hoursofweek])
        elseif rule[:words] == ["signal"] || rule[:words] == ["wet"]
            # leave `hours` as is
        elseif length(rule[:words]) > 0
            @warn "A unhandel word in a conditional tag was observed." words = rule[:words]
        else
            union!(hours, rule[:hoursofweek])
        end
    end

    return hours
end
