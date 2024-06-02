local Path = require("plenary.path")
local scan = require("plenary.scandir")
local Job = require("plenary.job")
local M = {}

M.logs = {}

function M.add_log(message)
  table.insert(M.logs, message)
  print("Log added:", message) -- Debug line
end

function M.get_logs()
  return M.logs
end

function M.clear_logs()
  M.logs = {}
end

function M.read_file(file_path)
  local path = Path:new(file_path)
  if not path:exists() then
    return nil, "File does not exist"
  end
  return path:read()
end

function M.parse_config_file(root_dir)
  local path = Path:new(root_dir .. "/dw.json")
  if not path:exists() then
    return nil, "Cannot open file: " .. tostring(path)
  end

  local content = path:read()
  local config, err = vim.json.decode(content)
  if not config then
    return nil, "Error parsing JSON: " .. err
  end

  return config
end

function M.list_directories(path)
  local dirs = scan.scan_dir(path, { only_dirs = true, depth = 1 })
  return dirs
end

function M.check_if_cartridge(project_file)
  local content, err = M.read_file(project_file)
  if not content then
    return false, err
  end

  return content:find("com.demandware.studio.core.beehiveNature") ~= nil
end

local function url_encode(str)
  if str then
    str = string.gsub(str, "\n", "\r\n")
    str = string.gsub(str, "([^%w ])", function(c)
      return string.format("%%%02X", string.byte(c))
    end)
    str = string.gsub(str, " ", "+")
  end
  return str
end

function M.upload_cartridge(cartridge_path, config)
  M.clear_logs()

  local files = scan.scan_dir(cartridge_path, { hidden = true, depth = 10 })

  -- local username = url_encode(config.username)
  -- local password = url_encode(config.password)

  local username = config.username
  local password = config.password

  -- Validate connection (dummy request to check connection)
  local validate_url = string.format(
    "https://%s/on/demandware.servlet/webdav/Sites/Cartridges/%s/",
    config.hostname,
    config["code-version"]
  )

  print(username, password)
  M.add_log("Using config file: " .. Path:new(cartridge_path):absolute())
  M.add_log("Hostname: " .. config.hostname)
  M.add_log("Code version: " .. config["code-version"])

  Job:new({
    command = "curl",
    args = {
      "-I",
      validate_url,
      "-u",
      username .. ":" .. password,
    },
    on_exit = function(j, return_val)
      if return_val == 0 then
        local result = j:result()
        local status_code = tonumber(string.match(result[1], "%s(%d+)%s"))

        if status_code == 200 then
          M.add_log("Connection validated successfully")
        else
          M.add_log("Failed to validate connection: HTTP status " .. status_code)
          M.add_log("Response: " .. table.concat(result, "\n"))
          return
        end
      else
        M.add_log("Failed to validate connection: " .. table.concat(j:stderr_result(), "\n"))
        return
      end

      M.add_log("Start uploading cartridges")

      for _, file in ipairs(files) do
        local relative_path = Path:new(file):make_relative(cartridge_path)
        local url = string.format(
          "https://%s/on/demandware.servlet/webdav/Sites/Cartridges/%s/%s",
          config.hostname,
          config["code-version"],
          relative_path
        )

        Job:new({
          command = "curl",
          args = {
            "-T",
            file,
            url,
            "-u",
            username .. ":" .. password,
          },
          on_exit = function(job, exit_code)
            if exit_code == 0 then
              M.add_log("Uploaded: " .. relative_path)
            else
              M.add_log("Failed to upload: " .. relative_path .. "\n" .. table.concat(job:stderr_result(), "\n"))
            end
          end,
        }):start()
      end

      M.add_log("Cleanup code version")
    end,
  }):start()
end

return M
