local DefaultPicker = require("codecompanion._extensions.history.pickers.default")
local utils = require("codecompanion._extensions.history.utils")

---@class SnacksPicker : DefaultPicker
local SnacksPicker = setmetatable({}, {
    __index = DefaultPicker,
})
SnacksPicker.__index = SnacksPicker

---@param current_save_id? string
function SnacksPicker:browse(current_save_id)
    require("snacks.picker").pick({
        title = "Saved Chats",
        items = self.chats,
        format = function(item)
            local is_current = current_save_id and current_save_id == item.save_id
            local relative_time = utils.format_relative_time(item.updated_at)
            return { { string.format("%s %s (%s)", is_current and "🌟" or " ", item.name, relative_time) } }
        end,
        preview = function(ctx)
            local item = ctx.item
            local lines = self.handlers.on_preview(item)
            local buf_id = ctx.preview:scratch()
            vim.treesitter.start(buf_id, "markdown")
            vim.bo[buf_id].filetype = "markdown"
            vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
        end,
    })
end

return SnacksPicker
