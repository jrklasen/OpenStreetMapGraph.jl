function maxspeedaskmh(token::AbstractString)
    number = match(r"^(\d+)", token)
    if number != nothing
        number = parse(Int, number.match)
        unit = match(r"(km/h|kmh|kph|mph|knots)$", token)
        if unit === nothing
            return number
        elseif unit.captures[1] in ["km/h", "kmh", "kph"]
            return number
        elseif unit.captures[1] == "mph"
            return number * 1.609
        elseif unit.captures[1] == "knots"
            return number * 1.852
        end
    else
        # statement =  match(r"^(none|...)", token)
        # todo: underdevelopment
   end      
end
