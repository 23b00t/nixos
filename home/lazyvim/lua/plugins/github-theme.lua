-- ~/.config/nvim/lua/plugins/github-theme.lua
return {
  "projekt0n/github-nvim-theme",
  priority = 1000,
  config = function()
    require("github-theme").setup({
      options = {
        styles = {
          comments = "italic",
          keywords = "bold",
        },
      },
    })
    -- vim.cmd("colorscheme github_dark_dimmed")
  end,
}
