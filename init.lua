local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local sorters = require("telescope.config").values
local file_utils = require("dw-sync.utils.file")
local actions_utils = require("dw-sync.utils.actions")

local M = {}

local function execute_action(prompt_bufnr)
  local selection = action_state.get_selected_entry()
  file_utils.clear_logs()
  local cwd = vim.fn.getcwd()
  local config, err = file_utils.parse_config_file(cwd)

  if not config then
    file_utils.add_log("Error: " .. err)
    return
  end

  if selection and selection.value == "Clean Project and Upload all" then
    actions_utils.execute_clean_project_upload_all(config, cwd)
  end

  if selection and selection.value == "Upload Cartridges" then
    actions_utils.execute_upload(config, cwd)
  end

  if selection and selection.value == "Clean Project" then
    actions_utils.execute_clean_project(config)
  end

  if selection and selection.value == "Enable Upload" then
    actions_utils.execute_enable_upload(config)
  end

  if selection and selection.value == "Disable Upload" then
    actions_utils.execute_disable_upload()
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
        n = {
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

      local title_description = ""
      local selection = action_state.get_selected_entry()

      if selection and selection.value == "Clean Project and Upload all" then
        title_description = "Clean Project and Upload all"
      end
      if selection and selection.value == "Upload Cartridges" then
        title_description = "Upload Cartridges"
      end
      if selection and selection.value == "Clean Project" then
        title_description = "Clean Project"
      end
      if selection and selection.value == "Enable Upload" then
        title_description = "Enable Upload"
      end
      if selection and selection.value == "Disable Upload" then
        title_description = "Disable Upload"
      end

      -- Ensure each log entry is split into individual lines
      local formatted_results = {}

      if title_description ~= "" then
        table.insert(formatted_results, title_description)
        table.insert(formatted_results, "---------------------------------------------------------------")
      end

      for _, log_entry in ipairs(results) do
        for line in log_entry:gmatch("[^\r\n]+") do
          table.insert(formatted_results, line)
        end
      end

      vim.schedule(function()
        -- Clear the buffer before setting new lines
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {})
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
