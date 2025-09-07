return {
  "zbirenbaum/copilot.lua",
  cmd = "Copilot",
  build = ":Copilot auth",
  event = "BufReadPost",
  opts = function()
    -- Setup Copilot configuration
    require("copilot").setup({
      suggestion = {
        enabled = true, -- Enable shadow-text suggestions
        auto_trigger = true, -- Automatically trigger suggestions
        debounce = 500, -- Set delay for suggestions to 500ms
        hide_during_completion = false, -- Do not hide suggestions during LSP completion
        keymap = {
          accept = "<A-s>", -- Accept suggestion
          next = "<A-n>", -- Go to the next suggestion
          prev = "<A-b>", -- Go to the previous suggestion
          dismiss = "<C-c>", -- Dismiss the current suggestion
          accept_word = "<A-w>", -- Accept the current word
          accept_line = "<A-l>", -- Accept the current line
        },
      },
      panel = {
        enabled = true, -- Disable the Copilot panel
      },
      chat = {
        enabled = true, -- Enable Copilot Chat
        follow_up_mode = true, -- Allow follow-up questions in the same chat context
      },
      -- Enable Copilot for all filetypes
      filetypes = {
        ["*"] = true, -- Enable Copilot for all filetypes
      },
      -- Optionally disable Copilot for specific filetypes
      -- filetypes_exclude = {
      --   "plaintext", -- Example: disable for plaintext files
      --   "log", -- Example: disable for log files
      -- },
    })

    -- Update LazyVim's cmp.actions to handle Copilot suggestions
    LazyVim.cmp.actions.ai_accept = function()
      return false
    end
  end,
}
