-- One-click update: notices new commits on origin/main and applies them from the hub.
--
-- Check: `git fetch` (quiet, in the background) then count the commits HEAD is behind origin/main.
-- Runs 30 s after start, every 6 hours, and when the hub opens (at most once per 30 min).
-- Apply: `git pull --ff-only`, then a reload. Nothing is ever forced or overwritten:
--   - only on the main branch (a checkout on another branch is someone developing: left alone);
--   - not while tracked files have local edits (the pull would refuse anyway; we say why first);
--   - fast-forward only, so a diverged history stops with a message instead of a merge.
-- config.local.lua, clipdata/ and the other git-ignored personal files are never touched by a pull.
-- Set `updateCheck = false` in config.local.lua to switch the whole thing off.
local Keep = require("keep")
local Config = require("config")

local M = {}
local DIR = os.getenv("HOME") .. "/.hammerspoon"
local GIT = "/usr/bin/git"
local CHECK_EVERY = 6 * 3600
local CHECK_ON_OPEN_AFTER = 30 * 60
local MAX_SUBJECTS = 5

local state = { behind = 0, subjects = {}, checkedAt = 0, checking = false, updating = false, error = nil }
local onChange

local function changed() if onChange then onChange() end end

-- git with the checkout as its work tree; cb(ok, stdout, stderr)
local function git(args, cb)
  local full = { "-C", DIR }
  for _, a in ipairs(args) do table.insert(full, a) end
  local t = Keep.task(GIT, function(code, out, err) cb(code == 0, out or "", err or "") end, full)
  if not t then cb(false, "", "git could not start") end
end

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

function M.enabled()
  return Config.updateCheck ~= false and hs.fs.attributes(DIR .. "/.git", "mode") ~= nil
end

-- What the hub shows. nil when there is nothing to say.
function M.data()
  if not M.enabled() then return nil end
  if state.behind > 0 or state.updating or state.error then
    return { behind = state.behind, subjects = state.subjects, updating = state.updating or nil, error = state.error }
  end
  return nil
end

function M.check(force)
  if not M.enabled() or state.checking or state.updating then return end
  if not force and os.time() - state.checkedAt < CHECK_ON_OPEN_AFTER then return end
  state.checking = true
  git({ "rev-parse", "--abbrev-ref", "HEAD" }, function(ok, branch)
    if not ok or trim(branch) ~= "main" then state.checking = false; return end
    git({ "fetch", "--quiet", "origin", "main" }, function(fetched)
      state.checkedAt = os.time()
      if not fetched then state.checking = false; return end -- offline: stay quiet, try again later
      git({ "rev-list", "--count", "HEAD..origin/main" }, function(counted, n)
        local behind = counted and tonumber(trim(n)) or 0
        if behind == 0 then
          state.checking = false
          if state.behind ~= 0 then state.behind, state.subjects = 0, {}; changed() end
          return
        end
        git({ "log", "--format=%s", "-n", tostring(MAX_SUBJECTS), "HEAD..origin/main" }, function(_, log)
          local subjects = {}
          for line in log:gmatch("[^\n]+") do table.insert(subjects, line) end
          state.checking = false
          state.behind, state.subjects, state.error = behind, subjects, nil
          changed()
        end)
      end)
    end)
  end)
end

local function fail(msg)
  state.updating = false
  state.error = msg
  changed()
  -- the message clears itself; the update stays on offer
  Keep.after(8, function() if state.error == msg then state.error = nil; changed() end end)
end

function M.apply()
  if not M.enabled() or state.updating then return end
  state.updating, state.error = true, nil
  changed()
  git({ "rev-parse", "--abbrev-ref", "HEAD" }, function(ok, branch)
    if not ok or trim(branch) ~= "main" then return fail("Güncelleme Yalnız main Dalında Yapılır") end
    git({ "status", "--porcelain", "--untracked-files=no" }, function(clean, out)
      if not clean then return fail("Depo Durumu Okunamadı") end
      if trim(out) ~= "" then return fail("Yerel Değişiklik Var · Önce Commit'le ya da Geri Al") end
      git({ "rev-parse", "HEAD" }, function(_, before)
        before = trim(before)
        git({ "pull", "--ff-only", "--quiet", "origin", "main" }, function(pulled, _, err)
          if not pulled then
            print("update: git pull failed: " .. err)
            return fail(err:find("[Cc]ould not resolve host") and "Bağlantı Yok · Sonra Yeniden Dene" or "Güncelleme Uygulanamadı · Ayrıntı Konsolda")
          end
          git({ "diff", "--name-only", before, "HEAD" }, function(_, files)
            local n = state.behind
            -- shown once after the reload (see M.start)
            hs.settings.set("nimbstia.updated", n > 0 and n or 1)
            local function reload() hs.reload() end
            -- the app icon is built from the logo: rebuild it only when its sources changed
            if files:find("assets/logo%.svg") or files:find("scripts/build%-app%.sh") or files:find("scripts/svg2png%.js") then
              local t = Keep.task("/bin/bash", reload, { DIR .. "/scripts/build-app.sh" })
              if not t then reload() end
            else
              Keep.after(0.2, reload)
            end
          end)
        end)
      end)
    end)
  end)
end

function M.start(notify)
  onChange = notify
  if not M.enabled() then return end
  local n = hs.settings.get("nimbstia.updated")
  if n then
    hs.settings.clear("nimbstia.updated")
    hs.alert.show("Nimbstia Güncellendi · " .. tostring(n) .. " Değişiklik", 2.2)
  end
  Keep.after(30, function() M.check(true) end)
  M.timer = hs.timer.doEvery(CHECK_EVERY, function() M.check(true) end)
end

return M
