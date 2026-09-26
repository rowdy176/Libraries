--!strict
--[=[
	@class Retry
	
	A small resilience library for retrying fallible operations
	with exponential backoff and jitter.
	
	Supports DataStore calls, HTTP requests, or any other function
	that can fail transiently.
]=]
-----===== Services =====-----
const RunService = game:GetService("RunService")

-----===== Export =====-----
export type BackoffConfig = {
	MaxAttempts: number?,                                        --// Total attempts before giving up (default 5)
	BaseDelay: number?,                                          --// Initial delay in seconds (default 0.5)
	MaxDelay: number?,                                           --// Delay cap in seconds (default 8)
	Factor: number?,                                             --// Multiplier per attempt (default 2)
	Jitter: ("None" | "Full" | "Decorrelated")?,                 --// Default "Full"
	Retryable: ((err: any) -> boolean)?,                         --// Default: in Studio, fails fast on all
	                                                             --// errors except DataStore transient ones.
	                                                             --// In production, retries everything
	ShouldCancel: (() -> boolean)?,                              --// Checked before each attempt
	OnRetry: ((attempt: number, err: any, delay: number) -> ())? --// Logging hook
}

-----===== Constants =====-----
const RNG    = Random.new()
const Prefix = "[Retry | ModuleScript]:"

-----===== Module =====-----
const Retry = {}

-----===== Predicates =====-----

--[=[
	@within Retry
	@prop Predicates
	
	A set of ready-made Retryable classifiers for common services.
	Each takes the error thrown by the failed callback and returns
	whether it represents a transient (retryable) failure.
	
	Unknown/unrecognized errors always return false.
]=]
Retry.Predicates = {}

function Retry.Predicates.Always(): boolean
	return true
end

function Retry.Predicates.Never(): boolean
	return false
end

const DataStoreTransient = {
	"request rate exceeds the allowed maximum",
	"internal server error",
	"request dropped",
	"throttled",
	"rejected the request"
}

function Retry.Predicates.DataStore(err: any): boolean
	if typeof(err) ~= "string" then return false end
	for _, pattern in DataStoreTransient do
		if string.find(err, pattern, 1, true) then
			return true
		end
	end
	
	return false
end

-----===== Internal =====-----

--[=[
	@within Retry
	@function ComputeDelay
	@private
	
	@param config BackoffConfig
	@param attempt number
	@return number
	
	Computes the wait duration before the next attempt.
	
	"Full" jitter (default): randomize across the whole
	backoff window. Prevents synchronized retries from
	thundering herd against a struggling service.
	
	"Decorrelated": new delay is random between base and
	delay*factor. Recovers faster after long outages, but
	is less smooth.
	
	"None": raw exponential, deterministic. Only really
	useful/good for testing.
]=]
const function ComputeDelay(config: BackoffConfig, attempt: number): number
	const raw = math.min(
		config.MaxDelay :: number,
		(config.BaseDelay :: number) * (config.Factor :: number) ^ (attempt - 1)
	)
	
	const jitter = config.Jitter
	if jitter == "None" then
		return raw
	elseif jitter == "Decorrelated" then
		return RNG:NextNumber(config.BaseDelay :: number, math.min(raw * (config.Factor :: number), config.MaxDelay :: number))
	else --// "Full"
		return RNG:NextNumber() * raw
	end
end

-----===== Public API =====-----

--[=[
	@within Retry
	@method WithBackoff
	
	@param callback () -> ...any
	@param config BackoffConfig?
	@return boolean, ...any
	
	Runs callback, retrying with exponential backoff + jitter until
	it succeeds, is judged non-retryable, is cancelled, or exhausts
	attempts.
	
	On success: returns true plus all of the callback's return values.
	On failure: returns false plus the final error.
	
	Delays use task.wait, so this yields and must not be called from
	a context where yielding is forbidden.
]=]
function Retry.WithBackoff(callback: () -> ...any, config: BackoffConfig?): (boolean, ...any)
	assert(typeof(callback) == "function", `{Prefix} Callback must be a function!`)
	
	const cfg: BackoffConfig = config and table.clone(config) or {}
	cfg.MaxAttempts = cfg.MaxAttempts or 5
	cfg.BaseDelay   = cfg.BaseDelay or 0.5
	cfg.Factor      = cfg.Factor or 2
	cfg.MaxDelay    = cfg.MaxDelay or 8
	cfg.Jitter      = cfg.Jitter or "Full"
	
	const retryable    = cfg.Retryable or function(err: any)
		return Retry.Predicates.DataStore(err) or not RunService:IsStudio()
	end
	const shouldCancel = cfg.ShouldCancel
	const onRetry      = cfg.OnRetry
	
	local lastErr: any = nil
	assert((cfg.MaxAttempts :: number) >= 1, `{Prefix} MaxAttempts must be >= 1!`)
	for attempt = 1, cfg.MaxAttempts :: number do
		--// Cooperative cancellation point, checked before every attempt
		if attempt > 1 and shouldCancel and shouldCancel() then
			return false, lastErr
		end
		
		const packed = table.pack(pcall(callback))
		if packed[1] then
			return true, table.unpack(packed, 2, packed.n)
		end
		
		lastErr = packed[2]
		
		--// Last attempt, or the error isn't retryable.
		if attempt == cfg.MaxAttempts or not retryable(lastErr) then
			return false, lastErr
		end
		
		const delay = ComputeDelay(cfg, attempt)
		if onRetry then
			task.spawn(onRetry, attempt, lastErr, delay)
		end
		task.wait(delay)
	end
	
	--// Is unreachable, but keeps the linter happy.
	return false, lastErr
end

-----===== Return =====-----
return Retry