--- A console utility for printing messages to the console with various levels of detail.

---@class console
--- Prints a shortened console log message.
--- ... The variadic arguments, can be integers, floats, or strings, concatenated into a single log message.
--- @field print fun(...):nil

--- @class console
--- Prints a full console log message including timing controls.
--- start_printing_time The start time when the logging should begin.
--- print_interval The interval at which the log should repeat.
--- msg The message to log.
--- ... The variadic arguments, can be integers, floats, or strings, concatenated with the msg.
--- @field print_full fun(start_printing_time:number, print_interval:number, msg:string, ...):nil

debug_enabled = debug_enabled or false

---@class console
console = {}

--- Sets the debug flag.
---@param value boolean
function console.set_debug(value)
    debug_enabled = value
end

--- Toggles the debug flag.
function console.toggle_debug()
    debug_enabled = not debug_enabled
end

--- Prints a message to the console when debugging is enabled.
---@param ... any Variadic arguments to print.
console.print = function(...)
    if debug_enabled then
        log(...)
    end
end

--- Prints a full message to the console with additional parameters when debugging is enabled.
---@param start_printing_time number When to start printing.
---@param print_interval number How often to print.
---@param msg string The message to print.
---@param ... any Variadic arguments to append to the message.
console.print_full = function(start_printing_time, print_interval, msg, ...)
    if debug_enabled then
        log(msg, ...)
    end
end
