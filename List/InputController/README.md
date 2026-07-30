# InputController
Roblox input system with inputs, action bindings, combos, and signals. Wraps UserInputService into something easier to work with

This module isn't perfect, but it's simple to use and accessible for developers of any skill level.

For a more advanced module, check out Sleitnick's input module which is much more professional, but might be a bit harder to use for some people.

## Usage
Get the contents of the `src` folder into any place you want, though I generally have it in `StarterPlayerScripts`, but `ReplicatedStorage` is also fine, as long as the client has access to it.
Then require the module:
```luau
local InputController = require(path.to.module)
```

##
- **Signals:**
  
  Listen to signals like `InputBegan`, `InputEnded`, `InputChanged`, `DoubleTapped` & `ComboReached`.
  
  Here is how they work in practice:
  ```luau
  --[[
    # There is no need to check for gameProcessed, as these signals are already filtered for non-gameProcessed inputs
  --]]
  InputController.InputBegan:Connect(function(Input: InputObject))
    print(Input.KeyCode)
  end)

  --...

  InputController.ComboReached:Connect(function(ComboName: string))
    print(ComboName)
  end)
  ```
  
- **Action Binding:**
  
  Bind keys to callbacks with `BindAction` and remove them with `UnbindAction`.

  Here is how they work in practice:
  ```luau
  InputController:BindAction(
		ActionName: string,
		callback: (State: Enum.UserInputState, Input: InputObject),
		KeyCodes: Enum.KeyCode | {Enum.KeyCode}, --> A single KeyCode or multiple KeyCodes are possible here
	)

  InputController:UnbindAction(ActionName: string)
  ```
  Where a callback can look something like this:
  ```luau
  InputController:BindAction(
		'Jump',
		function(State, Input)
			if State == Enum.UserInputState.Begin then
				print('Jumped')
			end
		end,
		Enum.KeyCode.Space
	)
  ```
  This creates an Action called 'Jump' triggered by pressing Space. The callback prints 'Jumped' on press.
  You can bind multiple KeyCodes to one Action, pressing any of them triggers the callback.
  
  If you are looking for something else that requires all of them to be pressed, I recommend you just look for 'RegisterCombo' and 'ComboReached' under the **Combos** bulletpoint.

- **Key State Tracking:**
  
  Check if a key is held or how long it has been held.
  ```luau
  if InputController:IsKeyDown(Enum.KeyCode.LeftShift) then
    print('Running')
  end
  
  print(InputController:GetHeldDuration(Enum.KeyCode.LeftShift)) --> Time the key has been held in seconds, or 0 if not held.
  ```
  
- **Combos:**
  
  Register a sequence of keys that must be pressed in order within 1 second between each key press.
  ```luau
  InputController:RegisterCombo('Dash', Enum.KeyCode.Space, Enum.KeyCode.W)

  InputController.ComboReached:Connect(function(ComboName: string)
    print(ComboName) --> Prints 'Dash' if the player pressed Space THEN W in this exact order in a 1 second time frame between each input.
  end)
  ```

- **Mouse & Gamepad:**
  
  Get mouse position, delta, and thumbstick input
  ```luau
  local MousePos   = InputController:GetMousePosition() --> Vector2
  local MouseDelta = InputController:GetMouseDelta() --> Vector2 
  local Stick      = InputController:GetThumbstick(Enum.KeyCode.Thumbstick1) --> Vector2
  ```

- **Device Detection:**

  Detect the current device and input capabilities.
  ```luau
  print(InputController:GetCurrentDevice()) --> "PC" | "Mobile" | "Console"
  print(InputController:HasKeyboard()) --> true | false
  print(InputController:HasTouch()) --> true | false
  ```

## Dependency
InputController requires one dependency: the Signal module.
[Here](https://github.com/Sleitnick/RbxUtil/blob/main/modules/signal/init.luau) is a link to Sleitnick's Signal module.
