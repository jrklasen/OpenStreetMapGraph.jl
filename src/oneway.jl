const DirectionalDict = Dict{Symbol,Union{Real,Missing,Array{Union{Real,Missing},1}}}


""" Interpretes the oneway tags of a OSM way object. Returns an Dict.
"""
function oneway(tags::Dict)::Dict
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
        out = Dict{Symbol, Array}(
            :uv => [],
            :vu => []
        )
    
    # oneway streets
    elseif oneway == "yes"
        out = Dict{Symbol, Array}(
            :uv => []
        )
    elseif oneway == "-1"
        out = Dict{Symbol, Array}(
            :vu => []
        )
    elseif oneway == "reversible"
        out = Dict{Symbol, Array}()
        @warn "A `way` with a `reversible` tag but without a `oneway:conditional` tag was discovered, it is ignored." tags=tags
    
    # if not marked as oneway but taged in the following way, it is a oneway too.
    elseif oneway == "_" && any(get(tags, "junction", "_") .== ["roundabout", "circular"])
        out = Dict{Symbol, Array}(
            :uv => []
        )
    elseif oneway == "_" && get(tags, "highway", "_") == "motorway"
        out = Dict{Symbol, Array}(
            :uv => []
        )
    elseif oneway == "_"
        out = Dict{Symbol, Array}(
            :uv => [],
            :vu => []
        )
    else
        out = Dict{Symbol, Array}()
        @warn "An unhandled oneway tag was discovered, the according way is ignored." tags=tags
    end

    return out
end


""" Interpretes the oneway:conditional part of the oneway information. Returns a dictinary.
"""
function parseonewayconditional(
        onewayconditional::AbstractString
    )::Dict
    condition = parseconditionaltag(onewayconditional)
    condikeys = collect(keys(condition))

    uvindex = UInt8[]
    vuindex = UInt8[]
    for ck = condikeys
        if length(collect(keys(condition[ck][:rules]))) > 1
            @error "Handling `oneway:conditional` with more the one rule per condition is not implemented." condition = onewayconditional
        end
        value = condition[ck][:value]
        rule = condition[ck][:rules][:rule1]

        if value != "yes"
            union!(uvindex,  rule[:hoursofweek])
        elseif value != "-1"
            union!(vuindex,  rule[:hoursofweek])
        else
            @error "`one way:conditional` tags with following value, are not supported." value = value
        end

    end

    out = Dict{Symbol, Array}(
        :uv => uvindex,
        :vu => vuindex 
    )

    return out
end

