return
{
  'stevearc/conform.nvim',
  opts = {
      formatters_by_ft = {
          lua = { "stylua" },
          markdown = { "prettier" },
          nix = { "alejandra" },
      },
  },
}
