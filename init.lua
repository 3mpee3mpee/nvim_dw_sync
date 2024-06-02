local telescope = require("telescope")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local sorters = require("telescope.config").values
local file_utils = require("dw-sync.utils.file")

local M = {}

local function execute_action(prompt_bufnr)
  local selection = action_state.get_selected_entry()

  if selection and selection.value == "Upload Cartridges" then
    print("Upload Cartridges action triggered")
    local config, err = file_utils.parse_config_file(vim.fn.getcwd())
    if not config then
      file_utils.add_log("Error: " .. err)
      return
    end

    local cartridges = file_utils.list_directories(vim.fn.getcwd() .. "/cartridges")
    local valid_cartridges = {}
    for _, cartridge in ipairs(cartridges) do
      if file_utils.check_if_cartridge(cartridge .. "/.project") then
        table.insert(valid_cartridges, cartridge)
      end
    end

    file_utils.add_log("Cartridges to upload: " .. table.concat(valid_cartridges, ", "))

    file_utils.upload_cartridge(vim.fn.getcwd() .. "/cartridges", config)
  end
  actions.close(prompt_bufnr)
end

function M.setup()
  -- Register Telescope picker
  require("telescope").setup({
    defaults = {
      mappings = {
        i = {
          ["<CR>"] = execute_action,
        },
      },
    },
  })
end

local function log_previewer()
  return previewers.new_buffer_previewer({
    define_preview = function(self, entry, status)
      local results = file_utils.get_logs()
      if not results or type(results) ~= "table" then
        results = { "No logs available." }
      end

      -- Ensure each log entry is split into individual lines
      local formatted_results = {}
      for _, log_entry in ipairs(results) do
        for line in log_entry:gmatch("[^\r\n]+") do
          table.insert(formatted_results, line)
        end
      end

      vim.schedule(function()
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, formatted_results)
      end)
    end,
  })
end

function M.open_telescope()
  pickers
    .new({}, {
      prompt_title = "DW Sync",
      finder = finders.new_table({
        results = { "Upload Cartridges" },
      }),
      sorter = sorters.generic_sorter({}),
      previewer = log_previewer(),
      attach_mappings = function(prompt_bufnr, map)
        map("i", "<CR>", execute_action)
        return true
      end,
    })
    :find()
end

return M
