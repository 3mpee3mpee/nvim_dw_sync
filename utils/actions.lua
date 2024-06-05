local file_utils = require("dw-sync.utils.file")
local Job = require("plenary.job")
local Path = require("plenary.path")

local M = {}

function M.execute_upload(config, cwd)
  print("Upload Cartridges action triggered")

  local valid_cartridges = file_utils.update_cartridge_list(cwd)

  -- Validate connection (dummy request to check connection)
  local validate_url = string.format(
    "https://%s/on/demandware.servlet/webdav/Sites/Cartridges/%s/",
    config.hostname,
    config["code-version"]
  )

  if #valid_cartridges == 0 then
    file_utils.add_log("No cartridges to upload")
    return
  end

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

function M.execute_clean_project(config)
  print("Clean Project triggered")

  file_utils.get_cartridge_list_and_clean(config)
end

function M.execute_enable_upload(config)
  print("Enable Upload triggered")
  file_utils.start_watcher(config)
end

function M.execute_disable_upload()
  print("Disable Upload triggered")
  file_utils.stop_watcher()
end

function M.execute_clean_project_upload_all(config, cwd)
  M.execute_clean_project(config)
  M.execute_upload(config, cwd)
  M.execute_enable_upload(config)
end

return M
