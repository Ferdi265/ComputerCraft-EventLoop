ComputerCraft-EventLoop
=======================

An implementation of an Event Loop for ComputerCraft that provides an interface similar to Node.js's EventEmitter and ```setTimeout()```.

ComputerCraft-EventLoop is an API for Event-driven programming in ComputerCraft Lua that eliminates the need to create your own loop to capture events.

## Current Version ##

ComputerCraft-EventLoop is currently at version 1.3.1

## Installation ##

To install this program via pastebin, run

```pastebin get xpE2SeZ0 eventloop```

or go to http://pastebin.com/xpE2SeZ0

## Usage ##

A program using ComputerCraft-EventLoop may look like this:

```lua
os.loadAPI('eventloop') --load the ComputerCraft-EventLoop API

local loop = eventloop.create() --get an EventLoop instance

loop:run(function () --run a function in the event loop
  print('I\'m in an event loop!')
  
  loop:timeout(2, function ()
    print('This will happen 2 seconds later.')
  end)
  
  loop:interval(1, function ()
    print('This will happen every second!')
  end)
  
  loop:on('char', 's', function ()
    print('You pressed s!')
  end)
  
  loop:timeout(6, function ()
    print('Goodbye') 
    loop:terminate() --stop the loop after 6 seconds
  end)
end)
```

Example output:

<img src="http://i.imgur.com/Vx4pxON.png">

## API Documentation ##

### ```eventloop.create()``` ###

