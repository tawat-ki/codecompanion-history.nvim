local utils = require("codecompanion._extensions.history.utils")
local DefaultPicker = {}
DefaultPicker.__index = DefaultPicker

---@class  DefaultPicker
---@field chats Array
---@field handlers {on_select: function, on_delete: function, on_preview: function}
function DefaultPicker:new(chats, handlers)
	local base = setmetatable({}, self)
	self.chats = chats
	self.handlers = handlers

	return base
end

function DefaultPicker:browse(current_save_id)
	vim.ui.select(self.chats, {
		prompt = "Saved Chats",
		format_item = function(item)
			local is_current = current_save_id and current_save_id == item.save_id
			local relative_time = utils.format_relative_time(item.updated_at)
			return string.format("%s %s (%s)", is_current and "🌟" or " ", item.name, relative_time)
		end,
	}, function(selected)
		if selected then
			self.handlers.on_select(selected)
		end
	end)
end

return DefaultPicker
