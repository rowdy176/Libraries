--!strict

--[[
	@class InputController.lua

	InputController is a wrapper for the UserInputService
  and provides efficient signal dispatching and event utilities for input management.
]]--

--========== Services ==========--
const UserInputService = game:GetService("UserInputService")
const GuiService       = game:GetService("GuiService")
const RunService       = game:GetService("RunService")

--========== Dependencies ==========--
const Signal = require(script.Dependancies.Signal)

--========== Constants ==========--
const DOUBLE_TAP_THRESHOLD = 0.3
const COMBO_EXPIRE_TIME    = 1.0
const THUMBSTICK_DEADZONE  = 0.15

--========== Module ==========--
const InputController = {}

--========== Public Signals ==========--
InputController.InputBegan   = Signal.new() --// Returns an InputObject
InputController.InputEnded   = Signal.new() --// Returns an InputObject
InputController.InputChanged = Signal.new() --// Returns an InputObject
InputController.DoubleTapped = Signal.new() --// Returns an InputObject
InputController.ComboReached = Signal.new() --// Returns a string, the ComboName

--========== Private States ==========--
const HeldInputs    = {} --// [KeyCode/UserInputType] = {Timestamp, Held}
const LastTapTimes  = {} --// [KeyCode/UserInputType] = timestamp
const BoundActions  = {} --// [ActionName] = {Inputs: {}, Callback: fn, Connection}
const ComboWatchers = {} --// [ComboName] = {Sequence: {}, Index: number, LastTime: number}

--========== Helpers ==========--

--[[
@brief Resolves a consistent key from an InputObject for use
@param Input: InputObject
@return Enum.KeyCode | Enum.UserInputType
]]--
const function ResolveKey(Input: InputObject): Enum.KeyCode | Enum.UserInputType
	if Input.KeyCode ~= Enum.KeyCode.Unknown then
		return Input.KeyCode
	end
	
	return Input.UserInputType
end

--========== Private ==========--

--[[
@brief Listens for input events and fires the corresponding signal
@return void
]]--
const function ListenInputs(): ()
	UserInputService.InputBegan:Connect(function(Input, gameProcessed)
		if gameProcessed then return end
		
		const key = ResolveKey(Input)
		HeldInputs[key] = {Timestamp = os.clock(), Held = true}
		
		InputController.InputBegan:Fire(Input)
		
		for _, action in BoundActions do
			for _, boundInput in ipairs(action.Inputs) do
				if boundInput == key then
					action.Callback(Enum.UserInputState.Begin, Input)
					break
				end
			end
		end
		
		for comboName, watcher in ComboWatchers do
			const expectedKey = watcher.Sequence[watcher.Index]
			const elapsed = os.clock() - watcher.LastTime
			
			if elapsed > COMBO_EXPIRE_TIME and watcher.Index > 1 then
				watcher.Index = 1
			end
			
			if expectedKey == key then
				watcher.Index += 1
				watcher.LastTime = os.clock()
				
				if watcher.Index > #watcher.Sequence then
					InputController.ComboReached:Fire(comboName)
					watcher.Index = 1
				end
			else
				watcher.Index = (expectedKey == key) and 2 or 1
				watcher.LastTime = os.clock()
			end
		end
	end)
	
	UserInputService.InputEnded:Connect(function(Input, gameProcessed)
		if gameProcessed then return end
		
		const key = ResolveKey(Input)
		HeldInputs[key] = nil
		
		InputController.InputEnded:Fire(Input)
		
		for _, action in BoundActions do
			for _, boundInput in ipairs(action.Inputs) do
				if boundInput == key then
					action.Callback(Enum.UserInputState.End, Input)
					break
				end
			end
		end
	end)
	
	UserInputService.InputChanged:Connect(function(Input, gameProcessed)
		if gameProcessed then return end
		InputController.InputChanged:Fire(Input)
	end)
end

--[[
@brief Listens for double taps on any key
@return void
]]--
const function ListenDoubleTaps(): ()
	InputController.InputBegan:Connect(function(Input)
		const key = ResolveKey(Input)
		const now = os.clock()
		const last = LastTapTimes[key]
		
		if last and (now - last) <= DOUBLE_TAP_THRESHOLD then
			InputController.DoubleTapped:Fire(Input)
			LastTapTimes[key] = nil
		else
			LastTapTimes[key] = now
		end
	end)
end

--========== Public API ==========--

--[[
@brief Returns true if the given KeyCode or UserInputType is currently held
@param Key: Enum.KeyCode | Enum.UserInputType
@return boolean
]]--
function InputController:IsKeyDown(Key: Enum.KeyCode | Enum.UserInputType): boolean
	return HeldInputs[Key] ~= nil
