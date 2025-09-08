return {
	{
		"nvimtools/none-ls.nvim",
		opts = function(_, opts)
			-- remove all php-related sources so only nvim-lint runs
			opts.sources = vim.tbl_filter(function(src)
				return not (src.name == "phpcs" or src.name == "phpstan" or src.name == "phpmd" or src.name == "phpcbf")
			end, opts.sources or {})
		end,
	},
}
