--!nocheck
-- Deterministic replacement for Roblox's `task` library. Threads started via
-- spawn/defer/delay are "managed": their task.wait() yields until the test
-- advances the virtual clock. Waits on unmanaged threads (the test body)
-- just move the clock forward.

local VirtualTask = {}

function VirtualTask.new()
	local V = { time = 0, queue = {}, managed = setmetatable({}, { __mode = "k" }), errors = {} }

	local function resume(co, ...)
		local ok, err = coroutine.resume(co, ...)
		if not ok then
			table.insert(V.errors, debug.traceback(co, tostring(err)))
		end
	end

	local function schedule(at, co, ...)
		table.insert(V.queue, { at = at, co = co, args = table.pack(...) })
	end

	function V.spawn(fn, ...)
		local co = if type(fn) == "thread" then fn else coroutine.create(fn)
		V.managed[co] = true
		resume(co, ...)
		return co
	end

	function V.defer(fn, ...)
		local co = if type(fn) == "thread" then fn else coroutine.create(fn)
		V.managed[co] = true
		schedule(V.time, co, ...)
		return co
	end

	function V.delay(seconds, fn, ...)
		local co = coroutine.create(fn)
		V.managed[co] = true
		schedule(V.time + (seconds or 0), co, ...)
		return co
	end

	function V.wait(seconds)
		seconds = math.max(seconds or 0, 0.001)
		local co = coroutine.running()
		if not V.managed[co] then
			V.time += seconds
			return seconds
		end
		local started = V.time
		schedule(V.time + seconds, co)
		coroutine.yield()
		return V.time - started
	end

	function V.cancel() end

	-- Runs everything due up to now + dt, in time order.
	function V.advance(dt, onStep)
		local target = V.time + dt
		while true do
			local bestIndex, best = nil, nil
			for i, entry in V.queue do
				if entry.at <= target and (best == nil or entry.at < best.at) then
					bestIndex, best = i, entry
				end
			end
			if not best then
				break
			end
			table.remove(V.queue, bestIndex)
			V.time = math.max(V.time, best.at)
			if coroutine.status(best.co) == "suspended" then
				resume(best.co, table.unpack(best.args, 1, best.args.n))
			end
			if onStep then
				onStep()
			end
		end
		V.time = target
	end

	return V
end

return VirtualTask
