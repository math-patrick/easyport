-- ============================================================================
-- Nozmie - Event Bus Module
-- Centralized event registration and dispatching
--
-- This module implements the event bus pattern, allowing multiple systems to
-- register for events without tight coupling. All events flow through this
-- single dispatcher for consistency and debugging.
--
-- Usage:
--   EventBus.Register("CHAT_MSG_SAY", function(event, message, sender)
--       -- handle chat message
--   end)
--   EventBus.Trigger("CUSTOM_EVENT", arg1, arg2)
-- ============================================================================

local EventBus = {}
local handlers = {}
local eventFrame = CreateFrame("Frame")

-- ============================================================================
-- Event Registration
-- ============================================================================

-- Register a handler function for an event
-- Returns true on success, false if handler/event invalid
function EventBus.Register(eventName, handler)
    if not eventName or not handler then
        return false
    end
    
    -- Initialize handler list if first registration for this event
    if not handlers[eventName] then
        handlers[eventName] = {}
        eventFrame:RegisterEvent(eventName)  -- Register with WoW event system
    end
    
    table.insert(handlers[eventName], handler)
    return true
end

-- Unregister a specific handler from an event
-- Returns true if unregistered, false if not found
function EventBus.Unregister(eventName, handler)
    if not eventName or not handlers[eventName] then
        return false
    end
    
    for i, h in ipairs(handlers[eventName]) do
        if h == handler then
            table.remove(handlers[eventName], i)
            -- Unregister from WoW if no more handlers
            if #handlers[eventName] == 0 then
                eventFrame:UnregisterEvent(eventName)
                handlers[eventName] = nil
            end
            return true
        end
    end
    return false
end

-- ============================================================================
-- Event Triggering
-- ============================================================================

-- Trigger a custom event (fires all registered handlers)
-- Used for internal addon communication, not WoW events
function EventBus.Trigger(eventName, ...)
    if not handlers[eventName] then
        return
    end
    
    for _, handler in ipairs(handlers[eventName]) do
        if handler then
            xpcall(handler, geterrorhandler(), ...)
        end
    end
end

-- ============================================================================
-- Internal Event Dispatching
-- ============================================================================

-- Dispatch WoW events to registered handlers (called by frame script)
local function dispatchEvent(event, ...)
    if not handlers[event] then
        return
    end
    
    -- Call each registered handler, catching errors to prevent handler crashes
    -- from breaking other handlers
    for _, handler in ipairs(handlers[event]) do
        if handler then
            xpcall(handler, geterrorhandler(), event, ...)
        end
    end
end

-- Set up the frame to forward all WoW events to our dispatcher
eventFrame:SetScript("OnEvent", function(self, event, ...)
    dispatchEvent(event, ...)
end)

_G.Nozmie_EventBus = EventBus
return EventBus
