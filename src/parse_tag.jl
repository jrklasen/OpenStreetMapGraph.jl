daysofweek = ["Mo", "Tu", "We", "Th", "Fr", "Sa","Su"]
specialdays = ["PH", "SH"]


"""Parse a conditional tag of the following structure:
<restriction-value> @ <condition>[;<restriction-value> @ <condition>]

Rturns a dictionary of complonents. 
"""
function parseconditionaltag(conditionaltag::AbstractString)::Dict{Symbol, Dict}
    # regex for values: find value-pards of string
    regexvalue = r"\;?\s?(\-?[[:alnum:]\_\.]*)\s?@"
    values = collect(m.captures[1] for m = eachmatch(regexvalue, conditionaltag))

    # regex for condition: find codition-pards of string
    regexcondi1 = r"@\s?\(([[:alnum:]\s\;\:\,\.\-\<\>]+)\)\;?"
    regexcondi2 = r"@\s?([[:alnum:]\:\,\.\-\<\>]+\s?[[:alnum:]\:\,\.\-\<\>]+)\;?"
    condis = [collect(m.captures[1] for m = eachmatch(regexcondi1, conditionaltag)); 
              collect(m.captures[1] for m = eachmatch(regexcondi2, conditionaltag))]
    values = [string(i) for i = values]
    condis = [string(i) for i = condis]

    # check if result is plausible if validatetokens=ture
    if length(values) == length(condis)
        norg = length(conditionaltag)
        norgspe = sum(length.(findall.(isequal.(['@', ';', '(', ')', ' ']), conditionaltag)))
        nres = sum([length.(i) for i in [values; condis]])
        nresspe = sum([sum(length.(findall.(isequal.([';', ' ']), i))) for i = [values; condis]])
        mengthmatch = norg - (nres + norgspe - nresspe)
        if mengthmatch != 0
            @error "The tokenizer of the conditional tags resulted in an implausible character count" condition=conditionaltag tokens=[values, condis]
        end
    else
        @error "The number of value and condition tokens don't match" values=values conditions=condis
    end

    # gether parsed data into a dictionary
    out = Dict{Symbol, Dict}()
    count = 1
    for (v, c) = zip(values, condis)
        valcondi = Dict{Symbol, Union{Dict, AbstractString, Integer}}(:value => v)
        condi = parsecondition(c)
        keyscondi = collect(keys(condi))
        for k = keyscondi
            valcondi[k] = condi[k]
        end

        out[Symbol("condition" * string(count))] = valcondi

        count += 1
    end

    return out
end 


""" Parse condition part of a conditional tag.  Rturns a dictionary of complonents.
"""
function parsecondition(condition::AbstractString)::Dict{Symbol, Dict}
    condis = strip.(split(condition, ';'))

    out = Dict{Symbol, Dict}()
    count = 1
    for token = condis
        # todo: capture AND !!!!!!!
        # haven't seen it in the tags of intrest, but it is part of the syntax
        daytimeword = Dict{Symbol, Union{AbstractArray, Dict}}(
            :words => parseconditionword(token), 
            :hoursofday => parseconditiontime(token))
        days = parseconditionday(token)
        daytimeword[:daysofweek] = days[:daysofweek]
        daytimeword[:specialdays] = days[:specialdays]

        out[Symbol("rule" * string(count))] = daytimeword

        count += 1
    end

    return out
end


""" Parse time (hour of day) component of the condition token as array of int.
"""
function parseconditiontime(token::AbstractString)::AbstractArray{UInt8}
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
function parseconditionday(token::AbstractString)::Dict{Symbol, AbstractArray}
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

    return Dict{Symbol, AbstractArray}(:daysofweek => days, :specialdays => sdays)
end


""" Find special word in condition token. Return array of Strings
"""
function parseconditionword(token::AbstractString)::AbstractArray{AbstractString, 1}
    regexword = r"(off|signal)"
    words = collect(string(m.captures[1]) for m = eachmatch(regexword, token))

    return words
end
