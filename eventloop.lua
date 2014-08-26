----Locals
--Functions
local numkeys = function (table)
	local keys = 0
	for k in pairs(table) do
		keys = keys + 1
	end
	return keys
end
--Proto Library (Inlined)
local extend = function (target, ...)
	target = target or {}
	local sources = {...}
	for index, source in ipairs(sources) do
		for key, value in pairs(source) do
			target[key] = source[key]
		end
	end
	return target
end
local proto = function (Proto, ...)
	Proto = Proto or {}
	local sources = {...}
	if #sources == 0 then
		table.insert(sources, Proto)
		Proto = {}
	end
	local instance = {}
	setmetatable(instance, {__index = Proto})
	return extend(instance, unpack(sources))
end
local inst = function (Proto, ...)
	Proto = Proto or {}
	local args = {...}
	local instance = {}
	setmetatable(instance, {__index = Proto})
	if instance.init then
		instance:init(unpack(args))
	end
	return instance
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
local instance
--Protos
local EventLoop = proto({
	init = function (self)
		self.listeners = {}
		self.fired = {} 
		self.running = false 
		return self
	end,
	run = function (self, fn)
		if fn then
			self:timeout(0, fn)
		end
		if not self.running then 
			self.running = true
			self:init()
			while true do 
				if numkeys(self.listeners) > 0 and not self.exit then
					local event
					if self.fired[1] then
						event = table.remove(self.fired, 1)
					else
						event = {coroutine.yield()}
					end
					self:handle(event)
				else
					break
				end
			end
			self.running = false
		end
		return self
	end,
	handle = function (self, event)
		local listenerCalled = false
		for i, listener in ipairs(self.listeners) do
			if listener and compare(listener.filter, event) then
				if type(listener.run) == 'function' then
					table.insert(self.listeners, i + 1, {
						filter = event,
						run = coroutine.create(listener.run),
						id = listener.run
					})
				elseif coroutine.status(listener.run) == 'dead' then
					self:off(event[1], listener.id)
				else
					listenerCalled = true
					local args
					if listener.fullArgs then
						args = event
					else
						args = slice(event, #listener.filter + 1)
					end
					local res = {coroutine.resume(listener.run, unpack(args))}
					if res[1] then
						if type(res[2]) == 'table' then
							listener.filter = res[2]
							listener.fullArgs = false
						else
							listener.filter = slice(res, 2)
							listener.fullArgs = true
						end
					else
						error(res[2], 0)
					end
				end
			end
		end
		pack(self.listeners)
		if not listenerCalled and event[1] == 'terminate' then
			error('Terminated', 0)
		end
		return self
	end,
	interval = function (self, time, fn)
		if not fn then
			fn = time
			time = 0
		end
		local id = os.startTimer(time)
		self:on('timer', id, fn)
		return self
	end,
	timeout = function (self, time, fn)
		if not fn then
			fn = time
			time = 0
		end
		local id = os.startTimer(time)
		self:once('timer', id, fn)
		return self
	end,
	on = function (self, ...)
		local filter = {...}
		if #filter < 1 then
			error('cannot register event without callback')
		end
		local fn = table.remove(filter)
		table.insert(self.listeners, {
			filter = filter,
			run = fn,
			id = fn,
			fullArgs = false
		})
		return self
	end,
	once = function (self, ...)
		local filter = {...}
		if #filter < 1 then
			error('cannot register event without callback')
		end
		local fn = table.remove(filter)
		table.insert(self.listeners, {
			filter = filter,
			run = coroutine.create(fn),
			id = fn,
			fullArgs = false
		})
		return self
	end,
	fire = function (self, type, ...)
		table.insert(self.fired, {type, ...})
		return self
	end,
	off = function (self, eventType, fn)
		if not fn and type(eventType) == 'function' then
			fn = eventType
			eventType = nil
		end
		for i, listener in ipairs(self.listeners) do
			if listener and (listener.filter[1] == eventType or not eventType) and (listener.id == fn or not fn) then
				self.listeners[i] = nil
			end
		end
		return self
	end,
	terminate = function (self)
		self.exit = true
		return self
	end
})
----Globals
--Functions
create = function ()
	if not instance then
		instance = inst(EventLoop)
	end
	return instance
end