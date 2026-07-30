--!strict

--[=[
    @class TouchObserver
    
    Observes touches on a part and fires events for players, characters, and humanoids.
    Supports filters and cooldowns to manage touch events.
]=]

--========== Services ==========--
const Players = game:GetService("Players")

--========== Dependencies ==========--
const Signal = require(script.Parent.Signal)

--========== Export Types ==========--
export type TouchObserver = {
	Part: BasePart,
	Cooldown: number,
	PlayerTouched: Signal.Signal<Player>,
	CharacterTouched: Signal.Signal<Model>,
	HumanoidTouched: Signal.Signal<Humanoid>,
	_Touches: {},
	_Filters: {},
	_Alive: true,
	_Connection: RBXScriptConnection,

	new: (Part: BasePart, Cooldown: number?) -> TouchObserver,
	AddFilter: (self: TouchObserver, FilterFunction: () -> boolean) -> TouchObserver,
	SetCooldown: (self: TouchObserver, Cooldown: number) -> (),
	Destroy: (self: TouchObserver) -> (),
}

--========== Module ==========--
const TouchObserver = {}
TouchObserver.__index = TouchObserver

--========== Helpers ==========--

--[=[
    Resolves the character and humanoid from a hit part.

    @within TouchObserver
    @function ResolveCharacter
    @private

    @param Hit BasePart

    @return Model?
    @return Humanoid?
]=]
const function ResolveCharacter(Hit: BasePart): (Model?, Humanoid?)
	const Character = Hit.Parent
	if not Character then return end
	
	const Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then return end
	
	return Character, Humanoid
end

--[=[
    Checks if a character and humanoid pass all filters.

    @within TouchObserver
    @function PassesFilters
    @private

    @param self TouchObserver
    @param Character Model
    @param Humanoid Humanoid

    @return boolean
]=]
const function PassesFilters(self: TouchObserver, Character: Model, Humanoid: Humanoid): boolean
	if not self._Filters then
		return true
	end
	
	for _, Filter in self._Filters do
		local Result = Filter(Character, Humanoid)
		if not Result then
			return false
		end
	end
	
	return true
end

--========== Public API ==========--

--[=[
	Creates a new TouchObserver for the specified part.

	@within TouchObserver
	@function new

	@param Part BasePart
	@param Cooldown number? -- Optional cooldown duration in seconds (default: 0.15)

	@return TouchObserver
]=]
function TouchObserver.new(Part: BasePart, Cooldown: number?): TouchObserver
	const self = setmetatable({} :: TouchObserver, TouchObserver)
	
	self.Part = Part
	self.Cooldown = Cooldown or 0.15
	self._Touches = {}
	self._Filters = {}
	
	self._Alive = true
	
	self.PlayerTouched = Signal.new() :: Signal.Signal<Player>
	self.CharacterTouched = Signal.new() :: Signal.Signal<Model>
	self.HumanoidTouched = Signal.new() :: Signal.Signal<Humanoid>
	
	self._Connection = Part.Touched:Connect(function(Hit: BasePart)
		if not self._Alive then return end
		const Character, Humanoid = ResolveCharacter(Hit)
		if not Character or not Humanoid then return end
		
		if not PassesFilters(self, Character, Humanoid) then
			return
		end
		
		const Time = tick()
		const Last = self._Touches[Character]
		
		if Last and (Time - Last) < self.Cooldown then return end
		
		self._Touches[Character] = Time
		
		const Player = Players:GetPlayerFromCharacter(Character)
		
		self.CharacterTouched:Fire(Character)
		self.HumanoidTouched:Fire(Humanoid)
		
		if not Player then return end
		self.PlayerTouched:Fire(Player)
	end)
	
	return self
end

--[=[
	Adds a filter function to the observer.
	The filter function should return true to allow the touch event to proceed, or false to block it.

	@within TouchObserver
	@method AddFilter

	@param FilterFunction () -> boolean

	@return TouchObserver
]=]
const function TouchObserver.AddFilter(self: TouchObserver, FilterFunction: () -> boolean): TouchObserver
	if not self._Filters then
		self._Filters = {}
	end
	
	table.insert(self._Filters, FilterFunction)
	return self
end

--[=[
	Sets the cooldown duration for touch events.
	Touch events from the same character will be ignored if they occur within this cooldown period.

	@within TouchObserver
	@method SetCooldown

	@param Cooldown number

	@return void
]=]
const function TouchObserver.SetCooldown(self: TouchObserver, Cooldown: number): ()
	if Cooldown <= 0 then return end
	self.Cooldown = Cooldown
end

--[=[
	Destroys the observer and cleans up all resources.

	@within TouchObserver
	@method Destroy

	@return void
]=]
const function TouchObserver:Destroy(): ()
	self._Alive = false
	
	if self._Connection then
		self._Connection:Disconnect()
	end
	
	self.PlayerTouched:Destroy()
	self.CharacterTouched:Destroy()
	self.HumanoidTouched:Destroy()
	
	table.clear(self._Touches)
	table.clear(self._Filters or {})
end

--========== Return ==========--
return TouchObserver
