local Path = require("plenary.path")
local scan = require("plenary.scandir")
local Job = require("plenary.job")
local M = {}

M.logs = {}
M.cartridges = {}
M.watcher = nil

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

function M.get_cartridge_list_and_clean(config)
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

local function str_split(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
    table.insert(t, str)
  end
  return t
end

function M.upload_file(file_path, config)
  local cwd = vim.fn.getcwd()
  local relative_path = Path:new(file_path):make_relative(cwd)
  local c_name = nil
  local c_rel_path = nil
  print(relative_path .. "Relative path") -- Debug line

  for i, c in ipairs(M.cartridges) do
    c_rel_path = Path:new(c):make_relative(cwd) -- Debug line
    print(c_rel_path .. "Cartridge relative path") -- Debug line
    if string.find(relative_path, c_rel_path) then
      c_name = c
    end
  end

  if c_name then
    local cartridge_name = string.match(c_name, "([^/]+)$") -- Extract the cartridge name using Lua pattern matching
    local rp = Path:new(file_path):make_relative(c_name)
    local c_rel_index = string.find(rp, cartridge_name, 1, true)
    local upload_path = string.sub(rp, c_rel_index)

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
        file_path,
        url,
        "-u",
        config.username .. ":" .. config.password,
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

function M.delete_file(file_path, config)
  local cwd = vim.fn.getcwd()
  local relative_path = Path:new(file_path):make_relative(cwd)
  local c_name = nil
  local c_rel_path = nil
  print(relative_path .. ": dassdRelative path") -- Debug line

  for i, c in ipairs(M.cartridges) do
    c_rel_path = Path:new(c):make_relative(cwd) -- Debug line
    print(c_rel_path .. ": aartridge relative path") -- Debug line
    if string.find(relative_path, c_rel_path) then
      c_name = c
    end
  end

  print(11111)
  if c_name then
    print(222222)
    local cartridge_name = string.match(c_name, "([^/]+)$") -- Extract the cartridge name using Lua pattern matching
    local rp = Path:new(file_path):make_relative(c_name)
    local c_rel_index = string.find(rp, cartridge_name, 1, true)
    local delete_path = string.sub(rp, c_rel_index)

    local url = string.format(
      "https://%s/on/demandware.servlet/webdav/Sites/Cartridges/%s/%s",
      config.hostname,
      config["code-version"],
      delete_path
    )

    Job:new({
      command = "curl",
      args = {
        "-X",
        "DELETE",
        url,
        "-u",
        config.username .. ":" .. config.password,
      },
      on_exit = function(job, exit_code)
        if exit_code == 0 then
          M.add_log("Deleted: " .. delete_path)
        else
          M.add_log("Failed to delete: " .. delete_path .. "\n" .. table.concat(job:stderr_result(), "\n"))
        end
      end,
    }):start()
  end
end

function M.start_watcher(config)
  if M.watcher then
    M.add_log("Watcher is already running")
    return
  end

  local cwd = vim.fn.getcwd()

  M.watcher = vim.loop.new_fs_event()
  M.watcher:start(
    cwd,
    { recursive = true },
    vim.schedule_wrap(function(err, fname, status)
      if err then
        M.add_log("Error in watcher: " .. err)
        return
      end

      if fname then
        local file_path = Path:new(fname)
        M.add_log("File changed: " .. fname)
        print("File changed: " .. fname) -- Debug line

        if file_path:exists() then
          local function handle_dir(f_path)
            M.add_log("Handling directory: " .. f_path)
            print("Handling directory: " .. f_path) -- Debug line

            local files = scan.scan_dir(f_path, { hidden = true, depth = 10 })
            for _, file in ipairs(files) do
              local file_path_obj = Path:new(file)
              if file_path_obj:is_dir() then
                handle_dir(file)
              else
                M.upload_file(file, config)
              end
            end
          end

          if file_path:is_dir() then
            M.add_log("Path is a directory: " .. fname)
            print("Path is a directory: " .. fname) -- Debug line
            handle_dir(fname)
          else
            M.add_log("Path is a file: " .. fname)
            print("Path is a file: " .. fname) -- Debug line
            M.upload_file(fname, config)
          end
        else
          M.add_log("File does not exist: " .. fname)
          print("File does not exist: " .. fname) -- Debug line
          M.delete_file(fname, config)
        end
      end
    end)
  )
end

function M.update_cartridge_list(cwd)
  local cartridges = M.list_directories(cwd)
  local valid_cartridges = {}
  for _, cartridge in ipairs(cartridges) do
    if M.check_if_cartridge(cartridge .. "/.project") then
      print(cartridge .. ": HELLO WORLD")
      table.insert(valid_cartridges, cartridge)
    end
  end

  if #valid_cartridges == 0 then
    M.add_log("No cartridges found")
    return
  end
  M.cartridges = valid_cartridges
  return valid_cartridges
end

function M.stop_watcher()
  if M.watcher then
    M.watcher:stop()
    M.watcher = nil
    print("Watcher stopped") -- Debug line
    M.add_log("Watcher stopped")
  end
end

return M
