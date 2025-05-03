---@class History
---@field opts HistoryOpts
---@field storage Storage
---@field title_generator TitleGenerator
---@field ui UI
---@field new fun(opts: HistoryOpts): History

local History = {}

---@class HistoryOpts
local default_opts = {
    auto_generate_title = true,
    default_buf_title = "[CodeCompanion] " .. " ",
    keymap = "gh",
    ---@type Pickers
    picker = "telescope",
}

---@type History|nil
local history_instance

---@param opts HistoryOpts
---@return History
function History.new(opts)
    local history = setmetatable({}, {
        __index = History,
    })
    history.opts = opts
    history.storage = require("codecompanion._extensions.history.storage").new()
    history.title_generator = require("codecompanion._extensions.history.title_generator").new(opts)
    history.ui = require("codecompanion._extensions.history.ui").new(opts, history.storage, history.title_generator)
    -- Setup commands
    history:_create_commands()
    history:_setup_autocommands()
    history:_setup_keymaps()
    return history --[[@as History]]
end

function History:_create_commands()
    vim.api.nvim_create_user_command("CodeCompanionHistory", function()
        self.ui:open_saved_chats()
    end, {
        desc = "Open saved chats",
    })
end

function History:_setup_autocommands()
    local group = vim.api.nvim_create_augroup("CodeCompanionHistory", { clear = true })
    -- util.fire("ChatCreated", { bufnr = self.bufnr, from_prompt_library = self.from_prompt_library, id = self.id })
    vim.api.nvim_create_autocmd("User", {
        pattern = "CodeCompanionChatCreated",
        group = group,
        callback = vim.schedule_wrap(function(opts)
            -- data = {
            --   bufnr = 5,
            --   from_prompt_library = false,
            --   id = 7463137
            -- },
            local chat_module = require("codecompanion.strategies.chat")
            local bufnr = opts.data.bufnr
            local chat = chat_module.buf_get_chat(bufnr)
            -- Set initial buffer title if present that we passed while creating a chat from history
            if chat.opts.title then
                self.ui:_set_buf_title(chat.bufnr, chat.opts.title)
            else
                --set title to tell that this is a auto saving chat
                self.ui:_set_buf_title(chat.bufnr, self:_get_title(chat))
            end
            --Check if out custom save_id is present, else generate a new one to be used to save the chat
            if not chat.opts.save_id then
                chat.opts.save_id = tostring(os.time() + math.random(10000))
            end
            self:_subscribe_to_chat(chat)
        end),
    })

    vim.api.nvim_create_autocmd("User", {
        pattern = "CodeCompanionChatCleared",
        group = group,
        callback = vim.schedule_wrap(function(opts)
            -- data = {
            --   bufnr = 5,
            --   id = 7463137
            -- },
            local chat_module = require("codecompanion.strategies.chat")
            local bufnr = opts.data.bufnr
            local chat = chat_module.buf_get_chat(bufnr)
            self.ui:_set_buf_title(chat.bufnr, self:_get_title(chat))
            self.storage:delete_chat(chat.opts.save_id)
            --set title to nil so that we can generate it again
            chat.opts.title = nil
            --generate a new save_id to be used to save the chat
            chat.opts.save_id = tostring(os.time() + math.random(10000))
        end),
    })
end

---@param chat Chat
---@param title? string
---@return string
function History:_get_title(chat, title)
    return title and title or (self.opts.default_buf_title .. " " .. chat.id)
end

function History:_setup_keymaps()
    require("codecompanion.config").strategies.chat.keymaps["Saved Chats"] = {
        modes = {
            n = self.opts.keymap,
        },
        description = "Browse Saved Chats",
        callback = function(_)
            self.ui:open_saved_chats()
        end,
    }
end

---@param chat Chat
function History:_subscribe_to_chat(chat)
    -- Add subscription to save chat on every response from llm
    chat.subscribers:subscribe({
        id = "save_messages_and_generate_title",
        --INFO:data field is needed
        data = {},
        callback = function(chat_instance)
            if self.opts.auto_generate_title and not chat_instance.opts.title then
                self.title_generator:generate(chat_instance, function(generated_title)
                    if generated_title and generated_title ~= "" then
                        self.ui:_set_buf_title(chat_instance.bufnr, generated_title)
                        if generated_title == "Deciding title..." then
                            return
                        end
                        chat_instance.opts.title = generated_title
                        --save the title to history
                        self.storage:save_chat(chat_instance)
                    else
                        self.ui:_set_buf_title(chat_instance.bufnr, self:_get_title(chat_instance))
                    end
                end)
            end
            self.storage:save_chat(chat_instance)
        end,
    })
end

---@type CodeCompanion.Extension
return {
    ---@param opts HistoryOpts
    setup = function(opts)
        if not history_instance then
            history_instance = History.new(vim.tbl_deep_extend("force", default_opts, opts or {}))
        end
    end,
    exports = {
        ---@return string filepath
        get_saved_location = function()
            return History.opts.file_path
        end,
    },
}
