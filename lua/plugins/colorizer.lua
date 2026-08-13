-- Paint hex/rgb/hsl color codes their actual color inline (maintained fork
-- of the archived NvChad/nvim-colorizer.lua).
return {
  "catgoose/nvim-colorizer.lua",
  event = "LazyFile",
  opts = {
    user_default_options = {
      -- only color codes (#f38ba8, rgb(...)), not names like "red"
      names = false,
    },
  },
}
