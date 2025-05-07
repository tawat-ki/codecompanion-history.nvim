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
        main = { file = false, float = true },
        format = function(item)
            local is_current = current_save_id and current_save_id == item.save_id
            local relative_time = utils.format_relative_time(item.updated_at)
            return { { string.format("%s %s (%s)", is_current and "🌟" or " ", item.name, relative_time) } }
        end,
        transform = function(item)
            item.file = item.save_id
        end,
        preview = function(ctx)
            local item = ctx.item
            local lines = self.handlers.on_preview(item)
            if not lines then
                return
            end

            local buf_id = ctx.preview:scratch()
            vim.bo[buf_id].filetype = "codecompanion"
            vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
        end,
        confirm = function(picker, _)
            local items = picker:selected({ fallback = true })
            if items then
                vim.iter(items):each(function(item)
                    self.handlers.on_select(item)
                end)
            end
            picker:close()
        end,
        actions = {
            delete_chat = function(picker)
                local selections = picker:selected({ fallback = true })
                if #selections == 0 then
                    return
                end

                -- Confirm deletion for multiple items
                if #selections > 1 then
                    local choice = vim.fn.confirm(
                        "Are you sure you want to delete " .. #selections .. " items? (y/n)",
                        "&Yes\n&No"
                    )
                    if choice ~= 1 then
                        return
                    end
                end

                for _, selected in ipairs(selections) do
                    self.handlers.on_delete(selected)
                end
                picker:close()
                self.handlers.on_open()
            end,
        },

        win = {
            input = {
                keys = {
                    ["d"] = "delete_chat",
                },
            },
            list = {
                keys = {
                    ["d"] = "delete_chat",
                },
            },
        },
    })
end

return SnacksPicker
