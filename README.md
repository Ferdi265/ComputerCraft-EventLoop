ComputerCraft-EventLoop
=======================

An implementation of an Event Loop for ComputerCraft that provides an interface similar to Node.js's EventEmitter and ```setTimeout()```.

ComputerCraft-EventLoop is an API for Event-driven programming in ComputerCraft Lua that eliminates the need to create your own loop to capture events.

## Installation ##

To install this package via pastebin, run

```pastebin get DJVaDmaA eventloop```

or go to http://pastebin.com/DJVaDmaA

## Usage ##

A program using ComputerCraft-EventLoop may look like this:

```
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
  
  loop:on('char', function (char)
    if char == 's' then
      print('You pressed s!')
    end
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

> **Returns** the [EventLoop](#EventLoop) instance.

### ```EventLoop``` ###

#### ```EventLoop:run([function])``` ####

> Starts the event loop and executes the given function.
  This function will return once there are no more events to handle or the [EventLoop](#EventLoop) is [terminated](#EventLoopTerminate).

> **Returns** the [EventLoop](#EventLoop) instance.

#### ```EventLoop:timeout([time], function)``` ####

> Starts a timer that executes the function after time seconds, defaulting to 0 seconds.

> **Returns** an id number that can be used to [cancel](#EventLoopCancelId) the timeout.

#### ```EventLoop:interval([time], function)``` ####

> Starts a timer that executes the function every time seconds, defaulting to 1 second.

> **Returns** an id number that can be used to [cancel](#EventLoopCancelId) the interval.

#### ```EventLoop:cancel(id)``` ####

> Cancels the [timeout](#EventLoopTimeoutTime-Function) or [interval](#EventLoopIntervalTime-Function) with the given id.

> **Returns** the [EventLoop](#EventLoop) instance.

#### ```EventLoop:on([eventType], function)``` ####

> Registers an Event Listener for the given event type. The function will be called every time the event is fired.
  The function will be called with the event parameters as arguments.
  If no type is given, the function will be called for every event, regardless of type. Such Event Listeners will have the event type as the first argument.

> **Returns** the [EventLoop](#EventLoop) instance.

> Example:

> ```
  loop:on('mouse_click', function (button, x, y)
    local button_name = 'left'
    if button == 2 then
      button_name = 'right'
    end
    print('You clicked the ' .. button_name .. ' mouse button!')
    print('X-Pos: ' .. x .. ', Y-Pos: ' .. y)
  end)
  ```

> ##### ```terminate``` Events #####

> When ComputerCraft-EventLoop receives a ```terminate``` Event, the loop will automatically be terminated forcefully.
  If there is an Event Listener for ```terminate```, the loop will continue as usual and will *not* be terminated.

#### ```EventLoop:once([eventType], function)``` ####

> Same as [on](#EventLoopOnEventType-function), except that the Event Listener is removed after the event is fired the first time. (i.e. the listener is only called once)

> **Returns** the [EventLoop](#EventLoop) instance.

#### ```EventLoop:off([eventType], [function])``` ####

> Removes the specified event listener for the given event type.
  If no type is given, removes the specified 'any event' Listener.
  If no function is given, removes all Event Eisteners for that type.
  If called without arguments, removes all Listeners.

> **Returns** the [EventLoop](#EventLoop) instance.

#### ```EventLoop:fire([eventType], [parameters...])``` ####

> Fires the specified custom event with the given parameters.
  The only difference to standard computercraft events is, that these events can have more than 5 parameters.

> **Returns** the [EventLoop](#EventLoop) instance.

#### ```EventLoop:terminate()``` ####

> Forces the loop to terminate after the current iteration.
  Event Listeners for the currently handled event will still be executed, but no further events will be handled.
  
> **Returns** the [EventLoop](#EventLoop) instance.
