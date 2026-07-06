--!strict

export type actionName = string
export type groupName = string
export type actionState = Enum.UserInputState
export type input = Enum.KeyCode | Enum.UserInputType
export type chord = {kind: "chord", inputs: {input}}
export type trigger = input | chord
export type serializedTrigger = string | {string}

export type actionCallback = (
	action: actionName,
	state: actionState,
	input: InputObject,
	gameProcessedEvent: boolean
) -> Enum.ContextActionResult

export type bindOptions = {
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

export type bind = {
	name: actionName,
	inputs: {trigger},
	enabled: boolean,
	callback: actionCallback,
	options: bindOptions,
	groups: {[groupName]: boolean}
}

export type rebindOptions = {
	allowProcessed: boolean?,
	allowWhileTyping: boolean?,
	ignore: {input}?
}

export type serializedBind = {
	inputs: {serializedTrigger},
	enabled: boolean?,
	groups: {groupName}?
}

type changedEvent = {
	Connect: (self: changedEvent, fn: (action: actionName, bind: bind?) -> ()) -> () -> (),
	Fire: (self: changedEvent, action: actionName, bind: bind?) -> ()
}

type ownedChangedEvent = changedEvent & {
	Destroy: (self: any) -> ()
}

local userInputService = game:GetService("UserInputService")
local contextActionService = game:GetService("ContextActionService")

local function makeEvent(): ownedChangedEvent
	local listeners: {(actionName, bind?) -> ()} = {}
	local event: any = {}
	local destroyed = false

	function event:Connect(fn)
		if destroyed then
			return function() end
		end

		table.insert(listeners, fn)

		local disconnected = false

		return function()
			if disconnected then
				return
			end

			disconnected = true

			local index = table.find(listeners, fn)

			if index then
				table.remove(listeners, index)
			end
		end
	end

	function event:Fire(action, bind)
		if destroyed then
			return
		end

		for _, fn in table.clone(listeners) do
			fn(action, bind)
		end
	end

	function event:Destroy()
		destroyed = true
		table.clear(listeners)
	end

	return event
end

local function isChord(value: any): boolean
	return typeof(value) == "table" and value.kind == "chord" and typeof(value.inputs) == "table"
end

local function cloneInputs(inputs: {input}): {input}
	local out: {input} = {}

	for _, value in inputs do
		if not table.find(out, value) then
			table.insert(out, value)
		end
	end

	return out
end

local function toInputArray(inputs: {input} | input): {input}
	if typeof(inputs) == "table" then
		return cloneInputs(inputs :: {input})
	end

	return {inputs :: input}
end

local function makeChord(inputs: {input} | input): chord
	return {
		kind = "chord",
		inputs = toInputArray(inputs)
	}
end

local function cloneTrigger(trigger: trigger): trigger
	local value: any = trigger

	if isChord(value) then
		return makeChord(value.inputs)
	end

	return trigger
end

local function toTriggersArray(inputs: {trigger} | trigger): {trigger}
	local value: any = inputs
	local out: {trigger} = {}

	if isChord(value) or typeof(value) ~= "table" then
		table.insert(out, cloneTrigger(inputs :: trigger))
		return out
	end

	for _, trigger in value do
		table.insert(out, cloneTrigger(trigger))
	end

	return out
end

local function hasInput(list: {input}, inputValue: input): boolean
	for _, value in list do
		if value == inputValue then
			return true
		end
	end

	return false
end

local function triggerHasInput(trigger: trigger, inputValue: input): boolean
	local value: any = trigger

	if isChord(value) then
		return hasInput(value.inputs, inputValue)
	end

	return trigger == inputValue
end

local function sameChord(a: chord, b: chord): boolean
	if #a.inputs ~= #b.inputs then
		return false
	end

	for _, inputValue in a.inputs do
		if not hasInput(b.inputs, inputValue) then
			return false
		end
	end

	return true
end

local function sameTrigger(a: trigger, b: trigger): boolean
	local aValue: any = a
	local bValue: any = b

	if isChord(aValue) and isChord(bValue) then
		return sameChord(aValue, bValue)
	end

	return a == b
end

local function triggerListHas(list: {trigger}, trigger: trigger): boolean
	for _, value in list do
		if sameTrigger(value, trigger) then
			return true
		end
	end

	return false
end

local function removeTrigger(list: {trigger}, trigger: trigger)
	local i = 1

	while i <= #list do
		if sameTrigger(list[i], trigger) then
			table.remove(list, i)
		else
			i += 1
		end
	end
end

local function cloneOptions(options: bindOptions?): bindOptions
	local out: bindOptions = {}

	if not options then
		return out
	end

	out.sinkProcessed = options.sinkProcessed
	out.createTouchButton = options.createTouchButton
	out.touchButtonPosition = options.touchButtonPosition
	out.touchButtonImage = options.touchButtonImage
	out.touchButtonTitle = options.touchButtonTitle
	out.priority = options.priority
	out.group = options.group
	out.groups = if options.groups then table.clone(options.groups) else nil
	out.allowWhileTyping = options.allowWhileTyping
	out.chordTimeout = options.chordTimeout

	return out
end

local function groupsFromOptions(options: bindOptions): {[groupName]: boolean}
	local groups: {[groupName]: boolean} = {}

	if options.group then
		groups[options.group] = true
	end

	if options.groups then
		for _, group in options.groups do
			groups[group] = true
		end
	end

	return groups
end

local function groupsToArray(groups: {[groupName]: boolean}): {groupName}
	local out: {groupName} = {}

	for group, enabled in groups do
		if enabled then
			table.insert(out, group)
		end
	end

	table.sort(out)

	return out
end

local function normalInputsFromTriggers(triggers: {trigger}): {input}
	local out: {input} = {}

	for _, trigger in triggers do
		local value: any = trigger

		if not isChord(value) and not table.find(out, trigger :: input) then
			table.insert(out, trigger :: input)
		end
	end

	return out
end

local function setTouchButtonOptions(action: actionName, options: bindOptions)
	if options.touchButtonPosition then
		contextActionService:SetPosition(action, options.touchButtonPosition)
	end

	if options.touchButtonImage then
		contextActionService:SetImage(action, options.touchButtonImage)
	end

	if options.touchButtonTitle then
		contextActionService:SetTitle(action, options.touchButtonTitle)
	end
end

local function casUnbind(name: actionName)
	contextActionService:UnbindAction(name)
end

local function inputFromInputObject(io: InputObject): input?
	if io.KeyCode ~= Enum.KeyCode.Unknown then
		return io.KeyCode
	end

	return io.UserInputType
end

local function inputToString(inputValue: input): string
	return `{inputValue.EnumType}.{inputValue.Name}`
end

local function inputToText(inputValue: input): string
	return inputValue.Name
end

local function inputFromString(value: string): input?
	local enumName, itemName = value:match("^Enum%.([%w_]+)%.([%w_]+)$")

	if not enumName then
		enumName, itemName = value:match("^([%w_]+)%.([%w_]+)$")
	end

	if enumName and itemName then
		local enumObject = (Enum :: any)[enumName]
		local enumItem = enumObject and enumObject[itemName]

		if typeof(enumItem) == "EnumItem" and (enumItem.EnumType == Enum.KeyCode or enumItem.EnumType == Enum.UserInputType) then
			return enumItem :: input
		end
	end

	local keyCode = (Enum.KeyCode :: any)[value]

	if typeof(keyCode) == "EnumItem" then
		return keyCode :: input
	end

	local userInputType = (Enum.UserInputType :: any)[value]

	if typeof(userInputType) == "EnumItem" then
		return userInputType :: input
	end

	return nil
end

local function serializeTrigger(trigger: trigger): serializedTrigger
	local value: any = trigger

	if isChord(value) then
		local out: {string} = {}

		for _, inputValue in value.inputs do
			table.insert(out, inputToString(inputValue))
		end

		return out
	end

	return inputToString(trigger :: input)
end

local function triggerFromSerialized(trigger: serializedTrigger): trigger?
	if typeof(trigger) == "string" then
		return inputFromString(trigger :: string)
	end

	local out: {input} = {}

	for _, value in trigger :: {string} do
		local inputValue = inputFromString(value)

		if inputValue then
			table.insert(out, inputValue)
		end
	end

	if #out == 0 then
		return nil
	end

	return makeChord(out)
end

local function triggerToText(trigger: trigger): string
	local value: any = trigger

	if isChord(value) then
		local parts: {string} = {}

		for _, inputValue in value.inputs do
			table.insert(parts, inputToText(inputValue))
		end

		return table.concat(parts, " + ")
	end

	return inputToText(trigger :: input)
end

local keybinds = {}
keybinds.__index = keybinds

export type keybinds = typeof(setmetatable({} :: {
	_binds: {[actionName]: bind},
	_changed: ownedChangedEvent,
	_groupEnabled: {[groupName]: boolean},
	_downInputs: {[any]: boolean},
	_downAt: {[any]: number},
	_downActions: {[actionName]: boolean},
	_actionInputsDown: {[actionName]: {[any]: boolean}},
	_activeChords: {[actionName]: chord},
	_connections: {RBXScriptConnection},
	_captureDisconnect: (() -> ())?
}, keybinds))

local function bindIsInGroup(bind: bind, group: groupName): boolean
	return bind.groups[group] == true
end

local function canRun(self: keybinds, bind: bind, gameProcessedEvent: boolean): boolean
	if not bind.enabled then
		return false
	end

	if gameProcessedEvent and bind.options.sinkProcessed ~= true then
		return false
	end

	if not bind.options.allowWhileTyping and userInputService:GetFocusedTextBox() ~= nil then
		return false
	end

	for group in bind.groups do
		if self._groupEnabled[group] == false then
			return false
		end
	end

	return true
end

local function hasAnyActionInputDown(self: keybinds, action: actionName): boolean
	local active = self._actionInputsDown[action]

	if not active then
		return false
	end

	for _, down in active do
		if down then
			return true
		end
	end

	return false
end

local function refreshActionDown(self: keybinds, action: actionName)
	self._downActions[action] = hasAnyActionInputDown(self, action) or self._activeChords[action] ~= nil
end

local function markActionInputDown(self: keybinds, action: actionName, io: InputObject)
	local inputValue = inputFromInputObject(io)

	if not inputValue then
		return
	end

	if not self._actionInputsDown[action] then
		self._actionInputsDown[action] = {}
	end

	self._actionInputsDown[action][inputValue] = true
	refreshActionDown(self, action)
end

local function markActionInputUp(self: keybinds, action: actionName, io: InputObject)
	local inputValue = inputFromInputObject(io)

	if not inputValue then
		return
	end

	local active = self._actionInputsDown[action]

	if active then
		active[inputValue] = nil
	end

	refreshActionDown(self, action)
end

local function chordWithinTimeout(self: keybinds, chordValue: chord, timeout: number?): boolean
	if not timeout or timeout <= 0 then
		return true
	end

	local minTime: number? = nil
	local maxTime: number? = nil

	for _, inputValue in chordValue.inputs do
		local downAt = self._downAt[inputValue]

		if not downAt then
			return false
		end

		minTime = if minTime then math.min(minTime, downAt) else downAt
		maxTime = if maxTime then math.max(maxTime, downAt) else downAt
	end

	return minTime ~= nil and maxTime ~= nil and maxTime - minTime <= timeout
end

local function chordIsDown(self: keybinds, chordValue: chord, timeout: number?): boolean
	for _, inputValue in chordValue.inputs do
		if self._downInputs[inputValue] ~= true then
			return false
		end
	end

	return chordWithinTimeout(self, chordValue, timeout)
end

local function firstActiveChord(self: keybinds, bind: bind): chord?
	for _, trigger in bind.inputs do
		local value: any = trigger

		if isChord(value) and chordIsDown(self, value, bind.options.chordTimeout) then
			return value
		end
	end

	return nil
end

local function casBind(self: keybinds, name: actionName, bind: bind)
	local normalInputs = normalInputsFromTriggers(bind.inputs)

	if #normalInputs == 0 and bind.options.createTouchButton ~= true then
		return
	end

	local callback = function(action: string, state: Enum.UserInputState, inputObject: InputObject, gameProcessedEvent: boolean): Enum.ContextActionResult
		if not canRun(self, bind, gameProcessedEvent) then
			return Enum.ContextActionResult.Pass
		end

		if state == Enum.UserInputState.Begin then
			markActionInputDown(self, action, inputObject)
		end

		local result = bind.callback(action, state, inputObject, gameProcessedEvent)

		if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			markActionInputUp(self, action, inputObject)
		end

		return result
	end

	if bind.options.priority then
		contextActionService:BindActionAtPriority(name, callback, bind.options.createTouchButton == true, bind.options.priority, table.unpack(normalInputs))
	else
		contextActionService:BindAction(name, callback, bind.options.createTouchButton == true, table.unpack(normalInputs))
	end

	if bind.options.createTouchButton then
		setTouchButtonOptions(name, bind.options)
	end
end

local function resetActionState(self: keybinds, action: actionName)
	self._downActions[action] = nil
	self._actionInputsDown[action] = nil
	self._activeChords[action] = nil
end

local function fireChanged(self: keybinds, action: actionName)
	self._changed:Fire(action, self._binds[action])
end

local function stopCapture(self: keybinds)
	local disconnect = self._captureDisconnect

	if disconnect then
		self._captureDisconnect = nil
		disconnect()
	end
end

local function shouldCaptureInput(options: rebindOptions?, io: InputObject, gameProcessedEvent: boolean): boolean
	if gameProcessedEvent and not (options and options.allowProcessed == true) then
		return false
	end

	if not (options and options.allowWhileTyping == true) and userInputService:GetFocusedTextBox() ~= nil then
		return false
	end

	local inputValue = inputFromInputObject(io)

	if not inputValue then
		return false
	end

	if options and options.ignore and hasInput(options.ignore, inputValue) then
		return false
	end

	return true
end

function keybinds.chord(inputs: {input} | input): chord
	return makeChord(inputs)
end

function keybinds.inputToString(inputValue: input): string
	return inputToString(inputValue)
end

function keybinds.inputToText(inputValue: input): string
	return inputToText(inputValue)
end

function keybinds.inputFromString(value: string): input?
	return inputFromString(value)
end

function keybinds.inputFromInputObject(io: InputObject): input?
	return inputFromInputObject(io)
end

function keybinds.triggerToText(trigger: trigger): string
	return triggerToText(trigger)
end

function keybinds.triggerToString(trigger: trigger): serializedTrigger
	return serializeTrigger(trigger)
end

function keybinds.triggerFromString(trigger: serializedTrigger): trigger?
	return triggerFromSerialized(trigger)
end

function keybinds.new(): keybinds
	local self: keybinds = setmetatable({
		_binds = {} :: {[actionName]: bind},
		_changed = makeEvent(),
		_groupEnabled = {} :: {[groupName]: boolean},
		_downInputs = {} :: {[any]: boolean},
		_downAt = {} :: {[any]: number},
		_downActions = {} :: {[actionName]: boolean},
		_actionInputsDown = {} :: {[actionName]: {[any]: boolean}},
		_activeChords = {} :: {[actionName]: chord},
		_connections = {} :: {RBXScriptConnection},
		_captureDisconnect = nil :: (() -> ())?
	}, keybinds) :: any

	table.insert(self._connections, userInputService.InputBegan:Connect(function(io, gameProcessedEvent)
		local inputValue = inputFromInputObject(io)

		if not inputValue then
			return
		end

		if self._downInputs[inputValue] == true then
			return
		end

		self._downInputs[inputValue] = true
		self._downAt[inputValue] = os.clock()

		for action, bind in self._binds do
			if self._downActions[action] ~= true and canRun(self, bind, gameProcessedEvent) then
				local chordValue = firstActiveChord(self, bind)

				if chordValue then
					self._activeChords[action] = chordValue
					refreshActionDown(self, action)
					bind.callback(action, Enum.UserInputState.Begin, io, gameProcessedEvent)
				end
			end
		end
	end))

	table.insert(self._connections, userInputService.InputEnded:Connect(function(io, gameProcessedEvent)
		local inputValue = inputFromInputObject(io)

		if not inputValue then
			return
		end

		self._downInputs[inputValue] = nil
		self._downAt[inputValue] = nil

		for action, chordValue in table.clone(self._activeChords) do
			if triggerHasInput(chordValue, inputValue) then
				local bind = self._binds[action]
				self._activeChords[action] = nil

				if bind then
					bind.callback(action, Enum.UserInputState.End, io, gameProcessedEvent)
				end

				refreshActionDown(self, action)
			end
		end
	end))

	table.insert(self._connections, userInputService.WindowFocusReleased:Connect(function()
		self:resetDown()
	end))

	return self :: any
end

function keybinds:changed(): changedEvent
	return self._changed
end

function keybinds:has(action: actionName): boolean
	return self._binds[action] ~= nil
end

function keybinds:get(action: actionName): bind?
	return self._binds[action]
end

function keybinds:bind(action: actionName, inputs: {trigger} | trigger, callback: actionCallback, options: bindOptions?): bind
	if self._binds[action] ~= nil then
		casUnbind(action)
		resetActionState(self, action)
	end

	local bindOptionsValue = cloneOptions(options)
	local bind: bind = {
		name = action,
		inputs = toTriggersArray(inputs),
		enabled = true,
		callback = callback,
		options = bindOptionsValue,
		groups = groupsFromOptions(bindOptionsValue)
	}

	self._binds[action] = bind
	casBind(self, action, bind)
	self._changed:Fire(action, bind)

	return bind
end

function keybinds:bindChord(action: actionName, inputs: {input} | input, callback: actionCallback, options: bindOptions?): bind
	return self:bind(action, makeChord(inputs), callback, options)
end

function keybinds:unbind(action: actionName): boolean
	if self._binds[action] == nil then
		return false
	end

	self._binds[action] = nil
	casUnbind(action)
	resetActionState(self, action)
	self._changed:Fire(action, nil)

	return true
end

function keybinds:unbindGroup(group: groupName): number
	local removed = 0

	for action, bind in table.clone(self._binds) do
		if bindIsInGroup(bind, group) and self:unbind(action) then
			removed += 1
		end
	end

	return removed
end

function keybinds:setEnabled(action: actionName, enabled: boolean): boolean
	local actionBind: bind? = self._binds[action]

	if actionBind == nil then
		return false
	end

	if actionBind.enabled == enabled then
		return true
	end

	actionBind.enabled = enabled

	if not enabled then
		resetActionState(self, action)
	end

	fireChanged(self, action)

	return true
end

function keybinds:toggleEnabled(action: actionName): boolean
	local actionBind: bind? = self._binds[action]

	if actionBind == nil then
		return false
	end

	return self:setEnabled(action, not actionBind.enabled)
end

function keybinds:setAllEnabled(enabled: boolean): ()
	local binds: {[actionName]: bind} = self._binds

	for action in binds do
		self:setEnabled(action, enabled)
	end
end

function keybinds:isEnabled(action: actionName): boolean
	local actionBind: bind? = self._binds[action]

	if actionBind == nil then
		return false
	end

	if not actionBind.enabled then
		return false
	end

	for group in actionBind.groups do
		if self._groupEnabled[group] == false then
			return false
		end
	end

	return true
end

function keybinds:setCallback(action: actionName, callback: actionCallback): boolean
	local actionBind: bind? = self._binds[action]

	if actionBind == nil then
		return false
	end

	actionBind.callback = callback
	fireChanged(self, action)

	return true
end

function keybinds:setOptions(action: actionName, options: bindOptions): boolean
	local actionBind: bind? = self._binds[action]

	if actionBind == nil then
		return false
	end

	local newOptions = cloneOptions(options)

	actionBind.options = newOptions
	actionBind.groups = groupsFromOptions(newOptions)

	casUnbind(action)
	casBind(self, action, actionBind)
	fireChanged(self, action)

	return true
end

function keybinds:setInputs(action: actionName, inputs: {trigger} | trigger): boolean
	local actionBind: bind? = self._binds[action]

	if actionBind == nil then
		return false
	end

	actionBind.inputs = toTriggersArray(inputs)

	casUnbind(action)
	casBind(self, action, actionBind)
	resetActionState(self, action)
	fireChanged(self, action)

	return true
end

function keybinds:addInput(action: actionName, trigger: trigger): boolean
	local actionBind: bind? = self._binds[action]

	if actionBind == nil then
		return false
	end

	if triggerListHas(actionBind.inputs, trigger) then
		return true
	end

	table.insert(actionBind.inputs, cloneTrigger(trigger))

	casUnbind(action)
	casBind(self, action, actionBind)
	fireChanged(self, action)

	return true
end

function keybinds:addChord(action: actionName, inputs: {input} | input): boolean
	return self:addInput(action, makeChord(inputs))
end

function keybinds:removeInput(action: actionName, trigger: trigger): boolean
	local actionBind: bind? = self._binds[action]

	if actionBind == nil then
		return false
	end

	if not triggerListHas(actionBind.inputs, trigger) then
		return true
	end

	removeTrigger(actionBind.inputs, trigger)

	casUnbind(action)
	casBind(self, action, actionBind)
	resetActionState(self, action)
	fireChanged(self, action)

	return true
end

function keybinds:getInputs(action: actionName): {trigger}?
	local actionBind: bind? = self._binds[action]

	if actionBind == nil then
		return nil
	end

	local out: {trigger} = {}

	for _, triggerValue in actionBind.inputs do
		table.insert(out, cloneTrigger(triggerValue))
	end

	return out
end

function keybinds:getAllInputs(): {[actionName]: bind}
	local out: {[actionName]: bind} = {}
	local binds: {[actionName]: bind} = self._binds

	for action, actionBind in binds do
		local inputs: {trigger} = {}

		for _, triggerValue in actionBind.inputs do
			table.insert(inputs, cloneTrigger(triggerValue))
		end

		out[action] = {
			name = actionBind.name,
			inputs = inputs,
			enabled = actionBind.enabled,
			callback = actionBind.callback,
			options = cloneOptions(actionBind.options),
			groups = table.clone(actionBind.groups)
		}
	end

	return out
end

function keybinds:getActions(): {actionName}
	local out: {actionName} = {}
	local binds: {[actionName]: bind} = self._binds

	for action in binds do
		table.insert(out, action)
	end

	table.sort(out)

	return out
end

function keybinds:getGroupActions(group: groupName): {actionName}
	local out: {actionName} = {}
	local binds: {[actionName]: bind} = self._binds

	for action, actionBind in binds do
		if bindIsInGroup(actionBind, group) then
			table.insert(out, action)
		end
	end

	table.sort(out)

	return out
end

function keybinds:setActionGroups(action: actionName, groups: {groupName}): boolean
	local actionBind: bind? = self._binds[action]

	if actionBind == nil then
		return false
	end

	local newGroups: {[groupName]: boolean} = {}

	for _, group in groups do
		newGroups[group] = true
	end

	actionBind.groups = newGroups
	actionBind.options.group = nil
	actionBind.options.groups = groupsToArray(newGroups)

	fireChanged(self, action)

	return true
end

function keybinds:addToGroup(action: actionName, group: groupName): boolean
	local actionBind: bind? = self._binds[action]

	if actionBind == nil then
		return false
	end

	actionBind.groups[group] = true
	actionBind.options.group = nil
	actionBind.options.groups = groupsToArray(actionBind.groups)

	fireChanged(self, action)

	return true
end

function keybinds:removeFromGroup(action: actionName, group: groupName): boolean
	local actionBind: bind? = self._binds[action]

	if actionBind == nil then
		return false
	end

	actionBind.groups[group] = nil
	actionBind.options.group = nil
	actionBind.options.groups = groupsToArray(actionBind.groups)

	fireChanged(self, action)

	return true
end

function keybinds:setGroupEnabled(group: groupName, enabled: boolean): boolean
	if self._groupEnabled[group] == enabled then
		return true
	end

	self._groupEnabled[group] = enabled

	local binds: {[actionName]: bind} = self._binds

	for action, actionBind in binds do
		if bindIsInGroup(actionBind, group) then
			if not enabled then
				resetActionState(self, action)
			end

			fireChanged(self, action)
		end
	end

	return true
end

function keybinds:toggleGroupEnabled(group: groupName): boolean
	return self:setGroupEnabled(group, not self:isGroupEnabled(group))
end

function keybinds:isGroupEnabled(group: groupName): boolean
	return self._groupEnabled[group] ~= false
end

function keybinds:enableOnlyGroup(group: groupName): ()
	local found: {[groupName]: boolean} = {}
	local binds: {[actionName]: bind} = self._binds

	for _, actionBind in binds do
		for bindGroup in actionBind.groups do
			found[bindGroup] = true
		end
	end

	found[group] = true

	for foundGroup in found do
		self:setGroupEnabled(foundGroup, foundGroup == group)
	end
end

function keybinds:isDown(inputValue: input): boolean
	return self._downInputs[inputValue] == true
end

function keybinds:areDown(inputs: {input} | input): boolean
	for _, inputValue in toInputArray(inputs) do
		if not self:isDown(inputValue) then
			return false
		end
	end

	return true
end

function keybinds:isActionDown(action: actionName): boolean
	return self._downActions[action] == true
end

function keybinds:rebind(action: actionName, onComplete: ((input) -> ())?, options: rebindOptions?): boolean
	local actionBind: bind? = self._binds[action]

	if actionBind == nil then
		return false
	end

	stopCapture(self)

	local connection: RBXScriptConnection

	connection = userInputService.InputBegan:Connect(function(io, gameProcessedEvent)
		if not shouldCaptureInput(options, io, gameProcessedEvent) then
			return
		end

		local newInput = inputFromInputObject(io)

		if not newInput then
			return
		end

		self:setInputs(action, newInput)

		local complete = onComplete

		if complete then
			complete(newInput)
		end

		stopCapture(self)
	end)

	self._captureDisconnect = function()
		connection:Disconnect()
	end

	return true
end

function keybinds:rebindChord(action: actionName, count: number?, onComplete: ((chord) -> ())?, options: rebindOptions?): boolean
	local actionBind: bind? = self._binds[action]

	if actionBind == nil then
		return false
	end

	stopCapture(self)

	local needed = math.max(1, math.floor(count or 2))
	local captured: {input} = {}
	local connection: RBXScriptConnection

	connection = userInputService.InputBegan:Connect(function(io, gameProcessedEvent)
		if not shouldCaptureInput(options, io, gameProcessedEvent) then
			return
		end

		local inputValue = inputFromInputObject(io)

		if not inputValue or table.find(captured, inputValue) then
			return
		end

		table.insert(captured, inputValue)

		if #captured < needed then
			return
		end

		local newChord = makeChord(captured)

		self:setInputs(action, newChord)

		local complete = onComplete

		if complete then
			complete(newChord)
		end

		stopCapture(self)
	end)

	self._captureDisconnect = function()
		connection:Disconnect()
	end

	return true
end

function keybinds:cancelRebind(): ()
	stopCapture(self)
end

function keybinds:findConflicts(targetTrigger: trigger, exceptAction: actionName?): {actionName}
	local out: {actionName} = {}
	local binds: {[actionName]: bind} = self._binds

	for action, actionBind in binds do
		if action ~= exceptAction then
			for _, bindTrigger in actionBind.inputs do
				if sameTrigger(bindTrigger, targetTrigger) and not table.find(out, action) then
					table.insert(out, action)
				end
			end
		end
	end

	table.sort(out)

	return out
end

function keybinds:getConflicts(): {[actionName]: {actionName}}
	local out: {[actionName]: {actionName}} = {}
	local binds: {[actionName]: bind} = self._binds

	for action, actionBind in binds do
		local conflicts: {actionName} = {}

		for _, triggerValue in actionBind.inputs do
			for _, conflict in self:findConflicts(triggerValue, action) do
				if not table.find(conflicts, conflict) then
					table.insert(conflicts, conflict)
				end
			end
		end

		if #conflicts > 0 then
			table.sort(conflicts)
			out[action] = conflicts
		end
	end

	return out
end

function keybinds:serialize(): {[actionName]: {trigger}}
	local data: {[actionName]: {trigger}} = {}
	local binds: {[actionName]: bind} = self._binds

	for action, actionBind in binds do
		local inputs: {trigger} = {}

		for _, triggerValue in actionBind.inputs do
			table.insert(inputs, cloneTrigger(triggerValue))
		end

		data[action] = inputs
	end

	return data
end

function keybinds:load(data: {[actionName]: {trigger}}): ()
	for action, inputs in data do
		if self._binds[action] then
			self:setInputs(action, inputs)
		end
	end
end

function keybinds:serializeStrings(): {[actionName]: {serializedTrigger}}
	local data: {[actionName]: {serializedTrigger}} = {}
	local binds: {[actionName]: bind} = self._binds

	for action, actionBind in binds do
		local inputs: {serializedTrigger} = {}

		for _, triggerValue in actionBind.inputs do
			table.insert(inputs, serializeTrigger(triggerValue))
		end

		data[action] = inputs
	end

	return data
end

function keybinds:loadStrings(data: {[actionName]: {serializedTrigger}}): ()
	for action, inputs in data do
		if self._binds[action] then
			local triggers: {trigger} = {}

			for _, serialized in inputs do
				local triggerValue = triggerFromSerialized(serialized)

				if triggerValue then
					table.insert(triggers, triggerValue)
				end
			end

			if #triggers > 0 then
				self:setInputs(action, triggers)
			end
		end
	end
end

function keybinds:serializeFull(): {[actionName]: serializedBind}
	local data: {[actionName]: serializedBind} = {}
	local binds: {[actionName]: bind} = self._binds

	for action, actionBind in binds do
		local saved: serializedBind = {
			inputs = {},
			enabled = actionBind.enabled,
			groups = groupsToArray(actionBind.groups)
		}

		for _, triggerValue in actionBind.inputs do
			table.insert(saved.inputs, serializeTrigger(triggerValue))
		end

		data[action] = saved
	end

	return data
end

function keybinds:loadFull(data: {[actionName]: serializedBind}): ()
	for action, saved in data do
		if self._binds[action] then
			local triggers: {trigger} = {}

			for _, serialized in saved.inputs do
				local triggerValue = triggerFromSerialized(serialized)

				if triggerValue then
					table.insert(triggers, triggerValue)
				end
			end

			if #triggers > 0 then
				self:setInputs(action, triggers)
			end

			local savedEnabled = saved.enabled

			if savedEnabled ~= nil then
				self:setEnabled(action, savedEnabled)
			end

			local savedGroups = saved.groups

			if savedGroups then
				self:setActionGroups(action, savedGroups)
			end
		end
	end
end

function keybinds:resetDown(): ()
	table.clear(self._downInputs)
	table.clear(self._downAt)
	table.clear(self._downActions)
	table.clear(self._actionInputsDown)
	table.clear(self._activeChords)
end

function keybinds:clear(): ()
	local binds: {[actionName]: bind} = self._binds

	for action in binds do
		casUnbind(action)
	end

	table.clear(self._binds)
	self:resetDown()
end

function keybinds:destroy(): ()
	stopCapture(self)
	self:clear()

	for _, connection in self._connections do
		connection:Disconnect()
	end

	table.clear(self._connections)
	self._changed:Destroy()
	setmetatable(self :: any, nil)
end

return keybinds
