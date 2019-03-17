const OnewayDict = Dict{Symbol,Union{Real,Missing,Array{Union{Real,Missing},1}}}


""" Interpretes the oneway tags of a OSM way object. Returns an array of strings.
"""
function oneway(way::Dict)::Dict
    if way["type"] != "way"
        throw(ArgumentError("`way` must be an OSM way object."))
    end
    
    tags = get(way, "tags", "_")
    if tags != "_"
        oneway = get(tags, "oneway", "_")
         onewayconditional = get(tags, "oneway:conditional", "_")
        if onewayconditional != "_"
            # interpret conditional oneway tag
            out = parseonewayconditional(onewayconditional)
            # ckeck if oneway and oneway:conditional match
            if !(oneway == "reversible" || (oneway == "no" || oneway == "_"))
                @warn "The `oneway` and `oneway:conditional` tag are conflicting." oneway = oneway condition = out
            end

        # common streets
        elseif oneway == "no" || oneway == "alternating"
            out = Dict{Symbol, Dict}(:uv => OnewayDict(:weight => missing),
                                     :vu => OnewayDict(:weight => missing) )

        # oneway streets
        elseif oneway == "yes"
            out = Dict{Symbol, Dict}(:uv => OnewayDict(:weight => missing) )
        elseif oneway == "-1"
            out = Dict{Symbol, Dict}(:vu => OnewayDict(:weight => missing) )
        elseif oneway == "reversible"
            out = Dict{Symbol, Dict}()
            @warn "A `way` with a `reversible` tag but without a `oneway:conditional` tag was discovered, it is ignored." ID=way["id"]
        
        # if not marked as oneway but one of the following tags is given, it is oneway
        elseif oneway == "_" && any(get(tags, "junction", "_") .== ["roundabout", "circular"])
            out = Dict{Symbol, Dict}(:uv => OnewayDict(:weight => missing) )
        elseif oneway == "_" && get(tags, "highway", "_") == "motorway"
            out = Dict{Symbol, Dict}(:uv => OnewayDict(:weight => missing) )
        elseif oneway == "_"
            out = Dict{Symbol, Dict}(:uv => OnewayDict(:weight => missing),
                                     :vu => OnewayDict(:weight => missing) )
        
        else
            out = Dict{Symbol, Dict}()
            @warn "An unhandled oneway tag was discovered therefore the according way is ignored." ID=way["id"]
        end
    
    else
        out = Dict{Symbol, Dict}()
        @warn "A `way` object without `tags` is discovered it is ignored." ID=way["id"]
    end

    return out
end


""" Interpretes the oneway:conditional part of the oneway information. Returns a dictinary.
"""
function parseonewayconditional(onewayconditional::AbstractString)::Dict
    condition = parseconditionaltag(onewayconditional)
    condikeys = collect(keys(condition))
    if length(condikeys) == 1
        # conditional switch between oneway and twoway
        condi = condition[condikeys[1]] 
        ruleskeys = collect(keys(condi1[:rules]))
        if length(ruleskeys) == 1
            value = condi[:value]
            rule = condi[:rules][:rule1]
            if value != "yes"
                @error "A `oneway:conditional` tag is containing one rule and the value is not `yes`." value = value
            end
            uvweight = missing
            vuweight = repeat(Union{Real,Missing}[missing], 168)
            vuweight[hoursofweek(rule[:hoursofday], rule[:daysofweek]) .+ 1] .= Inf
        else
            @error "Handling `oneway:conditional` with more the one rule per condition is not implemented." condition = onewayconditional
        end

    elseif length(condikeys) == 2
        # conditional switch between oneway dirctions

        condi1 = condition[condikeys[1]] 
        ruleskeys1 = collect(keys(condi1[:rules]))
        uvweight = repeat(Union{Real,Missing}[Inf], 168)
        if length(ruleskeys1) == 1
            value1 = condi1[:value]
            rule1 = condi1[:rule1]
            if value1 != "yes"
                @error "A `oneway:conditional` tag where the value of the first rule is not `yes`." value = value1
            end
            uvweight[hoursofweek(rule1[:daysofweek], rule1[:hoursofday]) .+ 1] .= missing
        else
            @error "Handling `oneway:conditional` with more the one rule per condition is not implemented." condition = onewayconditional
        end

        condi2 = condition[condikeys[2]]
        ruleskeys2 = collect(keys(condi1[:rules]))
        vuweight = repeat(Union{Real,Missing}[Inf], 168)
        if length(ruleskeys2) == 1
            value2 = condi2[:value]
            rules2 = condi2[:rule1]
            if valie2 != "-1"
                @error "A `oneway:conditional` tag where the value of the second rule is not `-1`." value = value2
            end
            vuweight[hoursofweek(rules2[:daysofweek], rules2[:hoursofday]) .+ 1] .= missing
        else
            @error "Handling `oneway:conditional` with more the one rule per condition is not implemented." condition = onewayconditional
        end
    end
    out = Dict{Symbol, Dict}(:uv => OnewayDict(:weight => uvweight),
                             :vu => OnewayDict(:weight => vuweight) )

    return out
end

