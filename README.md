# kbMod

a simple, strictly typed luau keybind module built on top of Roblox’s ContextActionService and UserInputService

## it provides:

action to input mapping,
key, mouse, touch & gamepad binds,
chords,
multiple inputs or chords per action,
groups,
enable/disable per action,
enable/disable per group,
dynamic, chord-compatible rebinding,
change event for listener sync,
optional custom touch button support for mobile,
ContextActionService priority support,
typing and processed-input control,
held input/action state helpers,
conflict detection,
string-safe & full serialization,
and safe cleaning

## basic setup

```luau
local keybinds = require(path.to.kbMod)

local binds = keybinds.new()
```

## types

### actionName

```luau
type actionName = string
```

### groupName

```luau
type groupName = string
```

### input

```luau
type input = Enum.KeyCode | Enum.UserInputType
```

#### examples

```luau
Enum.KeyCode.LeftShift
Enum.UserInputType.MouseButton1
Enum.KeyCode.ButtonA
Enum.UserInputType.Touch
```

### chord

```luau
type chord = {
	kind: "chord",
	inputs: {input}
}
```

chords require multiple inputs to be held at once

#### example

```luau
local dashChord = keybinds.chord({
	Enum.KeyCode.LeftShift,
	Enum.KeyCode.Q
})
```

### trigger

```luau
type trigger = input | chord
```

actions can be bound to one input, one chord, or a mixed array of inputs and chords

#### example

```luau
binds:bind(
	"dash",
	{
		Enum.KeyCode.ButtonB,
		keybinds.chord({
			Enum.KeyCode.LeftShift,
			Enum.KeyCode.Q
		})
	},
	callback
)
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

#### example

```luau
local function callback(action, state, inputObject, gameProcessedEvent)
	if state == Enum.UserInputState.Begin then
		print(action .. " began")
	elseif state == Enum.UserInputState.End then
		print(action .. " ended")
	end

	return Enum.ContextActionResult.Sink
end
```

### bindOptions

```luau
{
	sinkProcessed: boolean?,

	createTouchButton: boolean?,
	touchButtonPosition: UDim2?,
	touchButtonImage: string?,
	touchButtonTitle: string?,

	priority: number?,

	group: groupName?,
	groups: {groupName}?,

	allowWhileTyping: boolean?,
	chordTimeout: number?
}
```

#### sinkProcessed

```luau
sinkProcessed: boolean?
```

if true, callbacks can still run when Roblox marks the input as processed

(default behavior is to pass the processed input through)

#### createTouchButton

```luau
createTouchButton: boolean?
```

creates a ContextActionService touch button when true

#### touchButtonPosition

```luau
touchButtonPosition: UDim2?
```

sets the touch button position

#### touchButtonImage

```luau
touchButtonImage: string?
```

sets the touch button image

#### touchButtonTitle

```luau
touchButtonTitle: string?
```

sets the touch button title

#### priority

```luau
priority: number?
```

uses `ContextActionService:BindActionAtPriority` instead of `BindAction`.

#### group

```luau
group: groupName?
```

adds the bind to one group

#### groups

```luau
groups: {groupName}?
```

adds the bind to multiple groups

#### allowWhileTyping

```luau
allowWhileTyping: boolean?
```

if true, the bind can run while a TextBox is focused

(default behavior is to ignore binds while typing)

#### chordTimeout

```luau
chordTimeout: number?
```

maximum time, in seconds, between chord inputs being pressed; if nil or <= 0, chord input timing is ignored

#### example

```luau
binds:bind(
	"sprint",
	Enum.KeyCode.LeftShift,
	callback,
	{
		group = "gameplay",
		priority = 2000,
		createTouchButton = true,
		touchButtonPosition = UDim2.fromScale(0.8, 0.7),
		touchButtonImage = "rbxassetid://123456",
		touchButtonTitle = "sprint"
	}
)
```

### bind

```luau
{
	name: actionName,
	inputs: {trigger},
	enabled: boolean,
	callback: actionCallback,
	options: bindOptions,
	groups: {[groupName]: boolean}
}
```

### rebindOptions

```luau
{
	allowProcessed: boolean?,
	allowWhileTyping: boolean?,
	ignore: {input}?
}
```

used by `rebind` and `rebindChord`

#### example

```luau
binds:rebind(
	"sprint",
	function(newInput)
		print("sprint rebound to", newInput)
	end,
	{
		ignore = {Enum.KeyCode.R}
	}
)
```

### serializedTrigger

```luau
type serializedTrigger = string | {string}
```

normal inputs become strings, chords become arrays of strings

#### examples

```luau
"Enum.KeyCode.LeftShift"

