local msgpack = require("omgameserver.msgpack")
local buffer = require("omgameserver.buffer")

local bit_band = bit.band
local bit_bor = bit.bor
local bit_lshift = bit.lshift
local math_random = math.random
local table_concat = table.concat
local table_remove = table.remove
local socket_gettime = socket.gettime

-- Header constants
local HEADER_SIZE = 3 * 4 + 1
local HEADER_SYS_NOVALUE = 1
local HEADER_SYS_PINGREQ = 2
local HEADER_SYS_PONGRES = 4

-- Logging levels
local LOGGING_ERROR = 1
local LOGGING_WARN = 2
local LOGGING_INFO = 3
local LOGGING_DEBUG = 4
local LOGGING_TRACE = 5

-- Current client state
local CLIENT = {}

local function init_client(udp, settings, handler)	
	local settings = settings or {}
	local handler = handler or {}
	
	CLIENT = {}

	-- Socket
	CLIENT.udp = udp

	-- Settings
	CLIENT.buffer_size = settings.buffer_size or 1024
	CLIENT.disconnect_interval = settings.disconnect_interval or 5
	CLIENT.tick_interval = settings.tick_interval or 0.1
	CLIENT.ping_interval = settings.ping_interval or 0.5
	CLIENT.loss_simulation_level = settings.loss_simulation_level or 0
	
	-- Logging
	CLIENT.logging = settings.logging or LOGGING_INFO

	-- Handler
	CLIENT.handler = handler

	CLIENT.last_outgoing_seq = 0
	CLIENT.last_incoming_seq = 0
	CLIENT.last_incoming_bit = 0

	CLIENT.last_server_activity = socket_gettime()
	CLIENT.last_server_ping_request = socket_gettime()
	CLIENT.last_server_latency = 0

	CLIENT.last_tick_time = socket_gettime()

	CLIENT.outgoing = {}
	CLIENT.empty = true

	CLIENT.reliable = {}
	CLIENT.ephemeral = {}

	CLIENT.saved = {}
	CLIENT.outgoing_seq = {}
end

--[[
	options = {
		hostname - server hostname,
		port - server port,
		settings = {
			buffer_size - datagrams size limit in bytes,
			disconnect_interval - disconnect interval in seconds,
			tick_interval - tick interval in seconds,
			ping_interval - ping server interval in seconds,
			loss_simulation_level - simulation of server's datagrams loss,
			logging - level of logging
		}
		handler = {
			connected = function(self),
			closed = function(self),
			received = function(self, value),
			pong = function(self, latency),
			tick = function(self),
		},
	},
]]--
local function connect(options)
	assert(options, "[OMGS/CLIENT] hostname/port not defined")
	assert(options.hostname, "[OMGS/CLIENT] hostname not defined")
	assert(options.port, "[OMGS/CLIENT] port not defined")
	
	if (CLIENT.udp) then
		if (CLIENT.logging >= LOGGING_INFO) then
			print("[OMGS/CLIENT] client already connected")
		end

		return nil, "already connected"
	end

	local udp, error = socket.udp()
	if (error) then
		if (CLIENT.logging >= LOGGING_ERROR) then
			print("[OMGS/CLIENT] socket failed with " .. error)
		end

		return nil, error
	end

	local _, error = udp:setpeername(options.hostname, options.port)
	if (error) then
		if (CLIENT.logging >= LOGGING_ERROR) then
			print("[OMGS/CLIENT] setpeername failed with " .. error)
		end

		return nil, error
	end

	udp:settimeout(0)

	init_client(udp, options.settings or nil, options.handler)

	if (CLIENT.logging >= LOGGING_INFO) then
		print("[OMGS/CLIENT] connected to " .. options.hostname .. ":" .. options.port)
	end

	if (CLIENT.handler and CLIENT.handler.connected) then
		CLIENT.handler:connected()
	end

	return 1
end

local function close()
	if (not CLIENT.udp) then
		return nil, "client disconnected"
	end

	CLIENT.udp:close()
	CLIENT.udp = nil

	if (CLIENT.logging >= LOGGING_INFO) then
		print("[OMGS/CLIENT] closed")
	end

	if (CLIENT.handler and CLIENT.handler.closed) then
		CLIENT.handler:closed()
	end
end

local function as_binary(n)
	local result = ""
	for i = 0, 31 do
		if (bit_band(n, bit_lshift(1, i)) > 0) then
			result = 1 .. result
		else
			result = 0 .. result
		end
	end

	return result
end

local function sys_header_to_string(sys)
	if (sys == HEADER_SYS_NOVALUE) then
		return "NOVALUE"
	elseif(sys == HEADER_SYS_PINGREQ) then
		return "PINGREQ"
	elseif (sys == HEADER_SYS_PONGRES) then
		return "PONGRES"
	else
		return "UNKNOWN"
	end
