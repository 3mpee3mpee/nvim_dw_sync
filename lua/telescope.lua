local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local sorters = require("telescope.config").values
local file_utils = require("dw-sync.utils.file")
local actions_utils = require("dw-sync.utils.actions")
local logs = require("dw-sync.utils.logs")

local M = {}

-- Function to execute the selected action
local function execute_action(prompt_bufnr)
  local selection = action_state.get_selected_entry()
  logs.clear_logs()
  local cwd = vim.fn.getcwd()
  local config, err = file_utils.parse_config_file(cwd)

  if not config then
    logs.add_log("Error: " .. err)
    return
  end

  if selection then
    local action_map = {
      ["Clean Project and Upload all"] = actions_utils.execute_clean_project_upload_all,
      ["Upload Cartridges"] = actions_utils.execute_upload,
      ["Clean Project"] = actions_utils.execute_clean_project,
      ["Enable Upload"] = actions_utils.execute_enable_upload,
      ["Disable Upload"] = actions_utils.execute_disable_upload,
    }

    local action = action_map[selection.value]
    if action then
      action(config, cwd)
    end
  end

  actions.close(prompt_bufnr)
end

-- Setup function for telescope configuration
function M.setup()
  require("telescope").setup({
    defaults = {
      mappings = {
        i = {
          ["<CR>"] = execute_action,
        },
        n = {
          ["<CR>"] = execute_action,
        },
      },
    },
  })
end

-- Function to preview logs
local function log_previewer()
  return previewers.new_buffer_previewer({
    define_preview = function(self, entry, status)
      local results = logs.get_logs() or { "No logs available." }

      local title_description = entry.value

      local formatted_results = { title_description, "---------------------------------------------------------------" }
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

-- Function to open telescope with custom configuration
function M.open_telescope()
  pickers
    .new({}, {
      prompt_title = "DW Sync",
      finder = finders.new_table({
        results = {
          "Clean Project and Upload all",
          "Upload Cartridges",
          "Clean Project",
          "Enable Upload",
          "Disable Upload",
        },
      }),
      sorter = sorters.generic_sorter({}),
      previewer = log_previewer(),
      attach_mappings = function(prompt_bufnr, map)
        map("i", "<CR>", execute_action)
        map("n", "<CR>", execute_action)
        return true
      end,
    })
    :find()
end

return M
