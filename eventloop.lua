----Locals
--Functions
local numkeys = function (table)
	--//Returns the number of keys in a table
	local keys = 0
	for k in pairs(table) do
		keys = keys + 1
	end
	return keys
end
--Proto Library (Inlined)
local extend = function (target, ...)
	--//copies the specified tables into the target table
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
	--//extends a given prototype with the rest arguments
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
	--//instantiates a given prototype and calls init with the rest arguments
	Proto = Proto or {}
	local args = {...}
	local instance = {}
	setmetatable(instance, {__index = Proto})
	if instance.init then
		instance:init(unpack(args))
	end
	return instance
end
--Variables
local instance --//the singleton instance for the event loop
--Protos
local EventLoop = proto({
	--//the EventLoop prototype
	--//adds methods for evented programming similar to Node.js EventEmitters and setTimeout
	--//
	--//overrides os.pullEventRaw to capture events pulled during event handler execution
	init = function (self)
		self.typeListeners = {} --//event listeners listening for a specific type of event
		self.listeners = {} --//event listeners listening for any event
		self.timeouts = {} --//saves timeout ids for the timeout and interval methods
		self.fired = {} --//contains custom fired events
		self.events = {} --//contains events pulled during handler execution
		self.running = false --//saves state of EventLoop
		self.nativePullEventRaw = os.pullEventRaw --//save unmodified pullEventRaw
		self.redirectedPullEventRaw = function (filter)
			--//returns the first fired custom event or pulls an Event
			--//captured events are then forwarded to the events table
			local event = {}
			repeat
				if self.fired[1] then
					event = self.fired[1]
					table.remove(self.fired, 1)
					table.insert(self.events, event)
				else
					os.pullEventRaw = self.nativePullEventRaw --//calls to the native pullEventRaw somehow call os.pullEventRaw sometimes
					--//reset redirection temporarily to prevent event duplication
					event = {self.nativePullEventRaw()}
					os.pullEventRaw = self.redirectedPullEventRaw --//re-add redirection
					table.insert(self.events, event)
				end
			until event[1] == filter or not filter
			return unpack(event)
		end
		return self
	end,
	run = function (self, fn)
		--//starts the EventLoop
		--//executes the given function immediately
		self:init() --//re-initialize
		if fn then
			self:timeout(0, fn) --//execute function immediately after events are handled
		end
		if not self.running then --//prevent multiple loops at the same time
			self.running = true
			os.pullEventRaw = self.redirectedPullEventRaw --//redirect events
			while true do --//actual event loop
				if numkeys(self.typeListeners) + #self.listeners > 0 and not self.exit then
					--//if there are listeners waiting for events and the loop is not asked to terminate
					self:handle(self:event()) --//handle the next event
				else
					--//else break event loop
					break
				end
			end
			os.pullEventRaw = self.nativePullEventRaw --//reset event redirection
			self.running = false
		end
		return self
	end,
	event = function (self)
		--//returns the next processed event
		--//if that doesn't exists, consume fired custom event or pull event
		local event
		if self.events[1] then
			event = self.events[1]
			table.remove(self.events, 1)
		elseif self.fired[1] then
			event = self.fired[1]
			table.remove(self.fired, 1)
		else
			os.pullEventRaw = self.nativePullEventRaw --//calls to the native pullEventRaw somehow call os.pullEventRaw sometimes
			--//reset redirection temporarily to prevent event duplication
			event = {self.nativePullEventRaw()}
			os.pullEventRaw = self.redirectedPullEventRaw --//re-add redirection
		end
		local type = event[1]
		table.remove(event, 1)
		return {
			type = type,
			args = event
		}
	end,
	handle = function (self, event)
		--//calls all listeners listening for this event
		local callListener = function (listener, ...)
			--//calls the listener and handles error state
			local args = {...}
			local ok, err = pcall(function ()
				listener(unpack(args))
			end)
			if not ok  then
				if self.typeListeners['error'] and #self.typeListeners['error'] > 0 and event.type ~= 'error' then
					--//if there are an error listeners, call them
					--//except if the error came from an error listener
					self:handle({
						type = 'error',
						args = {err}
					})
				else
					--//else, propagate error
					error(err, 0)
				end
			end
		end
		if event.type ~= 'error' then
			--//call 'any event' listeners if the event is not an error
			for i, fn in ipairs(self.listeners) do
				callListener(fn, event.type, unpack(event.args))
			end
		end
		if self.typeListeners[event.type] then
			--//if there are listeners for type
			for i, fn in ipairs(self.typeListeners[event.type]) do
				--//call them
				callListener(fn, unpack(event.args))
			end
		elseif event.type == 'terminate' then
			--//if there are no listeners for 'terminate'
			--//do default pullEvent behaviour and terminate the loop
			error('Terminated', 0)
		end
		return self
	end,
	timeout = function (self, time, fn)
		--//executes a function after time seconds
		--//accepts fractions of a second, up to a game tick
		--//this is a once listener, it removes itself upon execution
		--//returns an id used to cancel the execution
		if not fn then
			fn = time
			time = 0
		end
		local id = os.startTimer(time)
		local listener
		listener = function (timerId)
			if timerId == id then
				self:off('timer', listener)
				self.timeouts[id] = nil
				fn()
			end
		end
		self.timeouts[id] = listener
		self:on('timer', listener)
		return id
	end,
	interval = function (self, time, fn)
		--//executes a function once every time seconds
		--//accepts fractions of a second, up to a game tick
		--//returns an id used to cancel all future executions
		if not fn then
			fn = time
			time = 1
		end
		local id = os.startTimer(time)
		local listener
		listener = function (timerId)
			if timerId == id then
				id = os.startTimer(time)
				fn()
			end
		end
		self.timeouts[id] = listener
		self:on('timer', listener)
		return id
	end,
	cancel = function (self, id)
		--//cancels a timeout or interval
		if self.timeouts[id] then
			self:off('timer', self.timeouts[id])
			self.timeouts[id] = nil
		end
		return self
	end,
	fire = function (self, type, ...)
		--//fires a custom event with the given type and arguments
		table.insert(self.fired, {type, ...})
		return self
	end,
	on = function (self, type, fn)
		--//registers an event listener for type or an event listener for any type if no type was given
		if not fn then
			fn = type
			type = nil
		end
		if type then
			if not self.typeListeners[type] then
				self.typeListeners[type] = {}
			end
			table.insert(self.typeListeners[type], fn)
		else
			table.insert(self.listeners, fn)
		end
		return self 
	end,
	once = function (self, type, fn)
		--//registers an event listener for type or an event listener for any type if no type was given
		--//this is a once listener, it removes itself upon execution
		if not fn then
			fn = type
			type = nil
		end
		local listener
		listener = function (...)
			if type then
				self:off(type, listener)
			else
				self:off(listener)
			end
			fn(...)
		end
		if type then
			self:on(type, listener)
		else
			self:on(listener)
		end
	end,
	off = function (self, eventType, fn)
		--//removes the specified listener for eventType or the specified 'any event' listener
		--//alternatively, removes all listeners for eventType or all listeners
		if not fn then
			if type(eventType) == 'function' then
				fn = eventType
				eventType = nil
			end
		end
		if eventType then
			if self.typeListeners[eventType] then
				if fn then
					for i, listener in ipairs(self.typeListeners[eventType]) do
						if listener == fn then
							table.remove(self.typeListeners[eventType], i)
							break
						end
					end
				end
				if #self.typeListeners[eventType] == 0 or not fn then
					self.typeListeners[eventType] = nil
				end
			end
		else
			if fn then
				for i, listener in ipairs(self.listeners) do
					if listener == fn then
						table.remove(self.listeners, i)
						break
					end
				end
			end
			if #self.listeners == 0 or not fn then
				self.listeners = {}
			end
		end
		return self
	end,
	terminate = function (self)
		--//forces the loop to terminate after the current iteration
		--//listeners for the current event will still be executed, but no further events will be handled
		self.exit = true
	end
})
----Globals
--Functions
create = function ()
	--//returns the EventLoop instance
	if not instance then
		instance = inst(EventLoop)
	end
	return instance
end