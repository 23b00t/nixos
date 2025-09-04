return {
  {
    "AndrewRadev/inline_edit.vim",
    lazy = true,
    cmd = { "InlineEdit" },
    keys = {
      { "<leader>ii", "<cmd>InlineEdit<cr>", desc = "Inline Edit (JS inside <script> html)" },
    },
    config = function()
      vim.g.inline_edit_html_like_filetypes = { "html.erb", "html.twig" }
    end,
  },
}
