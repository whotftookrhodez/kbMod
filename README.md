# kbMod
a simple, strictly typed luau keybind module built on top of Roblox’s ContextActionService

## it provides:
action to input mapping,
enable/disable per action,
dynamic rebinding,
multiple inputs per action,
change event for listener sync,
optional touch button support for mobile

## types

### actionName
```luau
type actionName = string
```

### input
```luau
type input = Enum.KeyCode | Enum.UserInputType
```

#### examples
```luau
Enum.KeyCode.Shift
Enum.UserInputType.MouseButton1
Enum.KeyCode.ButtonA
```

### actionState
```luau
type actionState = Enum.UserInputState
```

### actionCallback
```luau
(
    action: actionName,
    state: Enum.UserInputState,
    input: InputObject,
    gameProcessedEvent: boolean
) -> Enum.ContextActionResult
```

### bindOptions
```luau
{
    sinkProcessed: boolean?,
    createTouchButton: boolean?,
    touchButtonPosition: UDim2?,
    touchButtonImage: string?,
    touchButtonTitle: string?
}
```

### bind
```luau
{
    name: string,
    inputs: {input},
    enabled: boolean,
    callback: actionCallback,
    options: bindOptions
}
```

### constructor
```luau
keybinds.new(): keybinds
```

#### example
```luau
local keybinds = require(path.to.module)

local binds = keybinds.new()
```

## api reference

```luau
### :bind(action, inputs, callback, options?): bind
```
creates or replaces a bind

#### examples

##### 1
```luau
binds:bind(
    "sprint",
    Enum.KeyCode.Shift,
    function(action, state)
        if state == Enum.UserInputState.Begin then
            print("sprint down")
        end
        
        return Enum.ContextActionResult.Sink
    end
)
```

##### 2
```luau
binds:bind(
    "interact",
    {Enum.KeyCode.F, Enum.KeyCode.ButtonX},
    callback
)
```

```luau
:unbind(action): boolean
```
removes a bind, returns false if action did not exist

#### example
```luau
binds:unbind("sprint")
```

```luau
:has(action): boolean
```
returns whether a bind exists

```luau
:get(action): bind?
```
returns the bind object if it exists

```luau
:setenabled(action, enabled): boolean
```
enables or disables an action without unbinding

#### example
```luau
binds:setenabled("Jump", false)
```
-> callback will not fire, input will pass through

```luau
:setCallback(action, callback): boolean
```
replaces the callback at runtime

```luau
:setInputs(action, inputs): boolean
```
replaces all inputs for an action -> unbinds from ContextActionService, rebinds with new inputs

```luau
:addInput(action, input): boolean
```
adds a new input to an action if not already present

```luau
:removeInput(action, input): boolean
```
removes a specific input from an action

```luau
:clear()
```
unbinds all actions and clears the registry

### change event
```luau
:changed(): changedEvent
```
-> returns a custom event object -> bind will be nil if action was unbound

#### example:
```luau
local disconnect = binds:changed():Connect(function(action, bind)
    print("bind changed: " .. action .. ", " .. bind)
end)
```

returns a disconnect function:
```luau
disconnect()
```
