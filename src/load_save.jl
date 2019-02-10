# Good starting points for OSM overpass are:
# https://wiki.openstreetmap.org/wiki/Overpass_API/Language_Guide
# https://wiki.openstreetmap.org/wiki/Map_Features

"""
Generate a Overpass QL query.

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
                       queryname::String = "cardrive", timeout::Integer = 600, output::String = "json")::String
    bbox = (latitudesouth, longitudewest, latitudenorth, longitudeeast)
    
    if queryname === "cardrive" # a overpass query optimized for car routing
        query = """
        [out:$output][timeout:$timeout];
        (
            way["highway"]
                ["area"!~"yes"]
                ["highway"!~"cycleway|footway|path|pedestrian|steps|track|corridor|
                  proposed|construction|bridleway|abandoned|platform|raceway|service"]
                ["motor_vehicle"!~"no|privat|delivery|destination|customers|agricultural|forestry"]
                ["motorcar"!~"no|privat|designated|delivery|destination|customers|agricultural|forestry"]
                ["vehicle"!~"no|privat|designated|delivery|destination|customers|agricultural|forestry"]
                ["access"!~"no|privat|designated|delivery|destination|customers|agricultural|forestry"]
                $bbox;
            way["highway"]
                ["service"~"parking|parking_aisle"]
                $bbox;
            relation["restriction"]$bbox;
            relation["restriction:motor_vehicle"]$bbox;
            relation["restriction:motorcar"]$bbox;
            relation["restriction:vehicle"]$bbox;
            relation["restriction:conditional"]$bbox;
            relation["restriction:motor_vehicle:conditional"]$bbox;
            relation["restriction:motorcar:conditional"]$bbox;
            relation["restriction:vehicle:conditional"]$bbox;
        );
        (._;>;);
        out body;
        """
            # relation[~"^restriction.*\$"~"."]$bbox;
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