end

local function resend_buffers(seq)
	local saved = CLIENT.saved[seq]
	if (saved) then
		if (CLIENT.logging >= LOGGING_TRACE) then
			print("[OMGS/CLIENT] resend buffers from seq=" .. seq)
		end
		local outgoing = CLIENT.outgoing
		for i = 1, #saved do
			outgoing[saved[i]] = true
		end
		CLIENT.saved[seq] = nil
		CLIENT.empty = false
	end
end

local function detect_missing_seq(incoming_ack, incoming_bit)
	for i = #CLIENT.outgoing_seq, 1, -1 do
		local seq = CLIENT.outgoing_seq[i]

		local delta = incoming_ack - seq

		if (delta >= 0) then
			if (delta >= 32 or bit_band(incoming_bit, (bit_lshift(1, delta))) == 0) then
				resend_buffers(seq)
			else
				if (CLIENT.logging >= LOGGING_TRACE) then
					print("[OMGS/CLIENT] confirm seq=" .. seq)
				end
			end

			table_remove(CLIENT.outgoing_seq, i)
		end
	end
end

local function create_next_buffer(sys)
	local b = buffer.create_empty()

	CLIENT.last_outgoing_seq = CLIENT.last_outgoing_seq + 1
	buffer.write_int(b, CLIENT.last_outgoing_seq)
	buffer.write_int(b, CLIENT.last_incoming_seq)
	buffer.write_int(b, CLIENT.last_incoming_bit)
	buffer.write_byte(b, sys)

	return b
end

local function send_buffer(buffer)
	local _, error = CLIENT.udp:send(buffer.bytes)
	if (error) then
		if (CLIENT.logging >= LOGGING_DEBUG) then
			print("[OMGS/CLIENT] send buffer failed with " .. error)
		end

		return nil, error
	else
		return 1
	end
end

local function ping()
	CLIENT.last_server_ping_request = socket_gettime()
	local pingRequest = create_next_buffer(HEADER_SYS_PINGREQ)
	send_buffer(pingRequest)
end

local function pong()
	local pongResponse = create_next_buffer(HEADER_SYS_PONGRES)
	send_buffer(pongResponse)
end

local function is_tick_time()
	return socket_gettime() - CLIENT.last_tick_time > CLIENT.tick_interval
end

local function is_disconnected()
	return socket_gettime() - CLIENT.last_server_activity > CLIENT.disconnect_interval
end

local function is_ping_time()
	return socket_gettime() - CLIENT.last_server_ping_request > CLIENT.ping_interval
end

local function receive()
	if (not CLIENT.udp) then
		return nil, "client disconnected"
	end

	local bytes, error = CLIENT.udp:receive()
	if (error) then
		if (error ~= "timeout") then
			if (CLIENT.logging >= LOGGING_ERROR) then
				print("[OMGS/CLIENT] receiving failed with " .. error)
			end

			close()
		end

		return nil, error
	end

	-- Loss simulation
	if (math_random() < CLIENT.loss_simulation_level) then
		return nil, "loss simulated"
	end

	local b = buffer.from_bytes(bytes)

	local length = buffer.get_length(b)
	if (length < HEADER_SIZE) then
		if (CLIENT.logging >= LOGGING_DEBUG) then
			print("[OMGS/CLIENT] wrong header length=" .. length)
		end
	end

	local incoming_seq = buffer.read_int(b)
	local incoming_ack = buffer.read_int(b)
	local incoming_bit = buffer.read_int(b)
	local incoming_sys = buffer.read_byte(b)

	if (incoming_seq <= CLIENT.last_incoming_seq) then
		if (CLIENT.logging >= LOGGING_DEBUG) then
			print("[OMGS/CLIENT] wrong incoming_seq=" .. incoming_seq .. ", last_incoming_seq="
					.. CLIENT.last_incoming_seq)
		end

		return nil, "wrong incoming_seq"
	end

	if (incoming_ack > CLIENT.last_outgoing_seq or incoming_ack < 0) then
		if (CLIENT.logging >= LOGGING_DEBUG) then
			print("[OMGS/CLIENT] wrong incoming_ack=" .. incoming_ack .. ", last_outgoing_seq="
					.. CLIENT.last_outgoing_seq)
		end

		return nil, "wrong incoming_ack"
	end

	if (CLIENT.logging >= LOGGING_TRACE) then
		print("[OMGS/CLIENT] got datagram with seq=" .. incoming_seq .. ", ack=" .. incoming_ack
				.. ", bit=" .. as_binary(incoming_bit) .. ", sys=" .. sys_header_to_string(incoming_sys))
	end

	CLIENT.last_server_activity = socket_gettime()

	CLIENT.last_incoming_bit = bit_bor(bit_lshift(CLIENT.last_incoming_bit, incoming_seq - CLIENT.last_incoming_seq), 1)
	CLIENT.last_incoming_seq = incoming_seq

	detect_missing_seq(incoming_ack, incoming_bit)

	-- Calc latency
	if (incoming_sys == HEADER_SYS_PONGRES) then
		CLIENT.last_server_latency = socket_gettime() - CLIENT.last_server_ping_request
		CLIENT.last_server_ping_request = 0

		if (CLIENT.handler and CLIENT.handler.pong) then
			CLIENT.handler:pong(CLIENT.last_server_latency)
		end

		if (CLIENT.logging >= LOGGING_TRACE) then
			print("[OMGS/CLIENT] latency to server equal " .. CLIENT.last_server_latency .. " ms")
		end
	-- Response pong to ping request from server
	elseif (incoming_sys == HEADER_SYS_PINGREQ) then
		pong()
	elseif (buffer:remaining() > 0) then
		return buffer
	else
		return nil
	end
