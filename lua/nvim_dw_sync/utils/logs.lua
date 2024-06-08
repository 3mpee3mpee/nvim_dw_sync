local M = {}
M.logs = {}

function M.add_log(message)
  table.insert(M.logs, message)
end

function M.get_logs()
  return M.logs
end

function M.clear_logs()
  M.logs = {}
end

return M
