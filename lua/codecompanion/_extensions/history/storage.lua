---@class Storage
---@field base_path string Base directory path
---@field index_path string Path to index file
---@field chats_dir string Path to chats directory
local Storage = {}

-- File I/O utility functions
local FileUtils = {}

---Read and decode a JSON file
---@param file_path string Path to the file
---@return {ok: boolean, data: table|nil, error: string|nil} Result
function FileUtils.read_json(file_path)
    local Path = require("plenary.path")
    local path = Path:new(file_path)

    if not path:exists() then
        return { ok = false, data = nil, error = "File does not exist: " .. file_path }
    end

    local content, read_error = path:read()
    if not content then
        return { ok = false, data = nil, error = "Failed to read file: " .. (read_error or "unknown error") }
    end

    local success, data = pcall(vim.json.decode, content)
    if not success then
        return { ok = false, data = nil, error = "Failed to parse JSON: " .. tostring(data) }
    end

    return { ok = true, data = data, error = nil }
end

---Write data to a JSON file
---@param file_path string Path to the file
---@param data table Data to write
---@return {ok: boolean, error: string|nil} Result
function FileUtils.write_json(file_path, data)
    local Path = require("plenary.path")
    local path = Path:new(file_path)

    -- Ensure parent directory exists
    local parent = path:parent()
    if not parent:exists() then
        parent:mkdir({ parents = true })
    end

    -- Fix: Ensure data is a table
    if type(data) ~= "table" then
        return { ok = false, error = "Cannot encode non-table data" }
    end

    local encoded, encode_error = vim.json.encode(data)
    if not encoded then
        return { ok = false, error = "Failed to encode JSON: " .. (encode_error or "unknown error") }
    end

    local success, write_error = pcall(function()
        return path:write(encoded, "w")
    end)
    if not success then
        return { ok = false, error = "Failed to write file: " .. (write_error or "unknown error") }
    end

    return { ok = true, error = nil }
end

---Delete a file
---@param file_path string Path to the file
---@return {ok: boolean, error: string|nil} Result
function FileUtils.delete_file(file_path)
    local Path = require("plenary.path")
    local path = Path:new(file_path)

    if not path:exists() then
        return { ok = true, error = nil } -- File doesn't exist, consider it success
    end

    local success, err = pcall(function()
        return path:rm()
    end)
    if not success then
        return { ok = false, error = "Failed to delete file: " .. (err or "unknown error") }
    end

    return { ok = true, error = nil }
end

---@return Storage
function Storage.new()
    local self = setmetatable({}, {
        __index = Storage,
    })

    -- Set up fixed paths in the data directory
    self.base_path = vim.fn.stdpath("data") .. "/codecompanion-history"
    self.index_path = self.base_path .. "/index.json"
    self.chats_dir = self.base_path .. "/chats"

    -- Ensure storage directories exist
    self:_ensure_storage_dirs()

    return self
end

function Storage:_ensure_storage_dirs()
    local Path = require("plenary.path")

    -- Create base directory
    local base_dir = Path:new(self.base_path)
    if not base_dir:exists() then
        base_dir:mkdir({ parents = true })
    end

    -- Create chats directory
    local chats_dir = Path:new(self.chats_dir)
    if not chats_dir:exists() then
        chats_dir:mkdir({ parents = true })
    end

    -- Initialize index file if it doesn't exist
    local index_path = Path:new(self.index_path)
    if not index_path:exists() then
        local empty_index = {}
        local result = FileUtils.write_json(self.index_path, empty_index)
        if not result.ok then
            vim.notify("Failed to initialize index file: " .. result.error, vim.log.levels.ERROR)
        end
    end
end

---@param chat_data ChatData
---@return {ok: boolean, error: string|nil}
function Storage:_save_chat_to_file(chat_data)
    local chat_path = self.chats_dir .. "/" .. chat_data.save_id .. ".json"
    return FileUtils.write_json(chat_path, chat_data)
end

---@param chat_data ChatData
---@return {ok: boolean, error: string|nil}
function Storage:_update_index_entry(chat_data)
    -- Read current index
    local index_result = FileUtils.read_json(self.index_path)
    if not index_result.ok then
        return { ok = false, error = "Failed to read index: " .. index_result.error }
    end

    -- Ensure we have a table to work with
    local index = index_result.data or {}

    -- Update index with minimal metadata
    index[chat_data.save_id] = {
        save_id = chat_data.save_id,
        title = chat_data.title,
        updated_at = chat_data.updated_at,
    }

    -- Write updated index
    return FileUtils.write_json(self.index_path, index)
end

---Load all chats from storage (index only)
---@return table<string, ChatData>
function Storage:load_chats()
    local result = FileUtils.read_json(self.index_path)
    if not result.ok then
        if result.error:match("does not exist") then
            -- If index doesn't exist, initialize it
            self:_ensure_storage_dirs()
            return {}
        else
            vim.notify("Failed to read chat index: " .. result.error, vim.log.levels.ERROR)
            return {}
        end
    end

    -- Ensure we return a table even if data is nil
    return result.data or {}
end

---Load a specific chat by ID
---@param id string
---@return ChatData|nil
function Storage:load_chat(id)
    local chat_path = self.chats_dir .. "/" .. id .. ".json"
    local result = FileUtils.read_json(chat_path)

    if not result.ok then
        if not result.error:match("does not exist") then
            vim.notify("Failed to load chat: " .. result.error, vim.log.levels.ERROR)
        end
        return nil
    end

    return result.data
end

---Save a chat to storage
---@param chat Chat
function Storage:save_chat(chat)
    local save_id = chat.opts.save_id
    if not save_id then
        vim.notify("Can't save chat with no id", vim.log.levels.ERROR)
        return
    end

    -- Create chat data object
    local chat_data = {
        save_id = save_id,
        title = chat.opts.title,
        messages = chat.messages,
        updated_at = os.time(),
        refs = chat.refs,
        schemas = chat.tools.schemas,
        in_use = chat.tools.in_use,
    }

    -- Save chat to file
    local save_result = self:_save_chat_to_file(chat_data)
    if not save_result.ok then
        vim.notify("Failed to save chat: " .. save_result.error, vim.log.levels.ERROR)
        return
    end

    -- Update index
    local index_result = self:_update_index_entry(chat_data)
    if not index_result.ok then
        vim.notify("Failed to update index: " .. index_result.error, vim.log.levels.ERROR)
    end
end

---Delete a chat from storage
---@param id string
function Storage:delete_chat(id)
    if not id then
        vim.notify("Can't delete chat with no id", vim.log.levels.ERROR)
        return
    end

    -- Delete the chat file
    local chat_path = self.chats_dir .. "/" .. id .. ".json"
    local delete_result = FileUtils.delete_file(chat_path)
    if not delete_result.ok then
        vim.notify("Failed to delete chat file: " .. delete_result.error, vim.log.levels.ERROR)
    end

    -- Remove from index
    local index_result = FileUtils.read_json(self.index_path)
    if not index_result.ok then
        vim.notify("Failed to read index for deletion: " .. index_result.error, vim.log.levels.ERROR)
        return
    end

    -- Ensure we have a table to work with
    local index = index_result.data or {}

    -- Remove entry from index
    index[id] = nil

    -- Save updated index
    local write_result = FileUtils.write_json(self.index_path, index)
    if not write_result.ok then
        vim.notify("Failed to update index after deletion: " .. write_result.error, vim.log.levels.ERROR)
    end
end

return Storage
