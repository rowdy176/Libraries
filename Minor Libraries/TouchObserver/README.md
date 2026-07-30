# TouchObserver

A small wrapper around `BasePart.Touched` that provides cooldowns, filtering, and separate signals for players, characters, and humanoids.

Useful when you don't want to repeatedly write the same touch validation logic.

## Example

```luau
const TouchObserver = require(path.To.TouchObserver)

const Observer = TouchObserver.new(workspace.Part)

Observer.PlayerTouched:Connect(function(Player)
	print(Player.Name .. " touched the part!")
end)

--// If this filter function returns false, the Touched connection stops before sending a signal.
Observer:AddFilter(function(Character, Humanoid)
	return Humanoid.Health > 0
end)
```

## API

### `TouchObserver.new(Part: BasePart, Cooldown: number?)`

Creates a new observer for a part.

### Design choice

* The cooldown defaults to `0.15` seconds and is applied per character.

### Signals

#### `PlayerTouched: Signal<Player>`

Fires when a player touches the part.

#### `CharacterTouched: Signal<Model>`

Fires whenever a valid character touches the part.

#### `HumanoidTouched: Signal<Humanoid>`

Fires whenever a valid humanoid touches the part.

### `Observer:AddFilter(FilterFunction)`

Adds a filter that runs before any signals fire.

The filter receives the touching `Character` and `Humanoid`.

Return `true` to allow the touch or `false` to ignore it.

Multiple filters can be added. Every filter must pass for the touch to be accepted.

### `Observer:SetCooldown(Cooldown: number)`

Changes the cooldown duration.

### `Observer:Destroy()`

Disconnects the observer and destroys all internal signals.


## <b> Design choices </b>

* Cooldowns are tracked per character, not globally.
* Invalid touches (non-characters, missing humanoids, failed filters) are ignored.
* All three signals fire for player characters. NPCs only fire `CharacterTouched` and `HumanoidTouched`.
* Filters are evaluated before cooldowns or signals.
* Additional features may be added over time if I or others find them useful.
