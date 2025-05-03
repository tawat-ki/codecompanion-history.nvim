# CodeCompanion History Extension

A history management extension for [codecompanion.nvim](https://codecompanion.olimorris.dev/) that enables saving, browsing and restoring chat sessions.

## Features

- 🔄 Automatic chat session saving with context preservation
- 🎯 Smart title generation for chats 
- 📚 Browse saved chats with preview
- 🔍 Multiple picker interfaces
- ⚡ Restore chat sessions with full context and tools state

## How It Works

The extension enhances CodeCompanion by providing:

```mermaid
graph TD
A[Chat Created Event] --> B(Extension: Init & Subscribe);
B --> C(Extension: Setup Auto-Save & Auto-Title);
C --> D{Chat Submitted};
D --> E[LLM Response Received];
E --> F(Extension: Subscriber Triggered);
F --> G(Extension: Auto-Save Chat State);
G --> H{No Title & Auto-Title Enabled?};
H -- Yes --> I(Extension: Generate & Save Title);
H -- No --> D;
I --> D;

subgraph End Chat
D -- Cleared --> J[Chat Cleared Event];
E -- Cleared --> J;
J --> K(Extension: Respond to Clear Event);
K --> L(Extension: Delete Chat from Storage);
L --> M(Extension: Reset Extension State);
end

subgraph History Interaction
P[User Action (gh / :CodeCompanionHistory)] --> Q{History Browser};
Q -- Restore --> R(Extension: Load Chat State);
R --> A; %% Restore re-creates a chat
Q -- Delete --> L; %% Delete triggers extension cleanup
end
```

Here's what's happening in simple terms:

1. When you create a new chat, our extension jumps in and sets up two things:
   - An autosave system that will save your chat
   - A title generator that will name your chat based on the conversation

2. As you chat:
   - Every time you get a response, our extension automatically saves everything 
   - If your chat doesn't have a title yet, it tries to create one that makes sense
   - All your messages, tools, and references are safely stored

3. When you clear a chat:
   - Our extension knows to remove it from storage
   - This keeps your history clean and organized

4. Any time you want to look at old chats:
   - Use `gh` or the command to open the history browser
   - Pick any chat to restore it completely
   - Or remove ones you don't need anymore

## Requirements

- Neovim >= 0.8.0
- [codecompanion.nvim](https://codecompanion.olimorris.dev/)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (optional, for enhanced picker)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "olimorris/codecompanion.nvim",
    dependencies = {
        --other plugins
        "ravitemer/codecompanion-history.nvim"
    }
}
```

```lua
require("codecompanion").setup({
    extensions = {
        history = {
            enabled = true,
            opts = {
                -- Automatically generate titles for new chats
                auto_generate_title = true,
                -- Default buffer title when no title is set
                default_buf_title = "[CodeCompanion]",
                -- Keymap to open history from chat buffer (default: gh)
                keymap = "gh",
                -- Picker interface ("telescope" or "default")
                picker = "telescope", 
            }
        }
    }
})
```

## Usage 

### Commands

- `:CodeCompanionHistory` - Open the history browser

### Chat Buffer Keymaps

- `gh` - Open history browser (customizable via `opts.keymap`)

### History browser

The history browser shows all your saved chats with:
- Title (auto-generated or custom)
- Last updated time  
- Preview of chat contents

Actions in history browser:
- `<CR>` - Open selected chat
- `x` - Delete selected chat (Doesn't apply to default vim.ui.select)

### Title Generation

Chat titles are automatically generated based on the context of your conversation. You can:

- Let the extension auto-generate titles (controlled by `auto_generate_title`)
- See the titles updated in real-time as you chat

### API

The extension exports these functions that can be accessed via:

```lua
local history = require("codecompanion").extensions.history
```

#### Functions

- `get_saved_location()` - Get the path where chats are saved

## TODOs

- [ ] Add support for additional pickers like snacks, fzf etc

## License

MIT
