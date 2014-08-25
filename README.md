ComputerCraft-EventLoop
=======================

An implementation of an Event Loop for ComputerCraft. Provides an interface similar to Node.js's EventEmitter and ```setTimeout()```.

ComputerCraft-EventLoop is an API for Event-driven programming in ComputerCraft Lua that eliminates the need to create your own ```while true do ... end``` loop

## Usage ##

An example program using ComputerCraft-EventLoop looks like this:

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

**Returns** the [EventLoop](#EventLoop) instance.

### ```EventLoop``` ###

#### ```EventLoop:run([function])``` ####

Starts the event loop and executes the given function.

#### ```EventLoop:timeout([time], function)``` ####

Starts a timer that executes the function after time seconds, defaulting to 0 seconds.
**Returns** an id number that can be used to [cancel](#) the timeout.

#### ```EventLoop:interval([time], function)``` ####

Starts a timer that executes the function every time seconds, defaulting to 1 second.
**Returns** an id number that can be used to [cancel](#) the interval.
