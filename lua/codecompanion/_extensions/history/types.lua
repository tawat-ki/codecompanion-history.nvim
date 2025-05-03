---@meta CodeCompanion.Extension
---
---@class CodeCompanion.Extension
---@field setup fun(opts: table): any Function called when extension is loaded
---@field exports? table Optional table of functions exposed via codecompanion.extensions.name

---@class Chat
---@field opts {title:string, save_id: string}
---@diagnostic disable-next-line: duplicate-doc-field
---@field messages ChatMessage[]
---@field id number
---@field bufnr number
---@field settings table
---@field adapter table
---@field refs table
---@field tools {schemas: table, in_use: table}
---@field references table
---@field subscribers {subscribe: function}
---@field ui {is_active: function, hide: function, open: function}

---@class ChatMessage
---@field role string
---@field content string
---@field tool_calls table
---@field opts? {visible?: boolean, tag?: string}

---@class ChatData
---@field save_id string
---@field title? string
---@field messages ChatMessage[]
---@field updated_at number
---@field refs? table
---@field schemas? table
---@field in_use? table
---@field name? string

---@class UIHandlers
---@field on_preview fun(chat_data: ChatData): string[]
---@field on_delete fun(chat_data: ChatData)
---@field on_select fun(chat_data: ChatData)

---@class BufferInfo
---@field bufnr number
---@field name string
---@field filename string
---@field is_visible boolean
---@field is_modified boolean
---@field is_loaded boolean
---@field lastused number
---@field windows number[]
---@field winnr number
---@field cursor_pos? number[]

---@class EditorInfo
---@field last_active BufferInfo|nil
---@field buffers BufferInfo[]

return {}
