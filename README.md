# kbMod
a simple, strictly typed luau keybind module built on top of Roblox’s ContextActionService

## it provides:
action to input mapping
enable/disable per action
dynamic rebinding
multiple inputs per action
change event for listener sync
optional touch button support for mobile

## types

### actionName
type actionName = string

### input
type input = Enum.KeyCode | Enum.UserInputType

#### examples
Enum.KeyCode.Shift
Enum.UserInputType.MouseButton1
Enum.KeyCode.ButtonA

### actionState
type actionState = Enum.UserInputState

### actionCallback
(
    action: actionName,
    state: Enum.UserInputState,
    input: InputObject,
    gameProcessedEvent: boolean
) -> Enum.ContextActionResult

### bindOptions
{
    sinkProcessed: boolean?,
    createTouchButton: boolean?,
    touchButtonPosition: UDim2?,
    touchButtonImage: string?,
    touchButtonTitle: string?
}

### bind
{
    name: string,
    inputs: {input},
    enabled: boolean,
    callback: actionCallback,
    options: bindOptions
}

### constructor
keybinds.new(): keybinds

#### example
local keybinds = require(path.to.module)

local binds = keybinds.new()

## api reference

### :bind(action, inputs, callback, options?): bind
creates or replaces a bind

#### examples

##### 1
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

##### 2
binds:bind(
    "interact",
    {Enum.KeyCode.F, Enum.KeyCode.ButtonX},
    callback
)

### :unbind(action): boolean
removes a bind, returns false if action did not exist

#### example
binds:unbind("sprint")

### :has(action): boolean
returns whether a bind exists

### :get(action): bind?
returns the bind object if it exists

### :setenabled(action, enabled): boolean
enables or disables an action without unbinding

#### example
binds:setenabled("Jump", false) -> callback will not fire, input will pass through

### :setCallback(action, callback): boolean
replaces the callback at runtime

### :setInputs(action, inputs): boolean
replaces all inputs for an action -> unbinds from ContextActionService, rebinds with new inputs

### :addInput(action, input): boolean
adds a new input to an action if not already present

### :removeInput(action, input): boolean
removes a specific input from an action

### :clear()
unbinds all actions and clears the registry

### change event
:changed(): changedEvent -> returns a custom event object

#### example:
local disconnect = binds:changed():Connect(function(action, bind)
    print("bind changed: " .. action .. ", " .. bind)
end) -> bind will be nil if action was unbound

returns a disconnect function: disconnect()
