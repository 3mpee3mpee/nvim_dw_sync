local nvim_dw_sync = require("nvim_dw_sync")

return require("telescope").register_extension({
  exports = {
    open_telescope = nvim_dw_sync.open_telescope,
  },
})
