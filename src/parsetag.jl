daysofweek = ["Mo", "Tu", "We", "Th", "Fr", "Sa","Su"]
specialdays = ["PH", "SH"]


"""Parse a conditional tag of the following structure:
<restriction-value> @ <condition>[;<restriction-value> @ <condition>]

Rturns a dictionary of complonents. 
"""
function parseconditionaltag(
        tag::String;
        daysofweek=daysofweek,
        specialdays=specialdays
    )::Dict{Symbol, Dict}
    # regex for values: find value-parts of string
    regexvalue = r"\;?\s?(\-?[[:alnum:]\_\.]*)\s?@"
    values = collect(m.captures[1] for m = eachmatch(regexvalue, tag))

    # regex for condition: find codition-parts of string
    regexcondi1 = r"@\s?\(([[:alnum:]\s\;\:\,\.\-\<\>]+)\)\;?"
    regexcondi2 = r"@\s?([[:alnum:]\:\,\.\-\<\>]+\s?[[:alnum:]\:\,\.\-\<\>]+)\;?"
    condis = [collect(m.captures[1] for m = eachmatch(regexcondi1, tag)); 
              collect(m.captures[1] for m = eachmatch(regexcondi2, tag))]
    values = [string(i) for i = values]
    condis = [string(i) for i = condis]

    # check if result is plausible 
    # todo: allow turning this off, as it is costly
    if length(values) == length(condis)
        norg = length(tag)
        norgspe = sum(length.(findall.(isequal.(['@', ';', '(', ')', ' ']), tag)))
        nres = sum([length.(i) for i in [values; condis]])
        nresspe = sum([sum(length.(findall.(isequal.([';', ' ']), i))) for i = [values; condis]])
        mengthmatch = norg - (nres + norgspe - nresspe)
        if mengthmatch != 0
            @error "The tokenizer of the conditional tags resulted in an implausible character count" condition=tag tokens=[values, condis]
        end
    else
        @error "The number of value and condition tokens don't match" values=values conditions=condis
    end

    # gether parsed data into a dictionary
    out = Dict{Symbol, Dict}()
    count = 1
    for (v, c) = zip(values, condis)
        out[Symbol("condition" * string(count))] =  Dict{Symbol, Union{Dict, String, Integer}}(
            :value => v, 
            :rules => parsecondition(c, daysofweek=daysofweek, specialdays=specialdays)
        )

        count += 1
    end

    return out
end 


""" Parse condition part of a conditional tag.  Returns a rules as dictionary.
"""
function parsecondition(
        condition::String;
        daysofweek=daysofweek,
        specialdays=specialdays
    )::Dict{Symbol, Dict}
    condis = strip.(split(condition, ';'))

    out = Dict{Symbol, Dict}()
    count = 1
    for token = condis
        # todo: capture AND !!!!!!!
        # haven't seen it in the tags of intrest, but it is part of the syntax
        days = ruledays(token, daysofweek=daysofweek, specialdays=specialdays)
        hours = rulehours(token)
        daytimeword = Dict{Symbol, Union{Array, Dict}}(
            :words => rulewords(token), 
            :hoursofweek => hoursofweek(hours, days[:days], days[:specialdays])
        )
        out[Symbol("rule" * string(count))] = daytimeword

        count += 1
    end

    return out
end


""" Parse time (hour of day) component of the condition token as array of int.
"""
function rulehours(
        token::AbstractString
    )::Array{UInt8}
    token = replace(token, "24:00" => "00:00")
    # one or more time intervals
    regextime = r"(\d{2}:\d{2})-(\d{2}:\d{2})"
    timeinterval = collect(string.(m.captures) for m = eachmatch(regextime, token))
    if length(timeinterval) > 0
        starttimes, endtimes = [[Dates.hour(Dates.Time.(i)) for i = j] for j = zip(timeinterval...)]
        endtimes = [i == 0 ? 24 : i for i = endtimes]
        if length(starttimes) > 1 &&  
                issorted([i for j = zip(starttimes, endtimes) for i = j])
            hoursofday =  UInt8[i for (s, e) = zip(starttimes, endtimes) for i in collect(s:(e-1))]
        elseif length(starttimes) == 1
            if starttimes[1] > endtimes[1] 
                hoursofday = [collect(UInt8, 0:(endtimes[1]-1)); collect(UInt8, starttimes[1]:23)]
            else
                hoursofday = collect(UInt8, starttimes[1]:(endtimes[1]-1))
            end
        else
            throw(ErrorException("The time part of the condition can't be interpreted: $token"))
        end

    else
        hoursofday = UInt8[]
    end
    
    return hoursofday
end


""" Parse the day component of the condition token. Return dict containng a array 
of `daysofweek` as numbers between 1  (Mo) and 7 (Su) and `specialdays` array of strings.
"""
function ruledays(
        token::AbstractString;
        daysofweek=daysofweek,
        specialdays=specialdays
    )::Dict
    regexdayint = r"(Mo|Tu|We|Th|Fr|Sa|Su)-(Mo|Tu|We|Th|Fr|Sa|Su)"
    dayinterval = match(regexdayint, token)
    if dayinterval != nothing
        firstday = findfirst(dayinterval.captures[1] .== daysofweek)
        lastday = findfirst(dayinterval.captures[2] .== daysofweek)
        if firstday <= lastday 
            days = collect(UInt8, firstday:lastday)
            sdays = String[]
        else 
            days = [collect(UInt8, 1:lastday); collect(UInt8, firstday:7)]
            sdays = String[]
        end
    else
        regexdaycol = r"(Mo|Tu|We|Th|Fr|Sa|Su|PH)"
        dayscolect = collect(string(m.captures[1]) for m = eachmatch(regexdaycol, token))
        days = UInt8[]
        sdays = String[]
        if length(dayscolect) > 0
            for dc = dayscolect
                d = findfirst(dc .== daysofweek)
                if d != nothing
                    days = UInt8[days; d]
                end
                sd = specialdays[dc .== specialdays]
                if sd != nothing
                    sdays = [sdays; sd]
                end
            end
        end
    end
    out = Dict(
        :days => days, 
        :specialdays => sdays
    )

    return out
end


""" Find special word in condition token. Return array of Strings
"""
function rulewords(
        token::AbstractString
    )::Array{String, 1}
    regexword = r"(off|signal|wet)"
    words = collect(string(m.captures[1]) for m = eachmatch(regexword, token))

    return words
end


""" Use day of week and hour of day and return the hour of week
"""
function hoursofweek(
        hours::Array{<:UInt8,1}=UInt8[],
        days::Array{<:UInt8,1}=UInt8[], 
        specialdays::Array{<:AbstractString,1}=String[]
    )::Array{UInt8,1}
    nd = length(days)
    nh = length(hours)
    nsd = length(specialdays)

    # if days and hours are empty return empty array
    # if days are empty but specialdays are not, return empty array
    if nd == 0 && nh == 0 || nd == 0 && nsd != 0
        return Array{UInt8,1}[]
    # if only days are empty generate all days
    elseif nd == 0 && nsd == 0
        days = collect(UInt8, 1:7)
        nd = length(days)
    # if hours are empty generate all hours
    elseif nh == 0
        hours = collect(UInt8, 0:23)
        nh = length(hours)
    end
    daysashours = (days .- 1) .* 24
    
    # hours per day
    out = reshape((daysashours' .+ hours), nd * nh)

    return out
end

