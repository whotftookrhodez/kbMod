--!strict

export type actionName = string
export type actionState = Enum.UserInputState

export type actionCallback =
	(
		action: actionName,
		state: actionState,
		input: InputObject,
		gameProcessedEvent: boolean
	) -> Enum.ContextActionResult

export type bindOptions =
	{
		sinkProcessed: boolean?,

		createTouchButton: boolean?,
		touchButtonPosition: UDim2?,
		touchButtonImage: string?,
		touchButtonTitle: string?
	}

export type bind =
	{
		name: actionName,
		inputs: {input},

		enabled: boolean,
		callback: actionCallback,
		options: bindOptions
	}

type changedEvent =
	{
		Connect: (
			self: changedEvent, fn: (
				action: actionName, bind: bind?
			) -> ()
		) -> () -> (),

		Fire: (
			self: changedEvent, action: actionName, bind: bind?
		) -> ()
	}

export type input =
	Enum.KeyCode |
Enum.UserInputType

local function makeEvent(): changedEvent & {Destroy: (self: any) -> ()}
	local listeners: {(actionName, bind?) -> ()} = {}
	local event: any = {}
	local destroyed = false

	function event:Connect(fn)
		if destroyed then
			return function() end
		end

		table.insert(
			listeners,
			fn
		)

		local disconnected = false

		return function()
			if disconnected then
				return
			end

			disconnected = true

			local index = table.find(
				listeners,
				fn
			)

			if index then
				table.remove(
					listeners,
					index
				)
			end
		end
	end

	function event:Fire(
		action,
		bind
	)

		if destroyed then
			return
		end

		for _, fn in table.clone(listeners) do
			fn(
				action,
				bind
			)
		end
	end

	function event:Destroy()
		destroyed = true

		table.clear(listeners)
	end

	return event
end

local keybinds = {}

keybinds.__index = keybinds

export type keybinds = typeof(
	setmetatable(
		{} :: {
			_binds: {[actionName]: bind},
			_changed: changedEvent
		}, keybinds
	)
)

local function toInputsArray(
	inputs: {input} | input
): {input}

	if typeof(inputs) == "table" then
		local out: {input} = {}

		for i, v in inputs do
			out[i] = v
		end

		return out
	else
		return {inputs}
	end
end

local function hasInput(
	list: {input},
	input: input
): boolean

	for _, v in list do
		if v == input then
			return true
		end
	end

	return false
end

local function removeInput(
	list: {input},
	input: input
)

	local i = 1

	while i <= #list do
		if list[i] == input then
			table.remove(
				list,
				i
			)
		else
			i += 1
		end
	end
end

local contextActionService = game:GetService("ContextActionService")

local function setTouchButtonOptions(
	action: actionName,
	options: bindOptions
)

	local button: any = contextActionService:GetButton(action)

	if not button then
		return
	end

	if options.touchButtonPosition then
		button.Position = options.touchButtonPosition
	end

	if options.touchButtonImage then
		button.Image = options.touchButtonImage
	end

	if options.touchButtonTitle then
		button.Text = options.touchButtonTitle
	end
end

local function casBind(
	name: actionName,
	bind: bind
)

	contextActionService:BindAction(
		name,
		function(
			actionName,
			state,
			inputObject,
			gameProcessedEvent
		)

			if not bind.enabled then
				return Enum.ContextActionResult.Pass
			end

			if gameProcessedEvent
				and bind.options.sinkProcessed ~= true then

				return Enum.ContextActionResult.Pass
			end

			return bind.callback(
				actionName,
				state,
				inputObject,
				gameProcessedEvent
			)
		end,

		bind.options.createTouchButton == true,

		table.unpack(bind.inputs)
	)

	if bind.options.createTouchButton then
		setTouchButtonOptions(
			name,
			bind.options
		)
	end
end

local function casUnbind(name: actionName)
	contextActionService:UnbindAction(name)
end

function keybinds.new(): keybinds
	local self = setmetatable(
		{
			_binds = {} :: {[actionName]: bind},
			_changed = makeEvent()
		}, keybinds
	)

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

function keybinds:bind(
	action: actionName,
	inputs: {input} | input,
	callback: actionCallback,
	options: bindOptions?
): bind

	if self._binds[action] ~= nil then
		casUnbind(action)
	end

	local bind: bind =
		{
			name = action,
			inputs = toInputsArray(inputs),

			enabled = true,
			callback = callback,
			options = options or {}
		}

	self._binds[action] = bind

	casBind(
		action,
		bind
	)

	self._changed:Fire(
		action,
		bind
	)

	return bind
