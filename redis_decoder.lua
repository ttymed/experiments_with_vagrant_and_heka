local dt = require "date_time"
local l = require 'lpeg'
local syslog = require "syslog"
local sp = l.space


local payload_keep = read_config("payload_keep")

local pid = l.P"[" * l.Cg(l.R("09")^1, "pid") * l.P"]"
local date = l.P"[" * l.R("09")^1 * l.P"]" * l.P" " * l.Cg(dt.build_strftime_grammar("%d %b %H:%M:%S"), "log_date")
local log_date = l.Cg(dt.build_strftime_grammar("%d %b %H:%M:%S"), "log_date")
local milliseconds = l.P"." * l.R("09")^1
local symbol = l.Cg(l.S("#*-"), "symbol")
local logMsg = l.Cg(l.P(1)^1, "message")
local result = l.Cg(log_date * milliseconds * sp * symbol * sp * logMsg, "result")
local basePattern = pid * sp * log_date * milliseconds * sp * symbol * sp * logMsg
local pattern = pid * sp * result

local grammar = l.Ct(pattern)

local msg = {
  Timestamp = nil,
  Type = nil,
  Payload = nil,
  Fields = nil
}

function process_message()
  local log = read_message("Payload")
  local m = grammar:match(log)
  if not m then return -1 end
  if m then
    msg.Timestamp = m.log_date
    msg.Symbol = m.symbol
    msg.logMsg = m.message
    msg.result = m.result
  else
    msg.Type = "Ignore"
  end

  if payload_keep then
    msg.Payload = msg.Timestamp
  end

  msg.Payload = msg.result
  inject_message(msg)
  return 0
end

