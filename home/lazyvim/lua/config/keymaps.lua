-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here


vim.keymap.set('n', '<A-h>', '<C-w>h')
vim.keymap.set('n', '<A-j>', '<C-w>j')
vim.keymap.set('n', '<A-k>', '<C-w>k')
vim.keymap.set('n', '<A-l>', '<C-w>l')

vim.keymap.set({ "n" }, "<leader>bc", "<cmd>e #<cr>", { desc = "Switch to other buffer", silent = true })

vim.keymap.set({ "n" }, "<leader>bb", "<cmd>BufferLineCyclePrev<cr>", { desc = "Buffer back", silent = true })
vim.keymap.set({ "n" }, "<leader>bn", "<cmd>BufferLineCycleNext<cr>", { desc = "Buffer next", silent = true })
vim.keymap.set({ "n" }, "<leader>bf", function()
  Snacks.picker.buffers()
end, { desc = "Buffer find", silent = true })

-- Phpactor keymaps
--
-- vim.keymap.set("n", "<leader>cp", function()
--   vim.ui.select({
--     "Context Menu",
--     "Generate Accessors",
--     "Transform",
--     "Extract Constant",
--     "Extract Method",
--     "Extract Variable",
--   }, {
--     prompt = "Phpactor Actions:",
--   }, function(choice)
--     if choice == "Context Menu" then
--       vim.api.nvim_command("Phpactor context_menu")
--     elseif choice == "Generate Accessors" then
--       vim.api.nvim_command("Phpactor generate_accessors")
--     elseif choice == "Transform" then
--       vim.api.nvim_command("Phpactor transform")
--     elseif choice == "Extract Constant" then
--       vim.api.nvim_command("Phpactor extract_constant")
--     elseif choice == "Extract Method" then
--       vim.api.nvim_command("Phpactor extract_method")
--     elseif choice == "Extract Variable" then
--       vim.api.nvim_command("Phpactor extract_expression")
--     end
--   end)
-- end, { desc = "Phpactor: Actions Menu" })
