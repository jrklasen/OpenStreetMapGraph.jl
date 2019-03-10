""" Interpretes the oneway tags of a OSM way object. Returns an array of strings.
"""
function onewayinterpreter(way::Dict)::AbstractArray{AbstractString, 1}
    if way["type"] != "way"
        throw(ArgumentError("`way` must be an OSM way object."))
    end
    
    tags = get(way, "tags", "_")
    if tags != "_"
        oneway = get(tags, "oneway", "_")
        # interpret conditional oneway tag
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
        elseif oneway == "reversible" # if a street is reversible but has no condition, drop it
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
        # conditional switch between oneway and twoway
        condi1 = condition[condikeys[1]] 
        condi1keys = collect(keys(condi1))
        if length(condi1keys) == 2
            if condi1[:value] != "yes"
                @error "A `oneway:conditional` tag is containing one rule and the value is not `yes`." value = condi1[:value]
            end
            uvweight = missing
            vuweight = repeat(Union{Real,Missing}[missing], 168)
            vuweight[hoursofweek(condi1[:rule1][:daysofweek], condi1[:rule1][:hoursofday]) .+ 1] .= Inf
            #out[:hoursofday] = rule[:hoursofday]
            #if length(rule[:daysofweek]) > 0
                #out[:vu][:condition1][:daysofweek] = rule[:daysofweek]
                # out[:daysofweek] = rule[:daysofweek]
                # out[:oneway] = ["dh", "->", "<>"]
            # else
            #     out[:oneway] = ["h", "->", "<>"]
            #end
        else
            @error "Handling `oneway:conditional` with more the one rule per condition is not implemented." condition = onewayconditional
        end

    elseif length(condikeys) == 2
        # reversal oneway
        condi1 = condition[condikeys[1]] 
        condi1keys = collect(keys(condi1))
        uvweight = repeat(Union{Real,Missing}[Inf], 168)
        if length(condi1keys) == 2
            if condi1[:value] != "yes"
                @error "A `oneway:conditional` tag where the value of the first rule is not `yes`." value = condi1[:value]
            end
            uvweight[hoursofweek(condi1[:rule1][:daysofweek], condi1[:rule1][:hoursofday]) .+ 1] .= 12#missing
            # out[:hoursofday1] = condi1[:rule1][:hoursofday]
        else
            @error "Handling `oneway:conditional` with more the one rule per condition is not implemented." condition = onewayconditional
        end

        condi2 = condition[condikeys[2]] 
        condi2keys = collect(keys(condi2))
        vuweight = repeat(Union{Real,Missing}[Inf], 168)
        if length(condi2keys) == 2
            if condi2[:value] != "-1"
                @error "A `oneway:conditional` tag where the value of the second rule is not `-1`." value = condi1[:value]
            end
            vuweight[hoursofweek(condi2[:rule1][:daysofweek], condi2[:rule1][:hoursofday]) .+ 1] .= 11#missing
            # out[:hoursofday2] = condi2[:rule1][:hoursofday]
        else
            @error "Handling `oneway:conditional` with more the one rule per condition is not implemented." condition = onewayconditional
        end
        # if length(Set([out[:hoursofday1]; out[:hoursofday2]])) == 24
        #     out[:oneway] = ["h", "->", "<-"] 
        # else
        #     @warn "It is expected that a reversible oneway tags covers 24 hours, which is not the case here." condition = onewayconditional
        # end
    end
    out = Dict{Symbol, Dict}(
        :uv => Dict{Symbol,Union{Real,Missing,Array{Union{Real,Missing},1}}}(
            :weight => uvweight),
        :vu => Dict{Symbol,Union{Real,Missing,Array{Union{Real,Missing},1}}}(
            :weight => vuweight) )
    return out

end


function hoursofweek(days::Array{<:Integer,1}=Integer[], hours::Array{<:Integer,1}=Integer[])::Array{UInt8,1}
    nd = length(days)
    nh = length(hours)
    
    if nd == 0
        days = collect(UInt8, 1:7)
        nd = length(days)
    end
    daysashours = (days .- 1) .* 24
    
    if nh == 0
        hours = collect(UInt8, 0:23)
        nh = length(hours)
    end
    
    # hours per day
    out = reshape((daysashours' .+ hours), nd * nh)

    return out
end


function inversehoursofweek(hours::Array{<:Integer,1}=Integer[])::Array{UInt8,1}
    return setdiff(hoursofweek(), hours)
end
