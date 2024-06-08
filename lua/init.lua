local telescope = require("nvim-dw-sync.utils.telescope")
local commands = require("nvim-dw-sync.utils.commands")

local M = {}

function M.setup()
  telescope.setup()
  commands.setup()
end

return M
