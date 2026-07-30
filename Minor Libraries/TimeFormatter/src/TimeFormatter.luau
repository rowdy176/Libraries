--!strict

--[=[
	@class TimeFormatter
	
	Formats time in seconds into a string.
]=]

--========== Module ==========--
const TimeFormatter = {}

--========== Constants ==========--
const TimeTable = {
	Weeks = 604800,
	Days  = 86400,
	Hours = 3600,
	Mins  = 60,
	Secs  = 1,
}

const TimeUnits = {
	{Limit = TimeTable.Weeks, Label = "w"},
	{Limit = TimeTable.Days,  Label = "d"},
	{Limit = TimeTable.Hours, Label = "h"},
	{Limit = TimeTable.Mins,  Label = "m"},
	{Limit = TimeTable.Secs,  Label = "s"},
}

--========== Public API ==========--

--[=[
	Converts a number or string of seconds into a readable time string.
	Handles weeks, days, hours, minutes, and seconds with proper remainder logic.
	
	@param Time number string -- The amount of seconds to convert.
	@return string? -- The formatted string e.g. "30s", "1m 30s", "1h 2m". Returns nil if invalid.
]=]
function TimeFormatter.xmxs(Time: number | string): string?
	const Raw = tonumber(Time)
	if not Raw or Raw < 0 then return nil end
	
	local Remaining = math.floor(Raw)
	const Parts = {}
	
	for _, Unit in TimeUnits do
		if Remaining >= Unit.Limit then
			const Count = math.floor(Remaining / Unit.Limit)
			table.insert(Parts, Count .. Unit.Label)
			Remaining %= Unit.Limit
		end
	end
	
	if #Parts == 0 then
		return "0s"
	end
	
	return table.concat(Parts, " ")
end

--========== Return ==========--
return TimeFormatter