using OpenStreetMapGraphs, Test

function tests()
  @testset "load_save" begin
    query = overpassquery(53.67,10.16,53.,9.72)
    @test typeof(query) == String
    @test length(query) > 0
  end

  @testset "parse tag" begin
    value = OpenStreetMapGraphs.parsevalue("-1")
    @test typeof(value) == Int
    @test value == -1
    value2 = OpenStreetMapGraphs.parsevalue("yes")
    @test typeof(value2) == String
    @test value2 == "yes"

    word = OpenStreetMapGraphs.parsetokenword("PH off")
    @test typeof(word) == Array{AbstractString, 1}
    @test word == ["off"]
    word2 = OpenStreetMapGraphs.parsetokenword("PH")
    @test typeof(word2) == Array{AbstractString, 1}
    @test word2 == []
  end

end

tests()