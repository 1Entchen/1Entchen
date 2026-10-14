--!strict
-- Minimal synchronous signal used for in-process events between systems.
-- Handlers run in the firing thread via task.spawn so one failing handler
-- cannot break the others.

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
}

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	local handlers: { [Connection]: (T...) -> () } = {}

	local self = {}

	function self.Connect(_: any, handler: (T...) -> ()): Connection
		local connection = { Connected = true } :: any
		function connection.Disconnect(conn: Connection)
			conn.Connected = false
			handlers[conn] = nil
		end
		handlers[connection] = handler
		return connection
	end

	function self.Fire(_: any, ...: T...)
		for _, handler in handlers do
			task.spawn(handler, ...)
		end
	end

	function self.DisconnectAll(_: any)
		for connection in handlers do
			connection.Connected = false
		end
		table.clear(handlers)
	end

	return (self :: any) :: Signal<T...>
end

return Signal
