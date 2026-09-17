-- rust-analyzer only returns *types* from workspace symbol search by default
-- (functions, methods, consts and statics are dropped before the picker sees
-- them) and caps results at 128. gs should find a function like any other
-- server does, so search every kind, with headroom for bigger workspaces.
-- Merges into the LazyVim rust extra's rustaceanvim settings.
return {
  "mrcjkb/rustaceanvim",
  opts = {
    server = {
      default_settings = {
        ["rust-analyzer"] = {
          workspace = { symbol = { search = { kind = "all_symbols", limit = 512 } } },
        },
      },
    },
  },
}