> **Returns** the [EventLoop](#eventloop) instance.

### ```EventLoop``` ###

#### ```EventLoop:run([function])``` ####

> Starts the event loop and executes the given function.
  This function will return once there are no more events to handle or the [EventLoop](#eventloop) is [terminated](#eventloopterminate).

> Example:

> ```lua
  loop:run(function () --start the loop
    loop:run(function () --calling run a second time doesn't create a second loop.
      --it's equivalent to EventLoop:timeout(0, function) if called while an event loop is running.
      print('Inner loop?')
    end)
  end)
  ```

> **Returns** the [EventLoop](#eventloop) instance.

#### ```EventLoop:running()``` ####

> **Returns** ```true``` if the [EventLoop](#eventloop) is running, ```false``` otherwise.

#### ```EventLoop:reset()``` ####

> Removes all listeners and fired custom events from the [EventLoop](#eventloop).

> **Returns** the [EventLoop](#eventloop) instance.

#### ```EventLoop:timeout([time], function)``` ####

> Starts a timer that executes the function after time seconds, defaulting to 0 seconds.

> Example:

> ```lua
  print('Shutting down')
  loop:timeout(1, function () --leave time for people to read the message
    os.shutdown()
  end)
  ```

> **Returns** an id number that can be used to [cancel](#eventloopcancelid) the timeout.

#### ```EventLoop:interval([time], function)``` ####

> Starts a timer that executes the function every time seconds, defaulting to 1 second.

> Example:

> ```lua
  print('send message to computer 2 regularly')
  loop:interval(1, function ()
    rednet.send(2, 'still running')
  end)
  ```

> **Returns** an id number that can be used to [cancel](#eventloopcancelid) the interval.

#### ```EventLoop:cancel(id)``` ####

> Cancels the [timeout](#eventlooptimeouttime-function) or [interval](#eventloopintervaltime-function) with the given id.

> Example:

> ```lua
  print('send message to computer 2 regularly')
  local heartBeatId = loop:interval(1, function ()
    rednet.send(2, 'still running')
  end)
  loop:once('rednet_message', 2, function (msg) --when receiving a message from 2
    if msg == 'stop' then --and the text is 'stop'
      loop:cancel(heartBeatId) --stop the heartbeat 
    end
  end)
  ```

> **Returns** the [EventLoop](#eventloop) instance.

#### ```EventLoop:on([eventType, [parameters...]], function)``` ####

> Registers an Event Listener for the given event type. The function will be called every time the event is fired and the given parameters match.
  The function will be called with the additinal event parameters as arguments.

> Additional event parameters are all the parameters of the event that you did not specify.
  i.e. if you want to handle only left clicks, you can specify the ```button``` parameter as ```1```, and receive only the ```x``` and ```y``` parameters as the button parameter would always be ```1```.

> If no type is given, the function will be called for every event, regardless of type. Such Event Listeners will have the event type as the first argument.

> **Returns** the [EventLoop](#eventloop) instance.

> Example:

> ```lua
  loop:on('mouse_click', 1, function (x, y)
    print('X-Pos: ' .. x .. ', Y-Pos: ' .. y)
  end)
  ```

> ##### ```terminate``` Events #####

> When ComputerCraft-EventLoop receives a ```terminate``` Event, the loop will automatically be terminated forcefully.
  If there is an Event Listener for ```terminate```, the loop will continue as usual and will *not* be terminated.

> ##### ```error``` Events #####

> When an Event Listener errors, ComputerCraft-EventLoop will fire an ```error``` event. If there is no Event Listener for the ```error``` event, the loop will be terminated with an error message. An ```error``` Listener will receive the error message as the first argument.

#### ```EventLoop:once([eventType, [parameters...]], function)``` ####

> Same as [on](#eventlooponeventtype-parameters-function), except that the Event Listener is removed after the event is fired the first time. (i.e. the listener is only called once)

> Example:

> ```lua
  loop:once('terminate', function ()
    print('shutting down')
    os.shutdown()
  end)
  ```

> **Returns** the [EventLoop](#eventloop) instance.

#### ```EventLoop:off([eventType], [function])``` ####

> Removes the specified event listener for the given event type.
  If no type is given, removes the specified 'any event' Listener.
  If no function is given, removes all Event Eisteners for that type.
  If called without arguments, removes all Listeners.

> Example:

> ```lua
  loop:on('rednet_message', 2, function (msg)
    print('2 said: ', msg)
  end)
  loop:on('char', 'q', function ()
    loop:off('rednet_message')
  end)
  ```

> **Returns** the [EventLoop](#eventloop) instance.

#### ```EventLoop:fire(eventType, [parameters...])``` ####

> Fires the specified custom event with the given parameters.
  The only difference to standard computercraft events is, that these events can have more than 5 parameters.

> Example:

> ```lua
  loop:on('noFuel', function ()
    local slot = turtle.getSelectedSlot()
    turtle.select(1)
    turtle.refuel()
    turtle.select(slot)
  end)
  function checkFuel()
    if turtle.getFuelLevel() == 0 then
      loop:fire('noFuel')
    end
  end
  ```

> **Returns** the [EventLoop](#eventloop) instance.

#### ```EventLoop:defer(<time | [eventType, [parameters...]]>)``` ####

> Defers execution of the current timeout or event handler. During waiting time, other event handlers may be called.

> Example:

> ```lua
  print('Press k!')
  while true do
    local key = loop:defer('char')
    if key == 'k' then
      print('Correct!')
      break
    else
      print('Incorrect, try again.')
    end
  end
  print('Goodbye')
  loop:defer(1) --leave time to read the message
  os.shutdown()
  ```
  
> **Returns** ```nil``` when called with time, and the additional event parameters when called with event parameters

#### ```EventLoop:listeners([eventType, [parameters...]])``` ####

> Creates a list of listeners that listen for the given eventType and parameters.

> The list is returned in this format:

> ```lua
  {
    filter = <filter table>,
    fn = <function or coroutine>,
    type = <'on', 'once', 'deferred', or 'native'>
  }
  ```

> **Returns** the list of listeners

#### ```EventLoop:terminate()``` ####

> Forces the loop to terminate after the current iteration.
  Event Listeners for the currently handled event will still be executed, but no further events will be handled.

> ```lua
  local count = 0
  loop:on('terminate', function ()
    count = count + 1
    if count == 2 then
      loop:terminate()
    else
      print('Try again.')
    end
  end)
  ```

> **Returns** the [EventLoop](#eventloop) instance.

