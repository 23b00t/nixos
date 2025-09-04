-- Funktionen zur Erkennung von ILIAS-Projekten und Konfigurationen
local function is_ilias_project()
  -- Prüfe auf typische ILIAS-Dateien oder -Verzeichnisse
  local ilias_markers = {
    "ilias.php",
    "Services",
    "Modules",
    "setup",
  }

  local current_dir = vim.fn.getcwd()
  for _, marker in ipairs(ilias_markers) do
    if
      vim.fn.filereadable(current_dir .. "/" .. marker) == 1
      or vim.fn.isdirectory(current_dir .. "/" .. marker) == 1
    then
      return true, current_dir
    end
  end

  return false, nil
end

local in_ilias, ilias_root = is_ilias_project()

-- Pfade zu Konfigurationsdateien finden
local php_cs_fixer_config = nil
local phpstan_config = nil
local phpcs_config = nil

if in_ilias then
  -- Suche nach ILIAS-spezifischen Konfigurationen
  if vim.fn.filereadable(ilias_root .. "/CI/PHPStan/phpstan.neon") == 1 then
    phpstan_config = ilias_root .. "/CI/PHPStan/phpstan.neon"
  end

  if vim.fn.filereadable(ilias_root .. "/.php-cs-fixer.dist.php") == 1 then
    php_cs_fixer_config = ilias_root .. "/.php-cs-fixer.dist.php"
  end

  if vim.fn.filereadable(ilias_root .. "/CI/PHPCS/ruleset.xml") == 1 then
    phpcs_config = ilias_root .. "/CI/PHPCS/ruleset.xml"
  end
end

-- LazyVim Plugin-Konfigurationen
return {
  -- 1. PHP-Sprachunterstützung
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      if type(opts.ensure_installed) == "table" then
        vim.list_extend(opts.ensure_installed, { "php" })
      end
    end,
  },

  -- 2. Formatierung mit conform.nvim
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        php = { "php_cs_fixer" },
      },
      formatters = {
        php_cs_fixer = {
          command = "php-cs-fixer",
          args = function(ctx)
            local args = { "fix", "--quiet" }

            if php_cs_fixer_config then
              table.insert(args, "--config=" .. php_cs_fixer_config)
            end

            table.insert(args, ctx.filename)
            return args
          end,
          stdin = false,
        },
      },
    },
  },

  -- 3. Linting mit nvim-lint
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters_by_ft = {
        php = { "phpcs", "phpstan" },
      },
      linters = {
        phpcs = {
          cmd = "phpcs",
          args = function()
            local args = { "--report=json", "-s" }

            if phpcs_config then
              table.insert(args, "--standard=" .. phpcs_config)
            end

            return args
          end,
          stdin = true,
        },
        phpstan = {
          cmd = "phpstan",
          args = function()
            local args = { "analyze", "--error-format=raw", "--no-progress" }

            if phpstan_config then
              table.insert(args, "--configuration=" .. phpstan_config)
            else
              table.insert(args, "--level=5")
            end

            -- Zielverzeichnis
            local target = in_ilias and "." or "src"
            table.insert(args, target)

            return args
          end,
          stdin = false,
          stream = "stdout",
          ignore_exitcode = true,
          parser = require("lint.parser").from_errorformat("%f:%l:%c: %m", {
            source = "phpstan",
          }),
        },
      },
    },
  },

  -- 4. LSP-Konfiguration für PHP
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        intelephense = {
          settings = {
            intelephense = {
              stubs = {
                "apache",
                "bcmath",
                "bz2",
                "calendar",
                "Core",
                "curl",
                "date",
                "dba",
                "dom",
                "enchant",
                "fileinfo",
                "filter",
                "ftp",
                "gd",
                "gettext",
                "hash",
                "iconv",
                "imap",
                "intl",
                "json",
                "ldap",
                "libxml",
                "mbstring",
                "mysqli",
                "mysqlnd",
                "oci8",
                "openssl",
                "pcntl",
                "pcre",
                "PDO",
                "pdo_mysql",
                "Phar",
                "readline",
                "recode",
                "Reflection",
                "regex",
                "session",
                "SimpleXML",
                "soap",
                "sockets",
                "sodium",
                "SPL",
                "standard",
                "superglobals",
                "tokenizer",
                "xml",
                "xmlreader",
                "xmlrpc",
                "xmlwriter",
                "xsl",
                "Zend OPcache",
                "zip",
                "zlib",
              },
              environment = {
                includePaths = in_ilias and { ilias_root } or {},
              },
              files = {
                maxSize = 5000000,
              },
            },
          },
        },
      },
    },
  },

  -- 5. none-ls.nvim Konfiguration (falls benötigt)
  {
    "nvimtools/none-ls.nvim",
    optional = true,
    opts = function(_, opts)
      local nls = require("null-ls")

      -- Bestehende PHP-bezogene Quellen entfernen
      opts.sources = vim.tbl_filter(function(source)
        return source.name ~= "phpcs" and source.name ~= "phpstan" and source.name ~= "php_cs_fixer"
      end, opts.sources or {})

      -- PHPStan als Linter hinzufügen
      if phpstan_config then
        table.insert(
          opts.sources,
          nls.builtins.diagnostics.phpstan.with({
            command = "phpstan",
            args = {
              "analyse",
              "--configuration",
              phpstan_config,
              "--error-format",
              "raw",
              "--no-progress",
              "--",
              ".",
            },
          })
        )
      else
        table.insert(opts.sources, nls.builtins.diagnostics.phpstan)
      end

      -- PHP-CS-Fixer als Formatter hinzufügen
      if php_cs_fixer_config then
        table.insert(
          opts.sources,
          nls.builtins.formatting.phpcsfixer.with({
            command = "php-cs-fixer",
            args = {
              "fix",
              "--config=" .. php_cs_fixer_config,
              "--quiet",
              "$FILENAME",
            },
          })
        )
      else
        table.insert(opts.sources, nls.builtins.formatting.phpcsfixer)
      end
    end,
  },
}
