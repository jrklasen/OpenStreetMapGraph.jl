function osmgraph(osmdata)
    # find number of nodes in OSM data
    nnodes = 0
    for elem in osmdata["elements"]
        if elem["type"] == "node"
            nnodes += 1
        end
    end
    # creat graph (default weight is Inf)
    graph = MetaGraphs.MetaDiGraph(nnodes, Inf)
    # a dict which maps graph-indeces to the according OSM-ids
    nodeids = Dict{Integer, Integer}()
    # add meta data to nodes
    c = 1
    for elem = osmdata["elements"]
        if elem["type"] == "node"
            MetaGraphs.set_props!(graph, c, Dict(:id => elem["id"],
                                                 :lon => elem["lon"],
                                                 :lat => elem["lat"]))
            nodeids[elem["id"]] = c
            c += 1
        end
    end
    # add edges and edge meta data
    for elem = data["elements"]
        if elem["type"] == "way"
            di = onewayinterpreter(elem)
            nid = get(tags, "nodes", "_")
            if nodes != "_"
                nodes = [nodeids[i] for i = nid]
                if nodes != "_" && di = "<>"
                    for u, v = zip(nodes[1:(end-1)], nodes[2:end])
                        add_edge!(graph, u, v)
                        #set_prop!(graph, u, v, :weight)
                        add_edge!(graph, v, u)
                        #set_prop!(graph, v, u, :weight)
                    end
                elseif nodes != "_" && di = "->"
                    for u, v = zip(nodes[1:(end-1)], nodes[2:end])
                        add_edge!(graph, u, v)
                        #set_prop!(graph, u, v, :weight)
                    end
                elseif nodes != "_" && di = "<-"
                    for u, v = zip(nodes[1:(end-1)], nodes[2:end])
                        add_edge!(graph, v, u)
                        #set_prop!(graph, v, u, :weight)
                    end
                elseif nodes != "_" && di = ["h", "->", "<-"]
                    for u, v = zip(nodes[1:(end-1)], nodes[2:end])
                        add_edge!(graph, u, v)
                        #set_prop!(graph, u, v, :weight)  #todo: at time condition
                        #set_prop!(graph, u, v, :condition)
                        add_edge!(graph, v, v)
                        #set_prop!(graph, , 2, :weight)
                        #set_prop!(graph, u, v, :condition)
                    end
                end
           end
        end
    end
 


    return graph, nodeids
end

TAGS = Set([# https://wiki.openstreetmap.org/wiki/Key:name
            "name",
            # https://wiki.openstreetmap.org/wiki/Key:highway
            "highway", 
            # https://wiki.openstreetmap.org/wiki/Key:oneway
            # https://wiki.openstreetmap.org/wiki/Key:junction
            "oneway", "oneway:conditional", "junction", # junction=roundabout, highway=motorway
            # https://wiki.openstreetmap.org/wiki/Key:access
            "access", "access:conditional", 
            # https://wiki.openstreetmap.org/wiki/Key:maxspeed
            # rmaxspeed = r"^([^ ]+?)(?:[ ]?(?:km/h|kmh|kph|mph|knots))?$"
            "maxspeed", "maxspeed:backward", "maxspeed:conditional", "maxspeed:practical:conditional", "maxspeed:variable",
            # https://wiki.openstreetmap.org/wiki/Key:turn
            "turn", "turn:forward", "turn:lanes", "turn:lanes:both_ways",
            # https://wiki.openstreetmap.org/wiki/Key:construction
            "construction", 
            # https://wiki.openstreetmap.org/wiki/Key:service
            "service",
            # https://wiki.openstreetmap.org/wiki/Key:lanes
            "lanes", 
            # https://wiki.openstreetmap.org/wiki/Key:surface
            "surface", 
            "bridge", "tunnel"])
        
function refineways(osmdata)
    
    allways = Dict{String,Dict}()
    
    for elem in osmdata["elements"]
        if elem["type"] == "way"
            allways[string(elem["id"])] = Dict{String, Any}("nodes" => [string(i) for i in elem["nodes"]])
            tags = get(elem, "tags", "_")
            if tags != "_"
                for t in intersect(keys(tags), TAGS)
                    allways[string(elem["id"])][t] = tags[t]
                end
            end
        end
        
    end

    return allways
end

# https://wiki.openstreetmap.org/wiki/Relation:restriction
TURN_RESTRICTION = ["no_right_turn", "no_left_turn", "no_u_turn", "no_straight_on", 
                    "only_right_turn", "only_left_turn", "only_straight_on", "no_entry", "no_exit"] 
function refinerelations(osmdata)
        
    allrelations = Dict{String, Dict}()
    
    for elem in osmdata["elements"]
        if elem["type"] == "relation"
            memb = elem["members"]
            allrelations[string(elem["id"])] = Dict{String, String}(
                "from" => string(memb[1]["ref"]),
                "to" => string(memb[2]["ref"]),
                "via" => string(memb[3]["ref"]),
                "restriction" => elem["tags"]["restriction"]
            )
        end
        
    end

    return allrelations
end

# NODE
# - ID
# - [TURN_CONSTREINS]
#     - FRAM_EDGE
#         - TO_EDGES
#         - WEIGHT
#         - [..]
#     - [...]

# EDGE
# - ID
# - [WEIGHT]
# - [TIME_CONSTREINS]
#     - TIME_INTERVAL
#         - [UV or VU]
#         - WEIGHT
#         - [..]
#     - [...]
