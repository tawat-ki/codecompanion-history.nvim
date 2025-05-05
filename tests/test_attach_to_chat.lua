local h = require("tests.helpers")
local eq, new_set = MiniTest.expect.equality, MiniTest.new_set
local T = new_set()

local child = h.new_child_neovim()
T = new_set({
    hooks = {
        pre_case = function()
            child.setup()
            child.lua([[
              h = require('tests.helpers')
              cc_h = require('tests.cc_helpers')
              codecompanion = cc_h.setup_plugin({
                extensions = {
                  history = {
                    enabled = true,
                    opts = {
                      keymap = "gh",
                      auto_generate_title = true,
                      continue_last_chat = false,
                      delete_on_clearing_chat = false,
                      picker = "default", -- Use default picker to avoid telescope dependency
                      enable_logging = true,
                      dir_to_save = vim.fn.stdpath("data") .. "/codecompanion-history-test",
                    }
                  }
                }
              })
            History = require("codecompanion._extensions.history").History
            History._get_title = function()
              return "AutoSavingChat"
            end
            ]])
        end,
        post_case = function()
            child.lua([[
              --delete the test history folder
              local folder = vim.fn.stdpath("data") .. "/codecompanion-history-test"
              if vim.fn.isdirectory(folder) == 1 then
                vim.fn.delete(folder, "rf")
              end
              ]])
        end,
        post_once = child.stop,
    },
})

T["should attach to new chat"] = function()
    local result = child.lua([[
    chat = codecompanion.toggle()
    --wait for the event to trigger and actually update the title
    vim.wait(200)
    local bufnr = chat.bufnr
    return {
      name = vim.api.nvim_buf_get_name(bufnr),
      save_id = chat.opts.save_id,
      subscribers = #chat.subscribers.queue,
      subscriber_name = chat.subscribers.queue[1].data.name
    }
  ]])
    ---actual bufname will be like path .. "AutoSavingChat"
    if not vim.endswith(result.name, "AutoSavingChat") then
        error("default title should be set")
    end
    eq(true, type(result.save_id) == "string")
    eq(1, result.subscribers)
    eq("save_messages_and_generate_title", result.subscriber_name)
end

T["should use saved data to attach to chat"] = function()
    local result = child.lua([[

    local chat = require("codecompanion.strategies.chat").new({
        context = { bufnr = 1, filetype = "lua" },
        adapter = "test_adapter",
        title = "Saved Title",
        save_id = "test_save_id"
    })
    --wait for the event to trigger and actually update the title
    vim.wait(200)
    local bufnr = chat.bufnr
    return {
      name = vim.api.nvim_buf_get_name(bufnr),
      save_id = chat.opts.save_id,
      subscribers = #chat.subscribers.queue,
      subscriber_name = chat.subscribers.queue[1].data.name
    }
  ]])
    if not vim.endswith(result.name, "Saved Title") then
        error("Chat buffer name should be updated")
    end
    eq("test_save_id", result.save_id)
    eq(1, result.subscribers)
    eq("save_messages_and_generate_title", result.subscriber_name)
end

T["should reset chat data on 'ChatCleared' event"] = function()
    local result = child.lua([[
    local chat = require("codecompanion.strategies.chat").new({
        context = { bufnr = 1, filetype = "lua" },
        adapter = "test_adapter",
        title = "Saved Title",
        save_id = "test_save_id"
    })
    vim.wait(200)
    chat:clear()
    --wait for "ChatCleared" event to trigger
    vim.wait(200)
    local bufnr = chat.bufnr
    return {
      name = vim.api.nvim_buf_get_name(bufnr),
      save_id = chat.opts.save_id,
      title = chat.opts.title,
    }
  ]])
    eq(true, result.save_id ~= "test_save_id")
    eq(true, result.save_id ~= nil)
    eq(result.title, nil)
    eq(true, not vim.endswith(result.name, "Saved Title"))
    eq(true, vim.endswith(result.name, "AutoSavingChat"))
end

T["should save chat on getting llm response"] = function()
    local result = child.lua([[
    local tool_call = {
        id = 1,
        type = "function",
        ["function"] = {
          name = "weather",
          arguments = {
            location = "London, UK",
            units = "celsius",
          },
        },
    }
    cc_h.mock_submit("Mocked Response", {tool_call} , "success")
    local chat = require("codecompanion.strategies.chat").new({
        context = { bufnr = 1, filetype = "lua" },
        adapter = "test_adapter",
        title = "Saved Title",
        save_id = "test_save_id"
    })
    chat.tools:add("weather", chat.agents.tools_config.weather)
    table.insert(chat.messages,{
      role= "user",
      content= "User Message"
    })
    vim.wait(200)
    chat:submit()
    vim.wait(200)
    local chats = codecompanion.extensions.history.get_chats()
    local chat_data = codecompanion.extensions.history.load_chat("test_save_id")
    return {
      chat = chats['test_save_id'],
      tool_output = _G.weather_output,
      chat_data = chat_data,
      location = codecompanion.extensions.history.get_location()
    }
  ]])
    eq(true, result.chat ~= nil)
    eq("Saved Title", result.chat.title)
    eq(true, result.location == vim.fn.stdpath("data") .. "/codecompanion-history-test")
    eq(true, result.chat_data ~= nil)
    eq(#result.chat_data.messages, 5)
    eq(result.chat_data.messages[1].content, "default system prompt")
    --check if mocked response is saved
    eq(result.chat_data.messages[3].content, "Mocked Response")
    -- eq("The weather in London, UK is 15° celsius", result.tool_output)
    eq("Ran the weather tool The weather in London, UK is 15° celsius", result.chat_data.messages[5].content)
end

return T
