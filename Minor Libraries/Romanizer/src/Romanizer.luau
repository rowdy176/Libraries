--!strict

--[=[
	@class Romanizer
]=]

--========== Module ==========--
const Romanizer = {}

--========== Constants ==========--
const RomanMap = {
	{1000, 'M'}, {900, 'CM'}, {500, 'D'}, {400, 'CD'},
	{100, 'C'}, {90, 'XC'}, {50, 'L'}, {40, 'XL'},
	{10, 'X'}, {9, 'IX'}, {5, 'V'}, {4, 'IV'}, {1, 'I'}
}

--========== Public API ==========--

--[=[
	Turns the specified Number into Roman Numerals.
	
	The minimum number is 1 and the maximum is 3999, as
	Roman Numerals can't go below 1 or above 3999.
	
	If the specified Number is outside of the range,
	the Number will automatically be clamped to 1 or 3999.
	
	@within Romanizer
	@function ToRoman
	
	@param Number number
	
	@return string
]=]
function Romanizer.ToRoman(Number: number): string
	Number = math.clamp(math.round(Number), 1, 3999)
	
	local Result = ""
	
	for _, Pair in RomanMap do
		const Value, Symbol = Pair[1] :: number, Pair[2] :: string
		
		while Number >= Value do
			Result = Result .. Symbol
			Number = Number - Value
		end
	end
	
	return Result
end

--========== Return ==========--
return Romanizer