{
	"Enum.KeyCode.LeftShift",
	"Enum.KeyCode.Q"
}
```

### serializedBind

```luau
{
	inputs: {serializedTrigger},
	enabled: boolean?,
	groups: {groupName}?
}
```

used by `serializeFull` and `loadFull`

## constructor

### new

```luau
keybinds.new(): keybinds
```

#### example

```luau
local keybinds = require(path.to.kbMod)

local binds = keybinds.new()
```

## static helpers

### chord

```luau
keybinds.chord(inputs: {input} | input): chord
```

creates a chord trigger

#### example

```luau
local trigger = keybinds.chord({
	Enum.KeyCode.LeftControl,
	Enum.KeyCode.F
})
```

### inputToString

```luau
keybinds.inputToString(input): string
```

converts an input to a string

#### example

```luau
local value = keybinds.inputToString(Enum.KeyCode.Space)
```

returns:

```luau
"Enum.KeyCode.Space"
```

### inputToText

```luau
keybinds.inputToText(input): string
```

converts an input to display text

#### example

```luau
local value = keybinds.inputToText(Enum.KeyCode.Space)
```

returns:

```luau
"Space"
```

### inputFromString

```luau
keybinds.inputFromString(value: string): input?
```

converts a string back into an input

#### example

```luau
local input = keybinds.inputFromString("Enum.KeyCode.Space")
```

### inputFromInputObject

```luau
keybinds.inputFromInputObject(inputObject: InputObject): input?
```

gets the KeyCode when present, otherwise gets the UserInputType

### triggerToText

```luau
keybinds.triggerToText(trigger): string
```

converts an input or chord to display text

#### example

```luau
local text = keybinds.triggerToText(
	keybinds.chord({
		Enum.KeyCode.LeftShift,
		Enum.KeyCode.Q
	})
)
```

returns:

```luau
"LeftShift + Q"
```

### triggerToString

```luau
keybinds.triggerToString(trigger): serializedTrigger
```

converts an input or chord to a string-safe value

### triggerFromString

```luau
keybinds.triggerFromString(trigger: serializedTrigger): trigger?
```

converts a string-safe value back into an input or chord

## api reference

### bind

```luau
:bind(action, inputs, callback, options?): bind
```

creates or replaces a bind

`inputs` can be:

```luau
input
chord
{input}
{chord}
{trigger}
```

#### example: one input

```luau
binds:bind(
	"sprint",
	Enum.KeyCode.LeftShift,
	function(action, state)
		if state == Enum.UserInputState.Begin then
			print("sprint down")
		end

		return Enum.ContextActionResult.Sink
	end
)
```

#### example: multiple inputs

```luau
binds:bind(
	"interact",
	{
		Enum.KeyCode.F,
		Enum.KeyCode.ButtonX
	},
	callback
)
```

#### example: mixed inputs and chords

```luau
binds:bind(
	"dash",
	{
		Enum.KeyCode.ButtonB,
		keybinds.chord({
			Enum.KeyCode.LeftShift,
			Enum.KeyCode.Q
		})
	},
	callback,
	{
		group = "gameplay",
		chordTimeout = 0.35
	}
)
```

### bindChord

```luau
:bindChord(action, inputs, callback, options?): bind
```

shortcut for binding an action to a chord

#### example

```luau
binds:bindChord(
	"dash",
	{
		Enum.KeyCode.LeftShift,
		Enum.KeyCode.Q
	},
	callback,
	{
		group = "gameplay",
		chordTimeout = 0.4
	}
)
```

### unbind

```luau
:unbind(action): boolean
```

removes a bind, returns false if the action did not exist

#### example

```luau
binds:unbind("sprint")
```

### unbindGroup

```luau
:unbindGroup(group): number
```

unbinds every action in a group, returns the number of actions removed

#### example

```luau
local removed = binds:unbindGroup("menu")
```

### has

```luau
:has(action): boolean
```

returns whether a bind exists

#### example

```luau
if binds:has("sprint") then
	print("sprint exists")
