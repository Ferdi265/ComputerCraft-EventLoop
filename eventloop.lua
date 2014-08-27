----Locals
--Functions
local numkeys = function (table)
	local keys = 0
	for k in pairs(table) do
		keys = keys + 1
	end
	return keys
end
local pack = function (tbl)
	local length = 0
	for k, v in pairs(tbl) do
		if type(k) == 'number' then
			if k > length then
				length = k
			end
		end
	end
	local freeIndex
	for i = 1, length do
		if freeIndex and tbl[i] then
			tbl[freeIndex] = tbl[i]
			tbl[i] = nil
			freeIndex = freeIndex + 1
		elseif not (freeIndex or tbl[i]) then
			freeIndex = i
		end
	end
	return tbl
end
local compare = function (template, tbl)
	for i, val in ipairs(template) do
		if val ~= tbl[i] then
			return false
		end
	end
	return true
end
local slice = function (tbl, startIndex, endIndex)
	local copy = {}
	local copyIndex = 1
	if not startIndex then
		startIndex = 1
	end
	if not endIndex then
		endIndex = #tbl
	end
	for i = startIndex, endIndex do
		copy[copyIndex] = tbl[i]
		copyIndex = copyIndex + 1
	end
	return copy
end
--Variables
local private = {
	eventListeners = {},
	timeouts = {},
	fired = {},
	running = false,
	handle = function (self, event)
		local listenerCalled = false
		for i, listener in ipairs(private.eventListeners) do
			if listener then
				if listener and ((listener.type and event[1] == 'terminate') or compare(listener.filter, event)) then
					if type(listener.fn) == 'function' then
						table.insert(private.eventListeners, i + 1, {
							filter = listener.filter,
							fn = coroutine.create(listener.fn),
							type = 'once'
						})
					else
						listenerCalled = true
						local args
						if listener.type == 'native' then
							args = event
						else
							args = slice(event, #listener.filter + 1)
						end
						listener.filter = {nil}
						local res = {coroutine.resume(listener.fn, unpack(args))}
						if res[1] then
							if type(res[2]) == 'table' then
								listener.filter = res[2]
								listener.type = 'deferred'
							elseif coroutine.status(listener.fn) ~= 'dead' then
								listener.filter = slice(res, 2)
								listener.type = 'native'
							end
						else
							self:fire('error', res[2])
						end
						if coroutine.status(listener.fn) == 'dead' then
							self:remove(listener.fn)
						end
						if self.exit then
							break
						end
					end
				end
			end
		end
		pack(private.eventListeners)
		if not listenerCalled then
			if event[1] == 'terminate' then
				error('Terminated', 0)
			elseif event[1] == 'error' then
				error('Error in listener: ' .. event[2], 0)
			end
		end
		return self
	end
}
local EventLoop = {
	run = function (self, fn)
		if fn then
			self:timeout(0, fn)
		end
		if not private.running then 
			private.running = true
			while true do
				if numkeys(private.eventListeners) > 0 and not self.exit then
					local event
					if private.fired[1] then
						event = table.remove(private.fired, 1)
					else
						event = {coroutine.yield()}
					end
					private.handle(self, event)
				else
					break
				end
			end
			private.running = false
			self:reset()
		end
		return self
	end,
	running = function (self)
		return private.running
	end,
	reset = function (self)
		private.eventListeners = {}
		private.timeouts = {}
		private.fired = {}
		return self
	end,
	interval = function (self, time, fn)
		if not fn then
			fn = time
			time = 0
		end
		local id = os.startTimer(time)
		private.timeouts[id] = fn
		table.insert(private.eventListeners, {
			filter = {'timer'},
			fn = function (timerId)
				if id == timerId then
					id = os.startTimer(time)
					fn()
				end
			end,
			type = 'on'
		})
		return id
	end,
	timeout = function (self, time, fn)
		if not fn then
			fn = time
			time = 0
		end
		local id = os.startTimer(time)
		private.timeouts[id] = fn
		self:once('timer', id, fn)
		return id
	end,
	on = function (self, ...)
		local filter = {...}
		if #filter < 1 then
			error('cannot register event without callback')
		end
		local fn = table.remove(filter)
		table.insert(private.eventListeners, {
			filter = filter,
			fn = fn,
			type = 'on'
		})
		return self
	end,
	once = function (self, ...)
		local filter = {...}
		if #filter < 1 then
			error('cannot register event without callback')
		end
		local fn = table.remove(filter)
		table.insert(private.eventListeners, {
			filter = filter,
			fn = coroutine.create(fn),
			native = 'once'
		})
		return self
	end,
	fire = function (self, type, ...)
		table.insert(private.fired, {type, ...})
		return self
	end,
	cancel = function (self, id)
		if private.timeouts[id] then
			self:off('timer', private.timeouts[id])
		end
		return self
	end,
	off = function (self, eventType, fn)
		if not fn and type(eventType) == 'function' then
			fn = eventType
			eventType = nil
		end
		for i, listener in ipairs(private.eventListeners) do
			if listener and (listener.filter[1] == eventType or not eventType) and (listener.fn == fn or not fn) then
				private.eventListeners[i] = nil
			end
		end
		return self
	end,
	listeners = function (self, ...)
		local filter = {...}
		local list = {}
		for i, listener in ipairs(private.eventListeners) do
			if listener and compare(filter, listener.filter) then
				table.insert(list, listener)
			end
		end
		return list
	end,
	defer = function (self, ...)
		local args = {...}
		if type(args[1]) == 'number' then
			local id = os.startTimer(args[1])
			coroutine.yield({'timer', id})
		else
			return coroutine.yield(args)
		end
	end,
	terminate = function (self)
		self.exit = true
		return self
	end
}
----Globals
--Functions
create = function ()
	return EventLoop
end