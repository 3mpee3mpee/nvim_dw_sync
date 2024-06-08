local telescope = require("nvim-dw-sync.utils.telescope")

local M = {}

local CMDS = {
  {
    name = "DWOpenTelescope",
    opts = {
      desc = "nvim-tree: highlight test",
    },
    command = telescope.open_telescope(),
  },
}

function M.setup()
  for _, cmd in ipairs(CMDS) do
    local opts = vim.tbl_extend("force", cmd.opts, { force = true })
    vim.api.nvim_create_user_command(cmd.name, cmd.command, opts)
  end
end

return M
