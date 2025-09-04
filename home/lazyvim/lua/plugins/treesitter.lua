return {
	-- Completely override the LazyVim treesitter config
	{
		"nvim-treesitter/nvim-treesitter",
		opts = function(_, opts)
			-- Clear the ensure_installed table
			opts.ensure_installed = {}

			-- Disable auto_install
			opts.auto_install = false

			-- Use your existing parsers
			vim.opt.runtimepath:append(vim.fn.stdpath("config") .. "/parser")

			return opts
		end,
	},
}
