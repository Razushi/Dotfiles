-- [[ Configure and install plugins ]]
--
--  To check the current status of your plugins, run
--    :Lazy
--
--  You can press `?` in this menu for help. Use `:q` to close the window
--
--  To update plugins you can run
--    :Lazy update
--
-- NOTE: Here is where you install your plugins.
require('lazy').setup({
  -- Plugins can be added with a link (or for a github repo: 'owner/repo' link).
  --
  -- 'tpope/vim-sleuth', -- Detect tabstop and shiftwidth automatically

  -- Plugins can also be added by using a table,
  -- with the first argument being the link and the following
  -- keys can be used to configure plugin behavior/loading/etc.
  --
  -- Use `opts = {}` to force a plugin to be loaded.

  -- Not using rn, might use later
  -- require 'plugins.debug',
  --
  -- Requires some setup
  -- require 'plugins.lint',
  --
  -- Classic style file tree
  require 'plugins.neo-tree',
  require 'plugins.gitsigns', -- adds gitsigns recommend keymaps
  require 'plugins.conform-autoformat',
  require 'plugins.lazydev-lsp',
  require 'plugins.mini',
  require 'plugins.blink-cmp',
  -- require 'plugins.nvim-cmp',
  require 'plugins.telescope',
  require 'plugins.todo-comments',
  require 'plugins.treesitter',
  require 'plugins.which-key',
  require 'plugins.dashboard-nvim',
  -- require 'plugins.obsidian-nvim',
  require 'plugins.onedark',
  require 'plugins.telescope-undo',
  require 'plugins.no-neck-pain',

  --  Uncomment to load the custom/plugins directory and all files within, easy way to load a whole folder.
  --    For additional information, see `:help lazy.nvim-lazy.nvim-structuring-your-plugins`
  -- { import = 'custom.plugins' },

}, {
  ui = {
    -- If you are using a Nerd Font: set icons to an empty table which will use the
    -- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})