end
```

### get

```luau
:get(action): bind?
```

returns the bind object if it exists

#### example

```luau
local sprintBind = binds:get("sprint")
```

### setEnabled

```luau
:setEnabled(action, enabled): boolean
```

enables or disables an action without unbinding

#### example

```luau
binds:setEnabled("sprint", false)
```

(callback will not fire, and input will pass through)

### toggleEnabled

```luau
:toggleEnabled(action): boolean
```

toggles the enabled state of a bind, returns false if the action does not exist

#### example

```luau
binds:toggleEnabled("sprint")
```

### setAllEnabled

```luau
:setAllEnabled(enabled): ()
```

enables or disables every action

#### example

```luau
binds:setAllEnabled(false)
```

### isEnabled

```luau
:isEnabled(action): boolean
```

returns whether an action is currently enabled

(checks both the action and its groups)

#### example

```luau
if binds:isEnabled("sprint") then
	print("sprint is enabled")
end
```

returns false if the action does not exist

### setCallback

```luau
:setCallback(action, callback): boolean
```

replaces the callback at runtime

#### example

```luau
binds:setCallback("sprint", function(action, state)
	print(action, state)

	return Enum.ContextActionResult.Sink
end)
```

### setOptions

```luau
:setOptions(action, options): boolean
```

replaces the bind options at runtime

(also updates the bind groups from the new options)

#### example

```luau
binds:setOptions(
	"sprint",
	{
		group = "gameplay",
		priority = 3000
	}
)
```

### setInputs

```luau
:setInputs(action, inputs): boolean
```

replaces all inputs for an action

(unbinds from ContextActionService and rebinds with the new inputs)

#### example

```luau
binds:setInputs(
	"interact",
	{
		Enum.KeyCode.E,
		Enum.KeyCode.ButtonX
	}
)
```

### addInput

```luau
:addInput(action, trigger): boolean
```

adds a new input or chord to an action if not already present

#### example: input

```luau
binds:addInput("interact", Enum.KeyCode.F)
```

#### example: chord

```luau
binds:addInput(
	"interact",
	keybinds.chord({
		Enum.KeyCode.LeftControl,
		Enum.KeyCode.E
	})
)
```

### addChord

```luau
:addChord(action, inputs): boolean
```

shortcut for adding a chord to an action

#### example

```luau
binds:addChord(
	"interact",
	{
		Enum.KeyCode.LeftControl,
		Enum.KeyCode.E
	}
)
```

### removeInput

```luau
:removeInput(action, trigger): boolean
```

removes a specific input or chord from an action

#### example: input

```luau
binds:removeInput("interact", Enum.KeyCode.F)
```

#### example: chord

```luau
binds:removeInput(
	"interact",
	keybinds.chord({
		Enum.KeyCode.LeftControl,
		Enum.KeyCode.E
	})
)
```

### getInputs

```luau
:getInputs(action): {trigger}?
```

returns a cloned array of inputs and chords for the action, returns nil if the action does not exist

#### example

```luau
local inputs = binds:getInputs("sprint")
```

### getAllInputs

```luau
:getAllInputs(): {[actionName]: bind}
```

returns a shallow copy of all binds; input arrays and groups are cloned, callbacks and options are shallow copied

#### example shape

```luau
{
	[actionName] = {
		name = actionName,
		inputs = {trigger},
		enabled = boolean,
		callback = actionCallback,
		options = bindOptions,
		groups = {[groupName] = boolean}
	}
}
```

### getActions

```luau
:getActions(): {actionName}
```

returns a sorted array of all action names

#### example

```luau
local actions = binds:getActions()
```

### getGroupActions

```luau
:getGroupActions(group): {actionName}
```

returns a sorted array of action names in a group

#### example

```luau
local gameplayActions = binds:getGroupActions("gameplay")
```

## groups

groups let you enable, disable, inspect, and remove sets of binds; they do not (and should not!!) replace per-action enabled state

an action only runs when:

```luau
action.enabled == true
```

and every group it belongs to is enabled

### setGroupEnabled

```luau
:setGroupEnabled(group, enabled): boolean
```

enables or disables a group

#### example

```luau
binds:setGroupEnabled("gameplay", false)
binds:setGroupEnabled("menu", true)
```

### toggleGroupEnabled

```luau
:toggleGroupEnabled(group): boolean
```

toggles a group

#### example

```luau
binds:toggleGroupEnabled("gameplay")
```

### isGroupEnabled

```luau
:isGroupEnabled(group): boolean
```

returns whether a group is enabled

(groups are enabled by default unless explicitly disabled)

#### example

```luau
if binds:isGroupEnabled("gameplay") then
	print("gameplay binds are active")
