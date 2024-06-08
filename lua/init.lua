local telescope = require("nvim-dw-sync.utils.telescope")

local M = {}

function M.setup(config)
  telescope.setup()
  M.config = config
end

return M