end

--[[
@brief Returns true if the given InputObject is currently held
@param Input: InputObject
@return boolean
]]--
function InputController:IsHeld(Input: InputObject): boolean
	return HeldInputs[ResolveKey(Input)] ~= nil
end

--[[
@brief Returns how long (seconds) the given key has been held, or 0 if not held
@param Key: Enum.KeyCode | Enum.UserInputType
@return number
]]--
function InputController:GetHeldDuration(Key: Enum.KeyCode | Enum.UserInputType): number
	const data = HeldInputs[Key]
	if not data then return 0 end
	return os.clock() - data.Timestamp
end

--[[
@brief Returns all currently held keys
@return {Enum.Keyocde | Enum.UserInputType}
]]--
function InputController:GetAllHeld(): {Enum.KeyCode | Enum.UserInputType}
	const result = {}
	
	for key in HeldInputs do
		table.insert(result, key)
	end
	
	return result
end

--[[
@brief Bind a named action to one or more inputs with a callback
@param ActionName: string
@param callback: (State: Enun.UserInputState, Input: InputObject) -> ()
@param ...: Enum.KeyCode | Enum.UserInputType
@return void
]]--
function InputController:BindAction(
	ActionName: string,
	callback: (Enum.UserInputState, InputObject) -> (),
	...: Enum.KeyCode | Enum.UserInputType
): ()
	BoundActions[ActionName] = {
		Inputs   = { ... },
		Callback = callback,
	}
end

--[[
@brief Unbinds a previously bound action
@param ActionName: string
@return void
]]--
function InputController:UnbindAction(ActionName: string): ()
	BoundActions[ActionName] = nil
end

--[[
@brief Register a combo. Fires ComboReached when the sequence of keys is hit in order
@param ComboName: string
@param ...: Enum.KeyCode | Enum.UserInputType
@return void
]]--
function InputController:RegisterCombo(ComboName: string, ...: Enum.KeyCode | Enum.UserInputType): ()
	ComboWatchers[ComboName] = {
		Sequence  = {...},
		Index     = 1,
		LastTime  = 0,
	}
end

--[[
@brief Unregister a combo
@param ComboName: string
@return void
]]--
function InputController:UnregisterCombo(ComboName: string): ()
	ComboWatchers[ComboName] = nil
end

--[[
@brief Returns the Mouse position in screen space
@return Vector2
]]--
function InputController:GetMousePosition(): Vector2
	return UserInputService:GetMouseLocation()
end

--[[
@brief Returns the Mouse delta this frame
@return Vector2
]]--
function InputController:GetMouseDelta(): Vector2
	return UserInputService:GetMouseDelta()
end

-- | Returns the position of a thumbstick axis with deadzone applied
--[[
@brief Returns the position of a thumbstick axis with deadzone applied
@param Thumbstick: Enum.KeyCode
@param Deadzone: numer?
@return Vector2
]]--
function InputController:GetThumbstick(Thumbstick: Enum.KeyCode, Deadzone: number?): Vector2
	const dz = Deadzone or THUMBSTICK_DEADZONE
	const state = UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
	
	for _, inputObj in ipairs(state) do
		if inputObj.KeyCode == Thumbstick then
			const pos = Vector2.new(inputObj.Position.X, inputObj.Position.Y)
			if pos.Magnitude < dz then return Vector2.zero end
			
			return pos.Unit * ((pos.Magnitude - dz) / (1 - dz))
		end
	end
	
	return Vector2.zero
end

--[[
@brief Returns true if any gamepad is connected
@return boolean
]]--
function InputController:IsGamepadConnected(): boolean
	return #UserInputService:GetConnectedGamepads() > 0
end

--[[
@brief Returns the detected platform
@return "Console" | "Mobile" | "PC"
]]--
function InputController:GetCurrentDevice(): string
	if GuiService:IsTenFootInterface() then return "Console" end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then return "Mobile" end
	return "PC"
end

--[[
@brief This is a wrapper for UserInputService.KeyboardEnabled
@return boolean
]]--
function InputController:HasKeyboard(): boolean
	return UserInputService.KeyboardEnabled
end

--[[
@brief This is a wrapper for UserInputService.TouchEnabled
@return boolean
]]--
function InputController:HasTouch(): boolean
	return UserInputService.TouchEnabled
end

--========== Main ==========--

--[[
@brief Main function, everything starts here
@return void
]]--
const function Main(): ()
	ListenInputs()
	ListenDoubleTaps()
end

Main()

--========== Return ==========--
return InputController
