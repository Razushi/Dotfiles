return
-- lazy.nvim
{
    "folke/snacks.nvim",
    ---@type snacks.Config
    opts = {
        dashboard = {
            -- your dashboard configuration comes here
            -- or leave it empty to use the default settings
            sections = {
                {
                    text = { [[
⠀   ⠀⠀⠀⠀⠀⠆⠀⠀⠀            
⠀⠀     ⠀⠀ ⠀⢀⡀⠀⠀⠀⠀⡀       
⠀⠀   ⠀⠀⠀ ⠀⠀⡎⠛⡄           
   ⠐⠂⠀⠀ ⠀⠀⡘⢠⡄⠛⡀⠀⠀⠀⠀      
    ⠀⠀⠀ ⠀⣼⢠⡃⠀⢡⢸⡀⠀⠀⠀⠀     
  ⠀⣀⡀⠀⠀⠀ ⢹⢸⡇⠀⠀⡄⡇⠀⠀⠀⠉⠀    
⠀⠀⠀    ⠀⠀⠸⣿⢆⣴⣤⣿ ⠀⠀       
⠀     ⠀⠀⠀⢹⣏⣿⣽⡟⠀⠀⠐⠤⠀⠀     
   ⠀⣀⠠⠤⠤⠀⢐⡻⡗⣛⡒⠂⠠⢤⢀⡀⠀⠀    
  ⠀⢾⣿⡚⠉⠉⠀⠀⠀⠷⠄⠀⠈⠉⠝⠛⡯⣦     
  ⠀⢾⡉⠛⠒⠶⠤⠤⠤⠤⢤⣤⣤⣵⣶⣾⡿⣹     
  ⠺⡇⠀⠀⠀⠀⠀⠀⠀⣼⡿⣫⡾⣻⢟⡬⣾      
 ⠀⣿⣅⠀⠀⠀⠀⠀⠀⠀⢨⢞⣥⢞⣡⢟⣞⢼⠀     
⠀⢿⣥⠀⠀⠀⠀⠀⠀⠀⡵⢓⡵⢛⣵⣟⣵⣺⡦⣤⣤⣤⣤⡀⠀
⠈⠒⢄⣠⠀⣀⣀⠀⢀⣾⣿⢾⣽⢿⣿⣿⣿⣾⡿⡿⠿⠟⠛⠒ 
⠀⠀⠀⠀⠈⠉⠘⠓⠒⠛⠛⠛⠛⠛⠉⠉         
                        ]], hl = "Normal" },
                        align = "center",
                        -- height = 3,
                        -- padding = 1
                    },
                    {
                        text = { '"We die in the dark, so that you may live in the light."', hl = "SnacksDashboardKey" }
                    },
                },
            }
        }
    }
