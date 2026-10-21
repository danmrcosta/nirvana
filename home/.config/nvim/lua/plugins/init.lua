return {
  { "stevearc/conform.nvim", opts = require "configs.conform" },
  { "neovim/nvim-lspconfig", config = function() require "configs.lspconfig" end },

  -- Plugin de indentação corrigido
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = "VeryLazy",
    opts = {
      indent = {
        char = "│",
        highlight = "Comment",
      },
      whitespace = {
        remove_blankline_trail = false,
      },
      scope = { enabled = false },
    },
  },

  -- Configuração do tema Vercel
  {
    "tiesen243/vercel.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("vercel").setup({
        theme = "dark",
        transparent = true,
      })

      vim.defer_fn(function()
        pcall(vim.cmd.colorscheme, "vercel")
        
        local groups = { 
          "Normal", "NormalNC", "NormalFloat", "FloatBorder", "SignColumn", 
          "LineNr", "CursorLineNr", "StatusLine", "StatusLineNC", "VertSplit", 
          "WinBar", "WinBarNC", "Pmenu", "PmenuSel", "TelescopeNormal", "TelescopeBorder" 
        }
        for _, group in ipairs(groups) do
          pcall(function()
            local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
            hl.bg = "none"
            hl.ctermbg = "none"
            vim.api.nvim_set_hl(0, group, hl)
          end)
        end
      end, 200)
    end,
  },
}
