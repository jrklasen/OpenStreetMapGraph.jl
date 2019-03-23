using OpenStreetMapGraphs, Test
# execute test with:
# using Pkg; Pkg.test("OpenStreetMapGraphs")

function tests()
    @testset "load_save" begin
        query = overpassquery(53.67,10.16,53.,9.72)
        @test typeof(query) == String
        @test length(query) > 0
    end

    @testset "parse tag" begin
        word = OpenStreetMapGraphs.rulewords("PH off")
        @test typeof(word) == Array{AbstractString, 1}
        @test word == ["off"]
        word2 = OpenStreetMapGraphs.rulewords("PH")
        @test typeof(word2) == Array{AbstractString, 1}
        @test word2 == []
    end

    @testset "maxspeed tags" begin
        @testset "maxspeed" begin
            way = Dict(
                "type" => "way", 
                "tags" => Dict(
                    "maxspeed"=> "12",
                    "maxspeed:forward" => "123",
                    "maxspeed:backward" => "1234"
                )
            )                
            maxspeed =  OpenStreetMapGraphs.maxspeed(way)
            @test maxspeed[:maxspeed] === 12
            @test typeof(maxspeed[:maxspeed]) <: Real

            @test maxspeed[:uvmaxspeed] === 123
            @test typeof(maxspeed[:uvmaxspeed]) <: Real

            @test maxspeed[:vumaxspeed] === 1234
            @test typeof(maxspeed[:vumaxspeed]) <: Real
        end
        @testset "maxspeed:conditional" begin
            way = Dict(
                "type" => "way", 
                "tags" => Dict(
                    "maxspeed"=> "12",
                    "maxspeed:conditional" => "30@(22:00-06:00)",
                )
            )                
            maxspeed =  OpenStreetMapGraphs.maxspeed(way)
            @test length(maxspeed[:maxspeed]) === 168
            @test typeof(maxspeed[:maxspeed]) == Array{Union{Missing,Real},1}
            @test maxspeed[:maxspeed][6] === 30
            @test maxspeed[:maxspeed][7] === 12
            @test maxspeed[:maxspeed][22] === 12
            @test maxspeed[:maxspeed][23] === 30

            way["tags"]["maxspeed:conditional"] = "30 @ (06:00-22:00; Su,PH off)"
            maxspeed =  OpenStreetMapGraphs.maxspeed(way)
            @test length(maxspeed[:maxspeed]) === 168
            @test typeof(maxspeed[:maxspeed]) == Array{Union{Missing,Real},1}
            @test maxspeed[:maxspeed][6] === 12
            @test maxspeed[:maxspeed][7] === 30
            @test maxspeed[:maxspeed][22] === 30
            @test maxspeed[:maxspeed][23] === 12
            @test maxspeed[:maxspeed][165] === 12
            @test maxspeed[:maxspeed][166] === 12
            
            way["tags"]["maxspeed:conditional"] = "30 @ (Mo-Fr 00:00-06:30,22:00-24:00; Sa,Su 00:00-24:00)"
            maxspeed =  OpenStreetMapGraphs.maxspeed(way)
            @test length(maxspeed[:maxspeed]) === 168
            @test typeof(maxspeed[:maxspeed]) == Array{Union{Missing,Real},1}
            @test maxspeed[:maxspeed][6] === 30
            @test maxspeed[:maxspeed][7] === 12
            @test maxspeed[:maxspeed][22] === 12
            @test maxspeed[:maxspeed][23] === 30
            @test maxspeed[:maxspeed][165] === 30
            @test maxspeed[:maxspeed][166] === 30

            way["tags"]["maxspeed:conditional"] = "30 @ (Mo-Fr 00:00-06:00;Mo-Sa 22:00-24:00;Su 00:00-24:00)"
            maxspeed =  OpenStreetMapGraphs.maxspeed(way)
            @test length(maxspeed[:maxspeed]) === 168
            @test typeof(maxspeed[:maxspeed]) == Array{Union{Missing,Real},1}
            @test maxspeed[:maxspeed][6] === 30
            @test maxspeed[:maxspeed][7] === 12
            @test maxspeed[:maxspeed][22] === 12
            @test maxspeed[:maxspeed][23] === 30
            @test maxspeed[:maxspeed][126] === 12
            @test maxspeed[:maxspeed][126] === 12
            @test maxspeed[:maxspeed][142] === 12
            @test maxspeed[:maxspeed][143] === 30
            @test maxspeed[:maxspeed][165] === 30
            @test maxspeed[:maxspeed][166] === 30

            way["tags"]["maxspeed:conditional"] = "30 @ (Mo-Sa 06:00-22:00);50 @ We" 
            maxspeed =  OpenStreetMapGraphs.maxspeed(way)
            @test length(maxspeed[:maxspeed]) === 168
            @test typeof(maxspeed[:maxspeed]) == Array{Union{Missing,Real},1}
            @test maxspeed[:maxspeed][6] === 12
            @test maxspeed[:maxspeed][7] === 30
            @test maxspeed[:maxspeed][22] === 30
            @test maxspeed[:maxspeed][23] === 12
            @test maxspeed[:maxspeed][70] === 50
            @test maxspeed[:maxspeed][166] === 12
        end
    end
end


tests()