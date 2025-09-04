return {
  {
    "folke/edgy.nvim",
    optional = true,
    opts = function(_, opts)
      -- opts.right = opts.right or {}
      -- table.insert(opts.right, {
      --   title = "Database",
      --   ft = "dbui",
      --   pinned = true,
      --   width = 0.5,
      --   open = function()
      --     vim.cmd("DBUI")
      --   end,
      -- })
      --
      -- opts.bottom = opts.bottom or {}
      -- table.insert(opts.bottom, {
      --   title = "DB Query Result",
      --   ft = "dbout",
      -- })

      opts.right = opts.right or {}
      table.insert(opts.right, {
        ft = "copilot-chat",
        title = "Copilot Chat",
        size = { width = 50 },
      })
    end,
  },
}
