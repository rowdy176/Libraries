--!strict
--[=[
	@class Scheduler
	
	A scheduler for running pushed or delay tasks.
]=]
-----===== Services =====-----
const RunService = game:GetService("RunService")

-----===== Constants =====-----
const Prefix = "[Scheduler | ModuleScript]:"

-----===== Export =====-----
export type Scheduler = {
	TickRate: number,
	_count: number,
	_heartbeat: RBXScriptConnection?,
	_accumulator: number,
	_running: boolean,
	_tasks: {{ID: number, Task: () -> ()}},
	_waitingQueue: boolean,
	_queueThread: thread?,
	_alive: {[number]: boolean},
	_tombstone: {[number]: boolean},
	_queue: {
		{
			ID: number,
			Duration: number,
			Start: number,
			Task: () -> ()
		}
	},
	
	Push: (self: Scheduler, Task: () -> ()) -> (),
	Start: (self: Scheduler) -> (),
	Pause: (self: Scheduler) -> (),
	Delay: (self: Scheduler, Duration: number, callback: () -> ()) -> (),
	Remove: (self: Scheduler, id: number) -> ()
}

-----===== Module =====-----
const Scheduler = {}
Scheduler.__index = Scheduler

-----===== Internal =====-----

--[=[
	@within Scheduler
	@function newID
	@private
	
	@param self Scheduler
	@return number
	
	Creates a new ID for a task to represent
	and track it.
]=]
const function newID(self: Scheduler): number
	self._count += 1
	
	--// Register the new ID in the alive table
	--// so the Remove method can avoid stale
	--// tombstone entries.
	self._alive[self._count] = true
	return self._count
end

--[=[
	@within Scheduler
	@function WaitingQueue
	@private
	
	@param self Scheduler
	@return void
	
	Pushes ready tasks from the waiting queue to the active queue.
	
	This deliberately uses a single background coroutine instead of
	another RunService connection or a seperate thread per task,
	as the waiting queue is a background operation that should not
	consume more resources than necessary.
]=]
const function WaitingQueue(self: Scheduler): ()
	if self._waitingQueue then return end
	if not self._running then return end
	self._waitingQueue = true
	
	local thisThread = coroutine.running()
	self._queueThread = thisThread
	
	while self._running and self._queueThread == thisThread do
		task.wait(self.TickRate)
		if not self._running then continue end
		if #self._queue == 0 then continue end
		
		local currentTime = time()
		
		for i = #self._queue, 1, -1 do
			local Data = self._queue[i]
			if self._tombstone[Data.ID] then
				self._tombstone[Data.ID] = nil
				table.remove(self._queue, i)
				continue
			end
			if Data.Duration + Data.Start <= currentTime then
				table.insert(self._tasks, {
					ID = Data.ID,
					Task = Data.Task
				})
				table.remove(self._queue, i)
			end
		end
	end
end

--[=[
	@within Scheduler
	@function Loop
	@private
	
	@param self Scheduler
	@return void
	
	Internal function for the scheduler loop.
]=]
const function Loop(self: Scheduler): ()
	if self._heartbeat then return end
	
	self._heartbeat = RunService.Heartbeat:Connect(function(DeltaTime: number)
		self._accumulator += DeltaTime
		
		--// Cap the accumulator to prevent it from growing unbounded
		if self._accumulator > 0.25 then
			self._accumulator = 0.25
		end
		
		while self._accumulator >= self.TickRate do
			for i = #self._tasks, 1, -1 do
				local ID = self._tasks[i].ID
				if self._tombstone[ID] then
					self._tombstone[ID] = nil
					table.remove(self._tasks, i)
					continue
				end
				self._tasks[i].Task()
				table.remove(self._tasks, i)
			end
			
			self._accumulator -= self.TickRate
		end
	end)
end

-----===== Constructor =====-----

--[=[
	@within Scheduler
	@function new
	
	@param config {[any]: any} -- Configuration for the scheduler
	@return Scheduler
	
	Constructs a new Scheduler instance.
]=]
function Scheduler.new(config: {[any]: any}?): Scheduler
	local self = setmetatable({} :: Scheduler, Scheduler)
	
	self.TickRate     = config and config.TickRate or 1 / 60 :: number
	
	self._count          = 0 :: number
	self._heartbeat      = nil :: RBXScriptConnection?
	self._accumulator    = 0 :: number
	self._running        = false :: boolean
	self._tasks          = {} :: {{ID: number, Task: () -> ()}}
	self._waitingQueue   = false :: boolean
	self._queueThread    = nil :: thread?
	self._alive          = {} :: {[number]: boolean}
	self._tombstone      = {} :: {[number]: boolean}
	self._queue          = {} :: {
		{
			ID: number,
			Duration: number,
			Start: number,
			Task: () -> ()
		}
	}
	
	return self
end

-----===== Public API =====-----

--[=[
	@within Scheduler
	@method Push
	
	@param callback () -> () -- Function to be executed
	@return number
	
	Pushes a function to the scheduler's task queue.
]=]
function Scheduler.Push(self: Scheduler, callback: () -> ()): number
	assert(typeof(callback) == "function", `{Prefix} Task must be a function!`)
	
	local id = newID(self)
	table.insert(self._tasks, {
		ID = id,
		Task = callback
	})
	
	return id
end

--[=[
	@within Scheduler
	@method Start
	
	Starts the scheduler if it's not already running.
	This needs to be run atleast once as all Schedulers
	default to a paused state when constructed.
]=]
function Scheduler.Start(self: Scheduler): ()
	assert(not self._running, `{Prefix} Scheduler is already running!`)
	self._running = true
	
	Loop(self)
	task.spawn(function() WaitingQueue(self) end)
end

--[=[
	@within Scheduler
	@method Pause
	
	@param self Scheduler
	@return void
	
	Pauses the scheduler.
]=]
function Scheduler.Pause(self: Scheduler): ()
	assert(self._running, `{Prefix} Scheduler is already paused!`)
	self._running      = false
	self._waitingQueue = false
	self._queueThread  = nil
	
	if self._heartbeat then
		self._heartbeat:Disconnect()
		self._heartbeat = nil
	end
end

--[=[
	@within Scheduler
	@method Delay
	
	@param self Scheduler
	@param duration number
	@param callback () -> ()
	
	@return number
	
	Schedules a callback to be executed after a given duration.
	The WaitingQueue thread handles this by pushing the callback
	to the active task queue after the given duration.
]=]
function Scheduler.Delay(self: Scheduler, duration: number, callback: () -> ()): number
	assert(typeof(callback) == "function", `{Prefix} Task must be a function!`)
	
	local start = time()
	local id    = newID(self)
	table.insert(self._queue, {
		ID = id,
		Duration = duration,
		Start = start,
		Task = callback
	})
	return id
end

--[=[
	@within Scheduler
	@method Remove
	
	@param self Scheduler
	@param id number
	
	@return void
	
	Adds the given ID to the scheduler's tombstone list.
	The WaitingQueue thread and main tick thread will
	clean up the task from either queue if they find it.
]=]
function Scheduler.Remove(self: Scheduler, id: number): ()
	assert(typeof(id) == "number", `{Prefix} ID must be a number!`)
	assert(self._alive[id], `{Prefix} Stale Tombstone Entry detected! Given ID ({id}) is not valid!`)
	
	self._alive[id] = nil
	self._tombstone[id] = true
end

-----===== Return =====-----
return Scheduler
