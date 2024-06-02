local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local sorters = require("telescope.config").values
local file_utils = require("dw-sync.utils.file")
local Job = require("plenary.job")
local Path = require("plenary.path")

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

  if selection and selection.value == "Upload Cartridges" then
    print("Upload Cartridges action triggered")

    local cartridges = file_utils.list_directories(cwd)
    local valid_cartridges = {}
    for _, cartridge in ipairs(cartridges) do
      if file_utils.check_if_cartridge(cartridge .. "/.project") then
        table.insert(valid_cartridges, cartridge)
      end
    end

    -- Validate connection (dummy request to check connection)
    local validate_url = string.format(
      "https://%s/on/demandware.servlet/webdav/Sites/Cartridges/%s/",
      config.hostname,
      config["code-version"]
    )

    Job:new({
      command = "curl",
      args = {
        "-I",
        validate_url,
        "-u",
        config.username .. ":" .. config.password,
      },
      on_exit = function(j, return_val)
        if return_val == 0 then
          local result = j:result()
          local status_code = tonumber(string.match(result[1], "%s(%d+)%s"))

          if status_code == 200 then
            file_utils.add_log("Connection validated successfully")
          else
            file_utils.add_log("Failed to validate connection: HTTP status " .. status_code)
            file_utils.add_log("Response: " .. table.concat(result, "\n"))
            return
          end
        else
          file_utils.add_log("Failed to validate connection: " .. table.concat(j:stderr_result(), "\n"))
          return
        end

        file_utils.add_log("Start uploading cartridges")

        file_utils.add_log("Cartridges to upload: " .. table.concat(valid_cartridges, "\n"))
        file_utils.add_log("Using config file: " .. Path:new(cwd .. "/dw.json"):absolute())
        file_utils.add_log("Hostname: " .. config.hostname)
        file_utils.add_log("Code version: " .. config["code-version"])

        for _, valid_cartridge in ipairs(valid_cartridges) do
          file_utils.add_log("Uploading: " .. valid_cartridge)
          file_utils.upload_cartridge(valid_cartridge, config)
        end
      end,
    }):start()
  end

  if selection and selection.value == "Clean Project" then
    print("Clean Project triggered")

    file_utils.get_cartridge_list(config)
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
        results = { "Upload Cartridges", "Clean Project" },
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
