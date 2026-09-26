# Scheduler
A configurable, tick based task scheduler for Roblox.

Scheduler provides centralized task management for immediate and delayed callbacks, with independent tick rates for each scheduler instance.

### Features
- Configurable tick rate
- Immediate tasks with `Push`
- Delayed tasks with `Delay`
- Task cancellation with `Remove`
- Centralized task queues
- Deferred task removal using a tombstone marking pattern
- Independent scheduler instances (OOP)

### Example
```luau
const Scheduler = require(path.To.Scheduler)

const newScheduler = Scheduler.new({
  TickRate = 1 / 60 --// 60 ticks in one second.
})
newScheduler:Start()
--// All constructed Schedulers have a default paused state. Need to call Start() atleast once!

newScheduler:Push(function()
  print("Executed on the next tick!")
end)

newScheduler:Delay(2, function()
  print("Executed after 2 seconds!")
end)
```
Tasks can be cancelled using the ID returned by `Push` or `Delay`:
```luau
const ID = newScheduler:Delay(5, function()
  print("This will not execute.")
end)

newScheduler:Remove(ID)
```
