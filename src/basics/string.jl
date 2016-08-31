@inline digitsRequired(bitsOfPrecision) = ceil(Int, bitsOfPrecision*0.3010299956639811952137)

# default values for summary view
const midpoint_digits = 12
const radius_digits   =  9
const midpoint_bits   = 40
const radius_bits     = 30

string{P}(x::ArbFloat{P}) = string(x, midpoint_bits, radius_bits)::String

function string{T<:ArbFloat}(x::T, mbits::Int=midpoint_bits, rbits::Int=radius_bits)::String
    return (
      if isfinite(x)
          isexact(x) ? string_exact(x, mbits) : string_inexact(x, mbits, rbits)
      else
          string_nonfinite(x)
      end
    )
end

function string_exact{T<:ArbFloat}(x::T, mbits::Int=midpoint_bits)::String
    cstr = ccall(@libarb(arb_get_str), Ptr{UInt8}, (Ptr{ArbFloat}, Int, UInt), &x, mbits, 2%UInt)
    s = unsafe_string(cstr)
    return cleanup_numstring(s, isinteger(x))
end

function string_inexact{T<:ArbFloat}(x::T, mbits::Int=midpoint_bits, rbits::Int=radius_bits)::String
    mid = string_exact(midpoint(x), mbits)
    rad = string_exact(radius(x), rbits)
    return string(mid, "±", rad)
end

function cleanup_numstring(numstr::String, isaInteger::Bool)::String
    s =
      if !isaInteger
          rstrip(numstr, '0')
      else
          string(split(numstr, '.')[1])
      end

    if s[end]=='.'
        s = string(s, "0")
    end
    return s
end

function string_nonfinite{P}(x::ArbFloat{P})::String
    return(
        if isnan(x)
            "NaN"
        elseif ispositive(x)
            "+Inf"
        elseif isnegative(x)
            "-Inf"
        else
            "±Inf"
        end
        )
end


#=
     find the smallest N such that stringTrimmed(lowerbound(x), N) == stringTrimmed(upperbound(x), N)
=#

function smartarbstring{P}(x::ArbFloat{P})
     digts = digitsRequired(P)
     if isexact(x)
        if isinteger(x)
            return string(x, digts, UInt(2))
        else
            s = rstrip(string(x, digts, UInt(2)),'0')
            if s[end]=='.'
               s = string(s, "0")
            end
            return s
        end
     end
     if radius(x) > abs(midpoint(x))
        return "0"
     end

     lb, ub = bounds(x)
     lbs = string(lb, digts, UInt(2))
     ubs = string(ub, digts, UInt(2))
     if lbs[end]==ubs[end] && lbs==ubs
         return ubs
     end
     for i in (digts-2):-2:4
         lbs = string(lb, i, UInt(2))
         ubs = string(ub, i, UInt(2))
         if lbs[end]==ubs[end] && lbs==ubs # tests rounding to every other digit position
            us = string(ub, i+1, UInt(2))
            ls = string(lb, i+1, UInt(2))
            if us[end] == ls[end] && us==ls # tests rounding to every digit position
               ubs = lbs = us
            end
            break
         end
     end
     if lbs != ubs
        ubs = string(x, 3, UInt(2))
     end
     rstrip(ubs,'0')
end

function smartvalue{P}(x::ArbFloat{P})
    s = smartarbstring(x)
    ArbFloat{P}(s)
end

function smartstring{P}(x::ArbFloat{P})
    s = smartarbstring(x)
    a = ArbFloat{P}(s)
    if notexact(x)
       s = string(s,upperbound(x) < a ? '-' : (lowerbound(x) > a ? '+' : '~'))
    end
    return s
end

function smartstring{T<:ArbFloat}(x::T)
    absx   = abs(x)
    sa_str = smartarbstring(absx)  # smart arb string
    sa_val = (T)(absx)             # smart arb value
    if notexact(absx)
        md,rd = midpoint(absx), radius(absx)
        lo,hi = bounds(absx)
        if     sa_val <= lo
            if lo-sa_val >= ufp2(rd)
                sa_str = string(sa_str,"⁺")
            else
                sa_str = string(sa_str,"₊")
            end
        elseif sa_val > hi
            if sa_val-hi >= ufp2(rd)
                sa_str = string(sa_str,"⁻")
            else
                sa_str = string(sa_str,"₋")
            end
        else
            sa_str = string(sa_str,"~")
        end
    end
    return sa_str
end

function stringall{P}(x::ArbFloat{P})
    if isexact(x)
        return string(x)
    end
    sm = string(midpoint(x))
    sr = try
            string(Float64(radius(x)))
        catch
            string(round(radius(x),58,2))
        end

    return string(sm," ± ", sr)
end

function stringcompact{P}(x::ArbFloat{P})
    string(x,8)
end

function stringallcompact{P}(x::ArbFloat{P})
    return (isexact(x) ? string(midpoint(x)) :
              string(string(midpoint(x),8)," ± ", string(radius(x),10)))
end



#=

function stringTrimmed{P}(x::ArbFloat{P}, ndigitsremoved::Int)
   n = max(1, digitsRequired(P) - max(0, ndigitsremoved))
   cstr = ccall(@libarb(arb_get_str), Ptr{UInt8}, (Ptr{ArbFloat}, Int, UInt), &x, n, UInt(2))
   s = unsafe_string(cstr)
   # ccall(@libflint(flint_free), Void, (Ptr{UInt8},), cstr)
   s
end

=#