end

function keybinds:unbind(action: actionName): boolean
	local existing = self._binds[action]

	if existing == nil then
		return false
	end

	self._binds[action] = nil

	casUnbind(action)

	self._changed:Fire(
		action,
		nil
	)

	return true
end

function keybinds:setenabled(
	action: actionName,
	enabled: boolean
): boolean

	local bind = self._binds[action]

	if bind == nil then
		return false
	end

	if bind.enabled == enabled then
		return true
	end

	bind.enabled = enabled

	self._changed:Fire(
		action,
		bind
	)

	return true
end

function keybinds:toggleEnabled(action: actionName): boolean
	local bind = self._binds[action]

	if bind == nil then
		return false
	end

	return self:setenabled(
		action,
		not bind.enabled
	)
end

function keybinds:isEnabled(action: actionName): boolean
	local bind = self._binds[action]

	if bind == nil then
		return false
	end

	return bind.enabled
end

function keybinds:setCallback(
	action: actionName,
	callback: actionCallback
): boolean

	local bind = self._binds[action]

	if bind == nil then
		return false
	end

	bind.callback = callback

	self._changed:Fire(
		action,
		bind
	)

	return true
end

function keybinds:setInputs(
	action: actionName,
	inputs: {input} | input
): boolean

	local bind = self._binds[action]

	if bind == nil then
		return false
	end

	bind.inputs = toInputsArray(inputs)

	casUnbind(action)
	casBind(
		action,
		bind
	)

	self._changed:Fire(
		action,
		bind
	)

	return true
end

function keybinds:addInput(
	action: actionName,
	input: input
): boolean

	local bind = self._binds[action]

	if bind == nil then
		return false
	end

	if hasInput(
		bind.inputs,
		input
		) then

		return true
	end

	table.insert(
		bind.inputs,
		input
	)

	casUnbind(action)
	casBind(
		action,
		bind
	)

	self._changed:Fire(
		action,
		bind
	)

	return true
end

function keybinds:removeInput(
	action: actionName,
	input: input
): boolean

	local bind = self._binds[action]

	if bind == nil then
		return false
	end

	if not hasInput(
		bind.inputs,
		input
		) then

		return true
	end

	removeInput(
		bind.inputs,
		input
	)

	casUnbind(action)
	casBind(
		action,
		bind
	)

	self._changed:Fire(
		action,
		bind
	)

	return true
end

function keybinds:getInputs(action: actionName): {input}?
	local bind = self._binds[action]

	if bind == nil then
		return nil
	end

	return table.clone(bind.inputs)
end

function keybinds:getAllInputs(): {[actionName]: bind}
	local out = {}

	if self._binds == nil then
		return out
	end

	for action, bind in self._binds do
		out[action] =
			{
				name = bind.name,
				inputs = table.clone(bind.inputs),
				enabled = bind.enabled,
				callback = bind.callback,
				options = bind.options
			}
	end

	return out
end

local function inputFromInputObject(io: InputObject): input?
	if io.KeyCode ~= Enum.KeyCode.Unknown then
		return io.KeyCode
	end

	return io.UserInputType
end

function keybinds:rebind(
	action: actionName,
	onComplete: ((input) -> ())?
): boolean

	local bind = self._binds[action]

	if not bind then
		return false
	end

	local connection: RBXScriptConnection

	connection = game:GetService("UserInputService").InputBegan:Connect(
		function(
			io,
			gpe
		)

			if gpe then
				return
			end

			local newInput = inputFromInputObject(io)

			if not newInput then
				return
			end

			self:setInputs(
				action,
				newInput
			)

			if onComplete then
				onComplete(newInput)
			end

			connection:Disconnect()
		end
	)

	return true
end

function keybinds:serialize(): {[actionName]: {input}}
	local data = {}

	if self._binds == nil then
		return data
	end

	for action, bind in self._binds do
		data[action] = table.clone(bind.inputs)
	end

	return data
end

function keybinds:load(data: {[actionName]: {input}})
	for action, inputs in data do
		if self._binds[action] then
			self:setInputs(action, inputs)
		end
	end
end

function keybinds:clear(): ()
	for action, _ in self._binds do
		casUnbind(action)
	end

	table.clear(self._binds)
end

function keybinds:destroy()
	self:clear()
	self._changed:Destroy()

	setmetatable(
		self,
		nil
	)
end

return keybinds
