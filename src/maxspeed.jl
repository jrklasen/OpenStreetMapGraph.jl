maxspeedword = Dict(:none=>130, 
                    :motorway=>130, 
                    :signals=>nothing, # nothing is replased by highway 
                    :rural=>100, 
                    :trunk=>100, 
                    :urban=>50, 
                    :bicycle_road=>30, 
                    :walk=>7)

# a list of maxspeeds for highway types (in this case for germany)
highwaymaxspeed = Dict(:rural=>Dict(:motorway=>130, 
                                    :link=>80, 
                                    :trunk=>100, 
                                    :primary=>100, 
                                    :secondary=>100, 
                                    :tertiary=>100, 
                                    :unclassified=>100, 
                                    :residential=>100, 
                                    :living_street=>7,
                                    :service=>30),
                       :urban=>Dict(:motorway=>130, 
                                    :link=>80, 
                                    :trunk=>50, 
                                    :primary=>50, 
                                    :secondary=>50, 
                                    :tertiary=>50, 
                                    :unclassified=>50, 
                                    :residential=>50, 
                                    :living_street=>7,
                                    :service=>30))

function maxspeedinterpreter(waytags, maxspeedword=maxspeedword, urban=true, highwaymaxspeed=highwaymaxspeed)
    
    out = Dict{Symbol, Union{Dict, Integer}}()
    maxspeedtagconditional = get(waytags, "maxspeed:conditional", "_")
    if maxspeedtagconditional != "_"
        out[:condition] = maxspeedconditionalinterpreter(maxspeedtagconditional)
    end
    maxspeedforward = parsemaxspeedkes(waytags, maxspeedword, "forward", urban, highwaymaxspeed)
    maxspeedbackward = parsemaxspeedkes(waytags, maxspeedword, "backward", urban, highwaymaxspeed)
    maxspeed = parsemaxspeedkes(waytags, maxspeedword, "both", urban, highwaymaxspeed)
    if maxspeedforward != nothing
        out[:maxspeedforward] = maxspeedforward
    end
    if maxspeedbackward != nothing
        out[:maxspeedbackward] = maxspeedbackward
    end
    if maxspeed != nothing
        out[:maxspeed] = maxspeed
    end

    return out
end


"""
"""
function maxspeedconditionalinterpreter(maxspeedconditional::AbstractString, maxspeedword::Dict=maxspeedword)
    condition = parseconditionaltag(maxspeedconditional)
    condikeys = collect(keys(condition))
    out = Dict{Symbol, Union{AbstractArray, Integer}}()
    if length(condikeys) == 1
        # oneway or twoway
        condi1 = condition[condikeys[1]] 
        condi1keys = collect(keys(condi1))
        value = parsemaxspeed(condi1[:value], maxspeedword)
        if length(condi1keys) == 2
            rule = condi1[:rule1]
            if length(rule[:hoursofday]) > 0 && length(rule[:daysofweek]) > 0 
                out[:hoursofday] = rule[:hoursofday]
                out[:daysofweek] = rule[:daysofweek]
                out[:maxspeed] = value
            elseif length(rule[:daysofweek]) > 0
                out[:daysofweek] = rule[:daysofweek]
                out[:maxspeed] = value
            elseif length(rule[:hoursofday]) > 0
                out[:hoursofday] = rule[:hoursofday]
                out[:maxspeed] = value
            end
        elseif length(condi1keys) == 3
            # for now we ignore special days 
            rule1 = condi1[:rule1]
            rule2 = condi1[:rule2]
            if rule2[:words] == ["off"]
                days = rule2[:daysofweek]
                if length(days) > 0
                    inversedays = sort(collect(setdiff(Set(1:7), Set(days))))
                    if length(rule1[:hoursofday]) > 0
                        out[:hoursofday] = rule1[:hoursofday]
                        out[:daysofweek] = inversedays
                        out[:maxspeed] = value
                    end
                else
                    if length(rule1[:hoursofday]) > 0 && length(rule1[:daysofweek]) > 0 
                        out[:hoursofday] = rule[:hoursofday]
                        out[:daysofweek] = rule[:daysofweek]
                        out[:maxspeed] = value
                    elseif length(rule1[:daysofweek]) > 0
                        out[:daysofweek] = rule1[:daysofweek]
                        out[:maxspeed] = value
                    elseif length(rule1[:hoursofday]) > 0
                        out[:daysofweek] = rule1[:daysofweek]
                        out[:maxspeed] = value
                    end
                end
            else
                @warn "A `maxspeed:conditional` tag containing the following word which cannot yet been parsed." word = rule2[:words]
            end
        else
            @warn "A `maxspedd:conditional` tag containing more than 2 rules, cant be handelt yet." condition = condi1
        end
    elseif length(condikeys) == 2
        # reversal oneway
                # oneway or twoway
        condi1 = condition[condikeys[1]] 
        condi1keys = collect(keys(condi1))
        value1 = parsemaxspeed(condi1[:value], maxspeedword)
        if length(condi1keys) == 2
            rule1 = condi1[:rule1]
            if length(rule1[:hoursofday]) > 0 && length(rule1[:daysofweek]) > 0 
                out[:hoursofday1] = rule1[:hoursofday]
                out[:daysofweek1] = rule1[:daysofweek]
                out[:maxspeed1] = value1
            elseif length(rule1[:daysofweek]) > 0
                out[:daysofweek1] = rule1[:daysofweek]
                out[:maxspeed1] = value1
            elseif length(rule1[:hoursofday]) > 0
                out[:daysofweek1] = rule1[:daysofweek]
                out[:maxspeed1] = value1
            end
        else
            @error "Handling `maxspeed:conditional` tow conition and more the one rule per condition is not implemented." condition = condi1
        end
        condi2 = condition[condikeys[2]] 
        condi2keys = collect(keys(condi2))
        value2 = parsemaxspeed(condi1[:value], maxspeedword)
        if length(condi2keys) == 2
            rule2 = condi2[:rule2]
            if length(rule2[:hoursofday]) > 0 && length(rule2[:daysofweek]) > 0 
                out[:hoursofday2] = rule2[:hoursofday]
                out[:daysofweek2] = rule2[:daysofweek]
                out[:maxspeed2] = value2
            elseif length(rule2[:daysofweek]) > 0
                out[:daysofweek2] = rule2[:daysofweek]
                out[:maxspeed2] = value2
            elseif length(rule2[:hoursofday]) > 0
                out[:daysofweek2] = rule2[:daysofweek]
                out[:maxspeed2] = value2
            end
        else
            @error "Handling `maxspeed:conditional` tow conition and more the one rule per condition is not implemented." condition = condi2
        end
    end
    return out

end

""" Search for  tags which give the maxspeed of a way
"""
function parsemaxspeedkes(waytags, maxspeedword=maxspeedword, direction="both", urban=true, highwaymaxspeed=highwaymaxspeed)
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
function parsemaxspeed(token::AbstractString, maxspeedword=maxspeedword)
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
        regexmaxspeedword = r"(none|no|motorway|signals|trunk|rural|urban|bicycle_road|walk|living_street)"
        word = match(regexmaxspeedword, token)
        if word.match == "none" || word.match == "no"
            return maxspeedword[:none]
        elseif word.match == "motorway"
            return maxspeedword[:motorway]
        elseif word.match == "signals"
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
function parsehighwaymaxspeed(token::AbstractString, urban=true, highwaymaxspeed=highwaymaxspeed)
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
