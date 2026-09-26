# Grit
A small resilience library. It wraps fallible operations in exponential backoff loops with randomized jitter.
This prevents synchronized retries from overwhelming struggling services with thundering herds.

### Features
- Configurable base delays, multipliers, and ceilings.
- Includes `Full` and `Decorrelated` randomization to scatter retry spikes.
- In Studio, it fails fast on all errors except know transient DataStore throttles, saving you iteration time. In production, it defaults to retrying everything.
- Lets you check states (like if a player left the game) before executing the next attempt to break the loop early.
- Custom predicates

### Usage
Wrap the operation inside `Grit.WithBackoff`. The function yields using task.wait(), so do not call it in contexts where yielding is forbidden.
```luau
const DataStoreService = game:GetService("DataStoreService")
const Grit = require(path.to.Grit)

const playerDataStore = DataStoreService:GetDataStore("PlayerData")

const function loadData(userId: number)
    const success, result = Grit.WithBackoff(function()
        return playerDataStore:GetAsync(`User_{userId}`)
    end, {
        MaxAttempts = 5,
        BaseDelay = 0.5,
        Jitter = "Full",
        ShouldCancel = function()
            --// Cancel if the player disconnected during the backoff wait
            return not game.Players:GetPlayerByUserId(userId)
        end,
        OnRetry = function(attempt, err, delay)
            warn(`Attempt {attempt} failed: {err}. Retrying in {math.round(delay)}s...`)
        end
    })

    if success then
        print("Data loaded:", result)
    else
        warn("Final failure after retries:", result)
    end
end
```

### Configuration Reference
The second argument to `WithBackoff` is an optional `BackoffConfig` table. If omitted, Grit uses the defaults listed below.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `MaxAttempts` | `number` | 5 | Total number of attempts before giving up entirely |
| `BaseDelay` | `number` | 0.5 | Initial delay in seconds before the first retry |
| `MaxDelay` | `number` | 8 | Absolute cap on the delay duration in seconds |
| `Factor` | `number` | 2 | Multiplier applied to the delay after each attempt |
| `Jitter` | `string` | "Full" | The jitter algorithm. See the Jitter Modes section |
| `Retryable` | `function` | _(varies)_ | Function taking the error and returning a boolean. Defaults to only retrying DataStore errors in Studio, and all errors in production. |
| `ShouldCancel` | `function` | nil | Checked before each retry attempt. If it returns true, the loop aborts and returns `false, lastErr` |
| `OnRetry` | `function` | nil | Hook called before yielding for the next attempt. Passed `(attempt, error, delay)` |

### Jitter Modes
Jitter adds randomness to spread out requests.

Set the mode via the `Jitter` field in the config.
- `Full` (Default) randomizes the delay across the entire backoff window (from 0 to the current exponential cap). This provides the best overall distribution of load and prevents thundering herds entirely.
- `Decorrelated` randomizes the delay between the base delay and the current exponential step. This recovers faster after long outages but produces a slightly less smooth request distribution.
- `None` is the standard, deterministic exponential backoff. Do not use this in production. It is included strictly for unit testing.

### Predicates
By default, Grit uses `Grit.Predicates.DataStore` in Studio to filter out fatal script errors while still retrying actual Roblox backend throttles. You can swap this behaviour using the `Retryable` configuration property and the built-in predicates.