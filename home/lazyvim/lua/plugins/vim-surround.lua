return {
  {
    "tpope/vim-surround",
    keys = {
      { "S", "<Plug>VSurround", mode = "v", desc = "Surround selection" },
      { "cs", "<Plug>VSurroundChange", mode = "n", desc = "Change surround" },
      { "ds", "<Plug>Dsurround", mode = { "n", "o" }, desc = "Delete surround" },
    },
  },
}
