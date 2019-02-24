""" Interpretes the oneway tags of a OSM way object. Returns an array of strings.
"""
function onewayinterpreter(way::Dict)::AbstractArray{AbstractString, 1}
    if way["type"] != "way"
        throw(ArgumentError("`way` must be an OSM way object."))
    end
    
    tags = get(way, "tags", "_")
    if tags != "_"
        oneway = get(tags, "oneway", "_")
        onewayconditional = get(tags, "oneway:conditional", "_")
        if onewayconditional != "_"
            varoneway = onewayconditionalinterpreter(onewayconditional)
            out = varoneway[:oneway]
            # ckeck if oneway and oneway:conditional match
            if !((out == ["h", "->", "<-"] && oneway == "reversible") ||
                (out == ["dh", "->", "<>"] && (oneway == "no" || oneway == "_")))
                @warn "The `oneway` and `oneway:conditional` tag are conflicting." oneway = oneway condition = out
            end
        elseif oneway == "yes"
            out =  ["->"]
        elseif oneway == "-1"
            out =  ["<-"]
        elseif oneway == "no" || oneway == "alternating"
            out = ["<>"]
        elseif oneway == "reversible" # if a street is reversible but has not condition drop it
            out = ["x"]
            # if not marked as oneway but one of the following tags is given, make as oneway
        elseif oneway == "_" && any(get(tags, "junction", "_") .== ["roundabout", "circular"])
            out = ["->"]
        elseif oneway == "_" && get(tags, "highway", "_") == "motorway"
            out = ["->"]
        elseif oneway == "_"
            out = ["<>"]
        else
            out = ["<>"]
            @warn "An unhandled oneway tag was discovered it is handled as `oneway=no`." ID=way["id"]
        end
    else
        out = ["<>"]
        @warn "A `way` object without `tags` was discovered it is handled as`oneway=no`." ID=way["id"]
    end

    return out
end


""" Interpretes the oneway:conditional part of the oneway information. Returns a dictinary.
"""
function onewayconditionalinterpreter(onewayconditional::AbstractString)::Dict
    condition = parseconditionaltag(onewayconditional)
    condikeys = collect(keys(condition))
    out = Dict()
    if length(condikeys) == 1
        # oneway or twoway
        condi1 = condition[condikeys[1]] 
        condi1keys = collect(keys(condi1))
        if length(condi1keys) == 2
            if condi1[:value] != "yes"
                @warn "A `oneway:conditional` tag containing one rule, where the value is not `yes`." value = condi1[:value]
            end
            rule = condi1[:rule1]
            out[:hoursofday] = rule[:hoursofday]
            if length(rule[:daysofweek]) > 0
                out[:daysofweek] = rule[:daysofweek]
                out[:oneway] = ["dh", "->", "<>"]
            else
                out[:oneway] = ["h", "->", "<>"]
            end
        else
            @error "Handling `oneway:conditional` with more the one rule per condition is not implemented." condition = onewayconditional
        end

    elseif length(condikeys) == 2
        # reversal oneway
        condi1 = condition[condikeys[1]] 
        condi1keys = collect(keys(condi1))
        if length(condi1keys) == 2
            if condi1[:value] != "yes"
                @warn "A `oneway:conditional` tag where the value of the first rule is not `yes`." value = condi1[:value]
            end
            out[:hoursofday1] = condi1[:rule1][:hoursofday]
        else
            @error "Handling `oneway:conditional` with more the one rule per condition is not implemented." condition = onewayconditional
        end
        condi2 = condition[condikeys[2]] 
        condi2keys = collect(keys(condi2))
        if length(condi2keys) == 2
            if condi2[:value] != "-1"
                @warn "A `oneway:conditional` tag where the value of the second rule is not `-1`." value = condi1[:value]
            end
            out[:hoursofday2] = condi2[:rule1][:hoursofday]
        else
            @error "Handling `oneway:conditional` with more the one rule per condition is not implemented." condition = onewayconditional
        end
        if length(Set([out[:hoursofday1]; out[:hoursofday2]])) == 24
            out[:oneway] = ["h", "->", "<-"] 
        else
            @warn "It is expected that a reversible oneway tags covers 24 hours, which is not the case here." condition = onewayconditional
        end
    end
    return out

end