end
```

### enableOnlyGroup

```luau
:enableOnlyGroup(group): ()
```

enables one group and disables all known groups

#### example

```luau
binds:enableOnlyGroup("menu")
```

### setActionGroups

```luau
:setActionGroups(action, groups): boolean
```

replaces all groups on an action

#### example

```luau
binds:setActionGroups(
	"interact",
	{"gameplay", "shared"}
)
```

### addToGroup

```luau
:addToGroup(action, group): boolean
```

adds an action to a group

#### example

```luau
binds:addToGroup("interact", "shared")
```

### removeFromGroup

```luau
:removeFromGroup(action, group): boolean
```

removes an action from a group

#### example

```luau
binds:removeFromGroup("interact", "shared")
```

## rebinding

### rebind

```luau
:rebind(action, onComplete?, options?): boolean
```

waits for the next user input and replaces the action’s inputs with that one input, returns false if the action does not exist

#### example

```luau
binds:rebind("sprint", function(newInput)
	print("sprint rebound to", keybinds.inputToText(newInput))
end)
```

#### example with ignored key

```luau
binds:rebind(
	"sprint",
	function(newInput)
		print("sprint rebound to", keybinds.inputToText(newInput))
	end,
	{
		ignore = {Enum.KeyCode.R}
	}
)
```

### rebindChord

```luau
:rebindChord(action, count?, onComplete?, options?): boolean
```

waits for multiple user inputs and replaces the action’s inputs with a chord; `count` defaults to 2. returns false if the action does not exist

#### example

```luau
binds:rebindChord(
	"dash",
	2,
	function(newChord)
		print("dash rebound to", keybinds.triggerToText(newChord))
	end
)
```

### cancelRebind

```luau
:cancelRebind(): ()
```

cancels the current pending rebind or chord rebind

#### example

```luau
binds:cancelRebind()
```

## held input state

### isDown

```luau
:isDown(input): boolean
```

returns whether an input is currently held

#### example

```luau
if binds:isDown(Enum.KeyCode.LeftShift) then
	print("shift is down")
end
```

### areDown

```luau
:areDown(inputs): boolean
```

returns whether every input is currently held

#### example

```luau
if binds:areDown({
	Enum.KeyCode.LeftShift,
	Enum.KeyCode.Q
}) then
	print("dash chord is held")
end
```

### isActionDown

```luau
:isActionDown(action): boolean
```

returns whether an action is currently held; works for both normal binds and chords

#### example

```luau
if binds:isActionDown("dash") then
	print("dash is held")
end
```

### resetDown

```luau
:resetDown(): ()
```

clears all held input and action state

(this is also called automatically when window focus is lost)

#### example

```luau
binds:resetDown()
```

## conflicts

### findConflicts

```luau
:findConflicts(trigger, exceptAction?): {actionName}
```

finds actions using the same exact input or chord

#### example

```luau
local conflicts = binds:findConflicts(
	Enum.KeyCode.E,
	"interact"
)
```

### getConflicts

```luau
:getConflicts(): {[actionName]: {actionName}}
```

returns every action that conflicts with another action

#### example

```luau
local conflicts = binds:getConflicts()

for action, actionConflicts in conflicts do
	print(action, table.concat(actionConflicts, ", "))
