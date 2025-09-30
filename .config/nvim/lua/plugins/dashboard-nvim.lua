return {
  'nvimdev/dashboard-nvim',
  event = 'VimEnter',
  lazy = false,
  config = function ()
    require('dashboard').setup {
    -- config
    theme = 'doom',
    config = {
        header = {
"                          ",
"                          ",
"⠀⠀   ⠀⠀⠀⠀⠀⠆⠀⠀⠀            ",
"⠀⠀⠀     ⠀⠀ ⠀⢀⡀⠀⠀⠀⠀⡀       ",
"⠀⠀⠀   ⠀⠀⠀ ⠀⠀⡎⠛⡄           ",
"⠀   ⠐⠂⠀⠀ ⠀⠀⡘⢠⡄⠛⡀⠀⠀⠀⠀      ",
"     ⠀⠀⠀ ⠀⣼⢠⡃⠀⢡⢸⡀⠀⠀⠀⠀     ",
"   ⠀⣀⡀⠀⠀⠀ ⢹⢸⡇⠀⠀⡄⡇⠀⠀⠀⠉⠀    ",
"⠀⠀⠀⠀    ⠀⠀⠸⣿⢆⣴⣤⣿ ⠀⠀       ",
"⠀⠀     ⠀⠀⠀⢹⣏⣿⣽⡟⠀⠀⠐⠤⠀⠀     ",
"⠀   ⠀⣀⠠⠤⠤⠀⢐⡻⡗⣛⡒⠂⠠⢤⢀⡀⠀⠀    ",
"   ⠀⢾⣿⡚⠉⠉⠀⠀⠀⠷⠄⠀⠈⠉⠝⠛⡯⣦     ",
"   ⠀⢾⡉⠛⠒⠶⠤⠤⠤⠤⢤⣤⣤⣵⣶⣾⡿⣹     ",
"⠀  ⠺⡇⠀⠀⠀⠀⠀⠀⠀⣼⡿⣫⡾⣻⢟⡬⣾      ",
"  ⠀⣿⣅⠀⠀⠀⠀⠀⠀⠀⢨⢞⣥⢞⣡⢟⣞⢼⠀     ",
" ⠀⢿⣥⠀⠀⠀⠀⠀⠀⠀⡵⢓⡵⢛⣵⣟⣵⣺⡦⣤⣤⣤⣤⡀⠀",
"⠀⠈⠒⢄⣠⠀⣀⣀⠀⢀⣾⣿⢾⣽⢿⣿⣿⣿⣾⡿⡿⠿⠟⠛⠒ ",
"⠀⠀⠀⠀⠀⠈⠉⠘⠓⠒⠛⠛⠛⠛⠛⠉⠉         "
        },
        center = {
          {
            desc = '"We die in the dark, so that you may live in the light."',
            desc_hl = 'Conditional'
          },
        },
      }
    }
  end,
  dependencies = { {'nvim-tree/nvim-web-devicons'}}
}
