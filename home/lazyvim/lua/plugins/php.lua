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

-- Pfad zur PHPStan-Konfigurationsdatei finden
local phpstan_config = nil
if in_ilias and vim.fn.filereadable(ilias_root .. "/CI/PHPStan/phpstan.neon") == 1 then
	phpstan_config = ilias_root .. "/CI/PHPStan/phpstan.neon"
end

-- LazyVim Plugin-Konfigurationen
return {
	{
		"stevearc/conform.nvim",
		optional = true,
		opts = function(_, opts)
			if not in_ilias then
				return
			end

			opts.formatters_by_ft = opts.formatters_by_ft or {}
			opts.formatters_by_ft.php = { "php_cs_fixer" }

			opts.formatters = opts.formatters or {}
			opts.formatters.php_cs_fixer = {
				-- php-cs-fixer findet seine Konfig (.php-cs-fixer.dist.php) automatisch im Projekt-Root.
				-- Daher ist --config meist nicht nötig.
				command = (
					vim.fn.executable(ilias_root .. "/libs/composer/vendor/bin/php-cs-fixer") == 1
					and ilias_root .. "/libs/composer/vendor/bin/php-cs-fixer"
				) or "php-cs-fixer",
				args = { "fix", "$FILENAME", "--quiet" },
				stdin = false, -- Wichtig: Benötigt Dateipfad, nicht stdin
				-- ILIAS nutzt oft LF, falls dein Editor was anderes versucht
				line_ending = "lf",
			}

			return opts
		end,
	},

	{
		"mfussenegger/nvim-lint",
		optional = true,
		opts = function(_, opts)
			if not in_ilias then
				return
			end

			opts.linters_by_ft = opts.linters_by_ft or {}
			opts.linters_by_ft.php = { "phpcs", "phpstan" }

			opts.linters = opts.linters or {}
			opts.linters.phpcs = {
				cmd = (
					vim.fn.executable(ilias_root .. "/libs/composer/vendor/bin/phpcs") == 1
					and ilias_root .. "/libs/composer/vendor/bin/phpcs"
				) or "phpcs",
				args = {
					"--standard=" .. (vim.fn.filereadable(
						ilias_root .. "/libs/composer/vendor/captainhook/captainhook/phpcs.xml"
					) == 1 and ilias_root .. "/libs/composer/vendor/captainhook/captainhook/phpcs.xml" or "PSR12"),
					"--report=json",
					"-",
				},
				stdin = true,
			}

			-- Nur phpstan-Linter hinzufügen, wenn die Konfiguration gefunden wurde
			if phpstan_config then
				opts.linters.phpstan = {
					cmd = ilias_root .. "/libs/composer/vendor/bin/phpstan",
					args = {
						"analyze",
						"--error-format=json",
						"--no-progress",
						"--level=max",
						-- "--configuration=" .. phpstan_config,
					},
					ignore_exitcode = true,
					-- Dein existierender Parser ist großartig und wird hier beibehalten.
					parser = function(output, bufnr)
						if not output or vim.trim(output) == "" then
							return {}
						end
						local json_output = output:gsub("Warning: .-\n", "")
						local ok, data = pcall(vim.json.decode, json_output)
						if not ok or not data.files then
							return {}
						end
						local bufname = vim.api.nvim_buf_get_name(bufnr)
						local file
						for k, v in pairs(data.files) do
							if k == bufname or k:match(vim.fn.fnamemodify(bufname, ":p")) then
								file = v
								break
							end
						end
						if not file then
							return {}
						end
						local diagnostics = {}
						for _, message in ipairs(file.messages or {}) do
							table.insert(diagnostics, {
								lnum = type(message.line) == "number" and (message.line - 1) or 0,
								col = 0,
								message = message.message,
								source = "phpstan",
								code = message.identifier,
							})
						end
						return diagnostics
					end,
				}
			end

			return opts
		end,
	},

	{
		"neovim/nvim-lspconfig",
		opts = {
			servers = {
				intelephense = {
					root_dir = function(fname)
						-- Suche vom aktuellen File aufwärts nach einem dieser Marker.
						-- Das stellt sicher, dass immer das Haupt-ILIAS-Verzeichnis als
						-- Projekt-Root erkannt wird, egal wie tief du in einem Plugin arbeitest.
						local root_markers = { "ilias.php", "ilias.ini.php" }
						local root_dir = require("lspconfig.util").root_pattern(unpack(root_markers))(fname)

						-- Fallback: Wenn kein Marker gefunden wird, nutze das Standardverhalten.
						return root_dir or require("lspconfig.util").find_git_ancestor(fname)
					end,
					settings = {
						intelephense = {
							telemetry = { enable = false },

							files = {
								-- Wir überschreiben die Standard-Ausschlussliste,
								-- um den 'vendor'-Ordner explizit NICHT auszuschließen.
								exclude = {
									"**/.git/**",
									"**/.svn/**",
									"**/.hg/**",
									"**/CVS/**",
									"**/.DS_Store/**",
									"**/node_modules/**",
									"**/bower_components/**",
									-- Der wichtige Punkt: "**/vendor/**" fehlt hier.
								},
								-- Das Limit für die Dateigröße erhöhen, falls nötig.
								maxSize = 2000000,
							},

							environment = {
								phpVersion = "8.2",
								includePaths = { "Services", "Modules", "libs" },
							},

							-- Der Rest der Einstellungen bleibt wie gehabt
							diagnostics = {
								enable = true,
								run = "onSave",
								deprecated = true,
								undefinedSymbols = true,
								undefinedVariables = true,
								undefinedProperties = true,
								undefinedMethods = true,
								unusedSymbols = true,
								nonexistentFile = true,
								caseSensitive = true,
								strictTypes = true,
								strictKeyCheck = true,
								duplicateSymbols = true,
							},
							completion = {
								enable = true,
								triggerParameterHints = true,
								insertUseDeclaration = true,
								fullyQualifyGlobalConstants = true,
								fullyQualifyGlobalFunctions = true,
								phpdoc = { enable = true, text = true },
								quickPick = { enable = true },
							},
							format = { enable = true, braces = "psr12" },
							rename = { enable = true },
						},
					},
				},
			},
		},
	},
}
