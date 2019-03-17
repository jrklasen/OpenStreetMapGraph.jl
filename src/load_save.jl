# Good starting points for OSM overpass are:
# https://wiki.openstreetmap.org/wiki/Overpass_API/Language_Guide
# https://wiki.openstreetmap.org/wiki/Map_Features

"""
Generate a Overpass QL query. See:
https://wiki.openstreetmap.org/wiki/Overpass_API/Overpass_QL


# Arguments
- `latitudenorth::Float64`: The northern boundary of the region to query.
- `longitudeeast::Float64`: The eastern boundary of the region to query.
- `latitudesouth::Float64`: The southern boundary of the region to query.
- `longitudewest::Float64`: The western boundary of the region to query.
- `queryname::String = "cardrive"`: Specifeis the query content, so far only "cardrive" implemented.
- `timeout::Integer = 600`: Overpass timeout.
- `output::String = "json"`: Overpass output format, so far only "json" implemented.
"""
function overpassquery(latitudesouth::Float64, longitudewest::Float64, latitudenorth::Float64, longitudeeast::Float64;
                       queryname::String="cardrive", timeout::Integer=600, output::String = "json")::String
    
    if queryname === "cardrive" # a overpass query optimized for car routing
        query = """
        [out:$output]
        [timeout:$timeout]
        [bbox:$latitudesouth,$longitudewest,$latitudenorth,$longitudeeast];
        (
            way["highway"]
                ["area"!~"yes"]
                ["highway"!~"cycleway|footway|path|pedestrian|steps|track|corridor|
                    proposed|construction|bridleway|abandoned|platform|raceway|service"]
                ["motor_vehicle"!~"no|privat|delivery|destination|customers|agricultural|forestry"]
                ["motorcar"!~"no|privat|designated|delivery|destination|customers|agricultural|forestry"]
                ["vehicle"!~"no|privat|designated|delivery|destination|customers|agricultural|forestry"]
                ["access"!~"no|privat|designated|delivery|destination|customers|agricultural|forestry"];
            way["highway"]
                ["service"~"parking|parking_aisle"];
        )->.streets_network;
        (
            rel(bw)["restriction"];
            rel(bw)["restriction:motor_vehicle"];
            rel(bw)["restriction:motorcar"];
            rel(bw)["restriction:vehicle"];
            rel(bw)["restriction:conditional"];
            rel(bw)["restriction:motor_vehicle:conditional"];
            rel(bw)["restriction:motorcar:conditional"];
            rel(bw)["restriction:vehicle:conditional"];
        )->.turn_restrictions;
        ((.streets_network; .turn_restrictions;);>;);
        out body;
        """
    else
        query = ""
        @warn "Not yet implemented"
    end

    return query
end

"""
Query OSM data using Overpass QL.

# Arguments
- `query::String`: A Overpass QL query. See also: [`overpassquery`](@ref).
"""
function overpass(query::String)::Dict
    if !occursin("[out:json]", query)
        error("Use '[out:json]' as output flag, other formats are not yet implemented")
    end
    str =  String(HTTP.get("https://overpass-api.de/api/interpreter", body=query).body)
    data = JSON.parse(str)
    
    return data
end