end
```

## serialization

### serialize

```luau
:serialize(): {[actionName]: {trigger}}
```

returns raw input and chord data; this is useful for in-memory copies, but is not DataStore-safe; EnumItems cannot be directly saved

#### example

```luau
local data = binds:serialize()
```

### load

```luau
:load(data: {[actionName]: {trigger}}): ()
```

loads raw input and chord data back into existing binds

(only existing actions are updated)

#### example

```luau
binds:load(savedData)
```

### serializeStrings

```luau
:serializeStrings(): {[actionName]: {serializedTrigger}}
```

returns string-safe input and chord data; this is the preferred format for DataStores

#### example

```luau
local data = binds:serializeStrings()
```

#### example output

```luau
{
	sprint = {
		"Enum.KeyCode.LeftShift"
	},

	dash = {
		{
			"Enum.KeyCode.LeftShift",
			"Enum.KeyCode.Q"
		}
	}
}
```

### loadStrings

```luau
:loadStrings(data: {[actionName]: {serializedTrigger}}): ()
```

loads string-safe input and chord data back into existing binds

(only existing actions are updated)

#### example

```luau
binds:loadStrings(savedData)
```

### serializeFull

```luau
:serializeFull(): {[actionName]: serializedBind}
```

returns string-safe bind data with inputs, enabled state, and groups

#### example

```luau
local data = binds:serializeFull()
```

#### example output

```luau
{
	sprint = {
		inputs = {
			"Enum.KeyCode.LeftShift"
		},
		enabled = true,
		groups = {
			"gameplay"
		}
	}
}
```

### loadFull

```luau
:loadFull(data: {[actionName]: serializedBind}): ()
```

loads full string-safe bind data back into existing binds

(only existing actions are updated)

#### example

```luau
binds:loadFull(savedData)
```

## change event

### changed

```luau
:changed(): changedEvent
```

returns a custom event object, bind will be nil if the action was unbound

(all listeners are disconnected when `destroy()` is called)

#### example

```luau
local disconnect = binds:changed():Connect(function(action, bind)
	if bind then
		print("bind changed: " .. action)
	else
		print("bind removed: " .. action)
	end
end)
```

returns a disconnect function:

```luau
disconnect()
```

## cleaning

### clear

```luau
:clear(): ()
```

unbinds all actions and clears the registry; the instance can still be reused after this

#### example

```luau
binds:clear()
```

### destroy

```luau
:destroy(): ()
```

unbinds all actions, disconnects all listeners, cancels pending rebinds, clears state, and permanently invalidates the instance

#### example

```luau
binds:destroy()
```

## full example

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local keybinds = require(ReplicatedStorage:WaitForChild("kbMod"))

local binds = keybinds.new()

local function callback(action, state, inputObject, gameProcessedEvent)
	if state == Enum.UserInputState.Begin then
		print(action .. " began")
	elseif state == Enum.UserInputState.End then
		print(action .. " ended")
	end

	return Enum.ContextActionResult.Sink
end

binds:bind(
	"interact",
	{
		Enum.KeyCode.E,
		Enum.KeyCode.ButtonX
	},
	callback,
	{
		group = "gameplay",
		priority = 2000,
		createTouchButton = true,
		touchButtonTitle = "use",
		touchButtonPosition = UDim2.fromScale(0.82, 0.55)
	}
)

binds:bindChord(
	"dash",
	{
		Enum.KeyCode.LeftShift,
		Enum.KeyCode.Q
	},
	callback,
	{
		group = "gameplay",
		chordTimeout = 0.4
	}
)

binds:bind(
	"toggle menu",
	Enum.KeyCode.M,
	function(action, state)
		if state == Enum.UserInputState.Begin then
			local opening = not binds:isGroupEnabled("menu")

			binds:setGroupEnabled("menu", opening)
			binds:setGroupEnabled("gameplay", not opening)
		end

		return Enum.ContextActionResult.Sink
	end,
	{
		group = "global",
		allowWhileTyping = true
	}
)

binds:bind(
	"rebind interact",
	Enum.KeyCode.R,
	function(action, state)
		if state == Enum.UserInputState.Begin then
			binds:rebind(
				"interact",
				function(newInput)
					print("interact rebound to " .. keybinds.inputToText(newInput))
				end,
				{
					ignore = {Enum.KeyCode.R}
				}
			)
		end

		return Enum.ContextActionResult.Sink
	end,
	{
		group = "global",
		allowWhileTyping = true
	}
)

binds:changed():Connect(function(action, bind)
	if bind then
		print(action .. " changed")
	else
		print(action .. " removed")
	end
end)

local data = binds:serializeFull()

binds:loadFull(data)
```
