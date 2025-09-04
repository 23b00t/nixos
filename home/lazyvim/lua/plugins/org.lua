return {
  {
    "nvim-orgmode/orgmode",
    event = "VeryLazy",
    ft = { "org" },
    config = function()
      -- Setup orgmode
      require("orgmode").setup({
        org_agenda_files = "~/org/**/*",
        org_default_notes_file = "~/org/scratch.org",
        org_startup_indented = true,
        mappings = {
          org_return_uses_meta_return = true,
        },
      })
    end,
  },
}
