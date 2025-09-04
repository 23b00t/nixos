return {
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        ruby = { "formatter" },
        eruby = { "erb_format" },
        -- php = { "php_cs_fixer_custom" }, -- benutzerdefinierter Formatter-Name
        -- php = { "php_cs_fixer" },
        -- php = { "phpstan" }
      },
    --   formatters = {
    --     php_cs_fixer_custom = {
    --       command = "php-cs-fixer",
    --       args = function(ctx)
    --         return {
    --           "fix",
    --           "--config=/home/user/.php-cs-fixer.dist.php",
    --           "--quiet",
    --           ctx.filename,
    --         }
    --       end,
    --       stdin = false,
    --     },
    --   },
    },
  },
}
