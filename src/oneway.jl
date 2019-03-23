const OnewayDict = Dict{Symbol,Union{Real,Missing,Array{Union{Real,Missing},1}}}


""" Interpretes the oneway tags of a OSM way object. Returns an array of strings.
"""
function oneway(way::Dict)::Dict
    if way["type"] != "way"
        throw(ArgumentError("`way` must be an OSM way object.") )
    end
    
    tags = get(way, "tags", "_")
    if tags != "_"
        oneway = get(tags, "oneway", "_")
         onewayconditional = get(tags, "oneway:conditional", "_")
        if onewayconditional != "_"
            # interpret conditional oneway tag
            out = parseonewayconditional(onewayconditional)
            # ckeck if oneway and oneway:conditional match
            if !(oneway == "reversible" || (oneway == "no" || oneway == "_") )
                @warn "The `oneway` and `oneway:conditional` tag are conflicting." oneway = oneway condition = out
            end

        # common streets
        elseif oneway == "no" || oneway == "alternating"
            out = Dict{Symbol, Dict}(:uv => OnewayDict(:weight => missing),
                                     :vu => OnewayDict(:weight => missing) )

        # oneway streets
        elseif oneway == "yes"
            out = Dict{Symbol, Dict}(:uv => OnewayDict(:weight => missing))
        elseif oneway == "-1"
            out = Dict{Symbol, Dict}(:vu => OnewayDict(:weight => missing))
        elseif oneway == "reversible"
            out = Dict{Symbol, Dict}()
            @warn "A `way` with a `reversible` tag but without a `oneway:conditional` tag was discovered, it is ignored." ID=way["id"]
        
        # if not marked as oneway but one of the following tags is given, it is oneway
        elseif oneway == "_" && any(get(tags, "junction", "_") .== ["roundabout", "circular"])
            out = Dict{Symbol, Dict}(:uv => OnewayDict(:weight => missing))
        elseif oneway == "_" && get(tags, "highway", "_") == "motorway"
            out = Dict{Symbol, Dict}(:uv => OnewayDict(:weight => missing))
        elseif oneway == "_"
            out = Dict{Symbol, Dict}(:uv => OnewayDict(:weight => missing),
                                     :vu => OnewayDict(:weight => missing))
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
    for ck = condikeys
        if length(collect(keys(condition[ck][:rules]))) > 1
            @error "Handling `oneway:conditional` with more the one rule per condition is not implemented." condition = onewayconditional
        end
        value = condition[ck][:value]
        rule = condition[ck][:rules][:rule1]
        
        uvweight = repeat(Union{Real,Missing}[missing], 168)
        vuweight = repeat(Union{Real,Missing}[missing], 168)
        if value != "yes"
            vuweight[rule[:hoursofweek] .+ 1] .= Inf
        elseif value != "-1"
            uvweight[rule[:hoursofweek] .+ 1] .= Inf
        else
            @error "`one way:conditional` tags with following value, are not supported." value = value
        end

    end
    if all(uvweight .=== missing)
        uvweight = missing
    elseif all(uvweight .=== Inf)
        uweight = Inf
    end
    if all(vuweight .=== missing)
        vuweight = missing
    elseif all(vuweight .=== Inf)
        vuweight = Inf
    end
    out = Dict{Symbol, Dict}(:uv => OnewayDict(:weight => uvweight),
                             :vu => OnewayDict(:weight => vuweight) )

    return out
end

