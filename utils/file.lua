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
  local all_dirs = scan.scan_dir(path, { only_dirs = true, depth = 5 })
  local dirs = {}

  for _, dir in ipairs(all_dirs) do
    if not dir:match("node_modules") then
      table.insert(dirs, dir)
    end
  end
  return dirs
end

function M.check_if_cartridge(project_file)
  local content, err = M.read_file(project_file)
  if not content then
    return false, err
  end

  return content:find("com.demandware.studio.core.beehiveNature") ~= nil
end

function M.clean_project(cartridge_name, cwd)
  print("Executing clean_project function")
  M.add_log("Cleaning project: " .. cartridge_name)

  local config, err = M.parse_config_file(cwd)
  if not config then
    M.add_log("Error: " .. err)
    return
  end

  local clean_url = string.format(
    "https://%s/on/demandware.servlet/webdav/Sites/Cartridges/%s/%s/",
    config.hostname,
    config["code-version"],
    cartridge_name
  )

  Job:new({
    command = "curl",
    args = {
      "-X",
      "DELETE",
      clean_url,
      "-u",
      config.username .. ":" .. config.password,
    },
    on_exit = function(j, return_val)
      if return_val == 0 then
        M.add_log("Project cleaned successfully")
      else
        M.add_log("Failed to clean project: " .. table.concat(j:stderr_result(), "\n"))
      end
    end,
  }):start()
end

function M.get_cartridge_list(config)
  local username = config.username
  local password = config.password
  local cwd = vim.fn.getcwd()

  local url = string.format(
    "https://%s/on/demandware.servlet/webdav/Sites/Cartridges/%s/",
    config.hostname,
    config["code-version"]
  )
  local result = {}

  Job:new({
    command = "curl",
    args = {
      "-X",
      "GET",
      url,
      "-u",
      username .. ":" .. password,
    },
    on_stdout = function(_, data)
      table.insert(result, data)
    end,
    on_exit = function(j, return_val)
      if return_val == 0 then
        local cartridges = {}

        for _, line in ipairs(result) do
          print(line)
          local version, cartridge = string.match(
            line,
            '<a href="/on/demandware.servlet/webdav/Sites/Cartridges/([^/]*)/([^/]*)"><tt>([^<]+)</tt></a>'
          )
          if cartridge then
            table.insert(cartridges, cartridge)
          end
        end

        if cartridges and cartridges[1] then
          print("Cartridges found:", table.concat(cartridges, "\n"))
          for _, cartridge in ipairs(cartridges) do
            M.clean_project(cartridge, cwd)
          end
          M.add_log("Cartridges found: " .. table.concat(cartridges, "\n"))
        else
          print("Failed to get cartridges list")
          M.add_log("Failed to get cartridges list")
        end
      else
        print("Failed to get cartridges list: " .. table.concat(j:stderr_result(), "\n"))
        M.add_log("Failed to get cartridges list: " .. table.concat(j:stderr_result(), "\n"))
      end
    end,
  }):start()
end

function M.upload_cartridge(cartridge_path, config)
  local files = scan.scan_dir(cartridge_path, { hidden = true, depth = 10 })

  local username = config.username
  local password = config.password

  for _, file in ipairs(files) do
    local relative_path = Path:new(file):make_relative(cartridge_path)
    local cartridge_name = string.match(cartridge_path, "([^/]+)$") -- Extract the cartridge name using Lua pattern matching
    local upload_path = string.format("%s/%s", cartridge_name, relative_path)

    local url = string.format(
      "https://%s/on/demandware.servlet/webdav/Sites/Cartridges/%s/%s",
      config.hostname,
      config["code-version"],
      upload_path
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
          M.add_log("Uploaded: " .. upload_path)
        else
          M.add_log("Failed to upload: " .. upload_path .. "\n" .. table.concat(job:stderr_result(), "\n"))
        end
      end,
    }):start()
  end
end

return M
