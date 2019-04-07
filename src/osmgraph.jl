# TAGS = Set([# https://wiki.openstreetmap.org/wiki/Key:name
#             "name",
#             # https://wiki.openstreetmap.org/wiki/Key:highway
#             "highway", 
#             # https://wiki.openstreetmap.org/wiki/Key:oneway
#             # https://wiki.openstreetmap.org/wiki/Key:junction
#             "oneway", "oneway:conditional", "junction", # junction=roundabout, highway=motorway
#             # https://wiki.openstreetmap.org/wiki/Key:access
#             "access", "access:conditional", 
#             # https://wiki.openstreetmap.org/wiki/Key:maxspeed
#             # rmaxspeed = r"^([^ ]+?)(?:[ ]?(?:km/h|kmh|kph|mph|knots))?$"
#             "maxspeed", "maxspeed:backward", "maxspeed:conditional", "maxspeed:practical:conditional", "maxspeed:variable",
#             # https://wiki.openstreetmap.org/wiki/Key:turn
#             "turn", "turn:forward", "turn:lanes", "turn:lanes:both_ways",
#             # https://wiki.openstreetmap.org/wiki/Key:construction
#             "construction", 
#             # https://wiki.openstreetmap.org/wiki/Key:service
#             "service",
#             # https://wiki.openstreetmap.org/wiki/Key:lanes
#             "lanes", 
#             # https://wiki.openstreetmap.org/wiki/Key:surface
#             "surface", 
#             "bridge", "tunnel"])

# # https://wiki.openstreetmap.org/wiki/Relation:restriction
# TURN_RESTRICTION = ["no_right_turn", "no_left_turn", "no_u_turn", "no_straight_on", 
#                     "only_right_turn", "only_left_turn", "only_straight_on", "no_entry", "no_exit"] 

function osmgraph(
        osmdata::Dict
    )
    # find number of nodes in OSM data
    nnodes = 0
    for elem in osmdata["elements"]
        type = get(elem, "type", "_")
        if type == "node"
            nnodes += 1
        end
    end
    # creat graph (default weight is Inf)
    graph = MetaGraphs.MetaDiGraph(nnodes, 0.0)

    # a dict which maps graph-indeces to the according OSM-ids
    nodeidmap = Dict{Integer, Integer}()
    c = 1
    for elem = osmdata["elements"]
        if elem["type"] == "node"
            # add meta data to nodes
            MetaGraphs.set_props!(graph, c, 
                Dict(
                    :id => elem["id"],
                    :coordinates => Geodesy.LLA(elem["lat"], elem["lon"], 0.0)
                )
            )
            nodeidmap[elem["id"]] = c
            c += 1
        end
    end

    # add edge and edge meta data
    for elem = osmdata["elements"]
        type = get(elem, "type", "_")
        if type == "way"

            directional = osmway(elem)
            dikeys = keys(directional)

            # all nodes which are conected by the way, can be more then two
            osmnodeids = get(elem, "nodes", "_")
            osmwayid = get(elem, "id", "_")

            if osmnodeids != "_"
                nodeids = [nodeidmap[i] for i = osmnodeids]
                
                for (u, v) = zip(nodeids[1:(end-1)], nodeids[2:end])
                    dist = Geodesy.distance(
                        MetaGraphs.props(graph, u)[:coordinates],
                        MetaGraphs.props(graph, v)[:coordinates]
                    )

                    if any(dikeys .== :uv)
                        MetaGraphs.add_edge!(graph, u, v)
                        ms = get(directional[:uv], :maxspeed, -1)
                        MetaGraphs.set_prop!(graph, u, v, :id, osmwayid)
                        MetaGraphs.set_prop!(graph, u, v, :maxspeed, ms)
                        MetaGraphs.set_prop!(graph, u, v, :distance, dist)
                        MetaGraphs.set_prop!(graph, u, v, :weight, dist ./ (ms .* 1000 ./ 3600)) # make the array thing working us one elemet, cleanup the missing stuff!!!!!!
                    elseif any(dikeys .== :vu)
                        MetaGraphs.add_edge!(graph, v, u)
                        ms = directional[:vu][:maxspeed]
                        MetaGraphs.set_prop!(graph, v, u, :id, osmwayid)
                        MetaGraphs.set_prop!(graph, v, u, :maxspeed, ms)
                        MetaGraphs.set_prop!(graph, v, u, :distance, dist)
                        MetaGraphs.set_prop!(graph, v, u, :weight, dist ./ (ms .* 1000 ./ 3600))
                    end
                end
            end
        end
    end

    return graph
end


function osmway(
        way::Dict
    )::Dict{Symbol,Dict}
    if way["type"] != "way"
        throw(ArgumentError("`way` must be an OSM way object."))
    end
    out = Dict{Symbol,Dict}()

    tags = get(way, "tags", "_")
    if tags != "_"
        # directional
        directional = oneway(tags)
        directkeys = collect(keys(directional))

        # u -> v
        isuv = any(:uv .== directkeys)
        # v -> u
        isvu = any(:vu .== directkeys)
        
        # maxspeed
        msdict = maxspeed(tags, urban=true)
        uvms = get(msdict, :uvmaxspeed, 0)
        vums = get(msdict, :vumaxspeed, 0)
        ms = get(msdict, :maxspeed, 0)

        # u -> v direction
        if isuv 
            if uvms == 0 && sum(ms) > 0
                uvms = ms
            end
            # if vu exists and is a vector of indices, assign zero maxspeed at this positions, 
            # in order to block the way
            if  isvu && length(directional[:vu]) > 0 
                if length(uvms) == 1
                    uvms = repeat([uvms], 168)
                    uvms[directional[:vu] .+ 1] .= 0
                elseif length(uvms) > 1
                    uvms[directional[:vu] .+ 1] .= 0
                end
            end
            if sum(uvms) > 0
                out[:uv] = Dict(:maxspeed => uvms)
            end
        end
        # v -> u direction
        if isvu 
            if vums == 0 && sum(ms) > 0
                vums = ms
            end
            # if u -> v exists and is a vector of indices, assign zero maxspeed at this positions, 
            # in order to block the way
            if isuv && length(directional[:uv]) > 0
                if length(vums) == 1
                    vums = repeat([vums], 168)
                    vums[directional[:uv] .+ 1] .= 0
                elseif length(uvms) > 1
                    vums[directional[:uv] .+ 1] .= 0
                end
            end
            if sum(vums) > 0 
                out[:vu] = Dict(:maxspeed => vums)
            end
        end
    end

    return out
end