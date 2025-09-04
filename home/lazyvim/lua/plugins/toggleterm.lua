return {
  -- { "akinsho/toggleterm.nvim", version = "*", config = true },
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function(_, opts)
      local toggleterm = require("toggleterm")
      toggleterm.setup(opts)

      local Terminal = require("toggleterm.terminal").Terminal

      -- Define terminals outside the keymaps
      local term1 = Terminal:new({
        direction = "horizontal",
        hidden = true,
        count = 1,
        size = { height = 0.4 },
        shell = "zsh",
      })

      local term2 = Terminal:new({
        direction = "vertical",
        hidden = true,
        count = 2,
        size = { width = 0.4 },
        shell = "zsh",
      })

      local term3 = Terminal:new({
        direction = "float",
        hidden = true,
        count = 3,
        shell = "zsh",
      })

      -- Keymaps toggle these exact instances
      vim.keymap.set("n", "<A-1>", function()
        term1:toggle()
      end, { desc = "Toggle Terminal 1 (horizontal)" })

      vim.keymap.set("n", "<A-2>", function()
        term2:toggle()
      end, { desc = "Toggle Terminal 2 (vertical)" })

      vim.keymap.set("n", "<A-3>", function()
        term3:toggle()
      end, { desc = "Toggle Terminal 3 (float)" })
    end,
  },
}