end

local function send(value, reliable)
	if (not CLIENT.udp) then
		return nil, "client disconnected"
	end

	local b, error = msgpack.encode(value)
	if (b) then
		local length = buffer.get_length(b)
		local limit = CLIENT.buffer_size - HEADER_SIZE
		if (length > limit) then
			if (CLIENT.logging >= LOGGING_DEBUG) then
				print("[OMGS/CLIENT] too large data to send, size=" .. length .. ", limit=" .. limit)
			end

			return nil, "too large data to send"
		end

		if (CLIENT.logging >= LOGGING_TRACE) then
			print("[OMGS/CLIENT] send buffer " .. buffer)
		end

		-- Add to outgoing list
		CLIENT.outgoing[buffer] = reliable
		CLIENT.empty = false

		return 1
	else
		return nil, error
	end
end

local function save_buffer(seq, buffer)
	local saved = CLIENT.saved[seq]
	if (saved == nil) then
		saved = {}
		CLIENT.saved[seq] = saved
	end

	saved[#saved + 1] = buffer
end


local function flush()
	if (not CLIENT.udp) then
		return nil, "client disconnected"
	end

	if (CLIENT.empty) then
		return
	end

	local next = create_next_buffer(HEADER_SYS_NOVALUE)
	local count = 0
	local size = 0

	for b, r in pairs(CLIENT.outgoing) do
		if (buffer.get_length(next) + buffer.get_length(b) >= CLIENT.buffer_size) then
			-- Flush
			size = size + buffer.get_length(next)
			send_buffer(next)
			-- TODO: check result
			CLIENT.outgoing_seq[#CLIENT.outgoing_seq + 1] = CLIENT.last_outgoing_seq
			next = create_next_buffer(HEADER_SYS_NOVALUE)
		end
		buffer.write_buffer(next, b)
		count = count + 1

		if (r) then
			save_buffer(CLIENT.last_outgoing_seq, b)
		end
	end
	-- Flush
	size = size + buffer.get_length(next)
	send_buffer(next)
	CLIENT.outgoing_seq[#CLIENT.outgoing_seq + 1] = CLIENT.last_outgoing_seq
	-- Clear list
	CLIENT.outgoing = {}
	CLIENT.empty = true
	if (CLIENT.logging >= LOGGING_TRACE) then
		print("[OMGS/CLIENT] flush " .. count .. " datagrams with " .. size .. " bytes")
	end
end

local function update()
	if (not CLIENT.udp) then
		return nil, "client disconnected"
	end

	local b, _ = receive()
	if (b) then
		if (CLIENT.logging >= LOGGING_TRACE) then
			print("[OMGS/CLIENT] received buffer " .. b)
		end

		if (CLIENT.handler and CLIENT.handler.received) then
			while (buffer.remaining(b) > 0) do
				local t, _ = msgpack.decode(buffer)
				if (t) then
					CLIENT.handler:received(t)
				end
			end
		end
	end

	if (is_tick_time()) then
		CLIENT.last_tick_time = socket_gettime()

		if (is_disconnected()) then
			if (CLIENT.logging >= LOGGING_INFO) then
				print("[OMGS/CLIENT] server disconnected")
			end

			close()
		else
			if (is_ping_time()) then
				ping()
			end

			flush()

			if (CLIENT.handler and CLIENT.handler.tick) then
				CLIENT.handler:tick()
			end
		end
	end
end

-- Export local functions
return {
	-- Constants
	LOGGING_ERROR = LOGGING_ERROR,
	LOGGING_WARN = LOGGING_WARN,
	LOGGING_INFO = LOGGING_INFO,
	LOGGING_DEBUG = LOGGING_DEBUG,
	LOGGING_TRACE = LOGGING_TRACE,
	-- Methods
	connect = connect,
	closse = close,
	send = send,
	update = update,
}