-- Clipboard history panel (⌃V): copied text and images plus the screenshots folder,
-- shown in a searchable webview with live previews.
local Keep = require("keep")
local M = {}

local HOME = os.getenv("HOME")
local BASE = HOME .. "/.hammerspoon"
local DATA_DIR = BASE .. "/clipdata"
local IMG_DIR = DATA_DIR .. "/images"
local THUMB_DIR = DATA_DIR .. "/thumbs"
local DIMS_FILE = DATA_DIR .. "/dims.json"
local HTML_FILE = BASE .. "/clipboard.html"
local SETTINGS_KEY = "clip.v2"

local TEXT_MAX, IMAGE_MAX, SHOT_MAX = 300, 40, 150
-- Texts larger than this are not recorded: the whole history is re-serialised on every copy,
-- so one 30 MB log would make every later copy and panel open stall.
local TEXT_BYTES_MAX = 512 * 1024
local PREVIEW_CHARS = 6000
local THUMB_PX = 560
local W, H = 1060, 660

M.shotDir = require("config").screenshotDir

local PB = require("pb") -- secret pasteboard types and password-manager apps live there
local IMAGE_TYPES = { ["public.png"] = true, ["public.tiff"] = true, ["public.jpeg"] = true }
local SHOT_EXT = { png = true, jpg = true, jpeg = true, heic = true }

for _, d in ipairs({ DATA_DIR, IMG_DIR, THUMB_DIR }) do hs.fs.mkdir(d) end

-- ---------------------------------------------------------------- helpers

local function fileExists(p) return p and hs.fs.attributes(p) ~= nil end

local function readFile(p)
  local f = io.open(p, "rb")
  if not f then return nil end
  local d = f:read("a"); f:close()
  return d
end

local function writeFile(p, d)
  local f = io.open(p, "wb")
  if not f then return false end
  f:write(d); f:close()
  return true
end

local function shellQuote(s) return "'" .. (s:gsub("'", "'\\''")) .. "'" end

-- Cut a UTF-8 string to at most n bytes without splitting a character.
local function utf8Cut(s, n)
  if #s <= n then return s end
  local i = n
  while i > 0 do
    local b = s:byte(i + 1)
    if not b or b < 0x80 or b >= 0xC0 then break end
    i = i - 1
  end
  return s:sub(1, i)
end

local function safeText(s)
  if utf8.len(s) then return s end
  return (s:gsub("[\128-\255]", "?"))
end

local seq = 0
local function newId()
  seq = seq + 1
  return string.format("%x%x%02x", os.time(), seq, math.random(0, 255))
end

-- ---------------------------------------------------------------- storage

local history = hs.settings.get(SETTINGS_KEY)
if type(history) ~= "table" then
  history = {}
  local legacy = hs.settings.get("clipHistory")
  if type(legacy) == "table" then
    for i, text in ipairs(legacy) do
      if type(text) == "string" then
        -- Legacy entries have no timestamp; small fake values keep their order and mark them as "older".
        table.insert(history, { id = "legacy" .. i, kind = "text", text = text, t = 100000 - i })
      end
    end
  end
end

local function save() hs.settings.set(SETTINGS_KEY, history) end

local function trim()
  local nText, nImg, keep = 0, 0, {}
  for _, e in ipairs(history) do -- newest first
    local n, limit
    if e.kind == "image" then nImg = nImg + 1; n, limit = nImg, IMAGE_MAX
    else nText = nText + 1; n, limit = nText, TEXT_MAX end
    if e.pinned or n <= limit then
      table.insert(keep, e)
    elseif e.kind == "image" and e.path then
      os.remove(e.path)
    end
  end
  history = keep
end

local function findEntry(id)
  for i, e in ipairs(history) do if e.id == id then return e, i end end
end

local shots = {}
local function findShot(id)
  for _, s in ipairs(shots) do if s.id == id then return s end end
end

-- ---------------------------------------------------------------- thumbnails

local dims = {}
do
  local ok, d = pcall(hs.json.read, DIMS_FILE)
  if ok and type(d) == "table" then dims = d end
end
local dimsTimer
local function saveDimsSoon()
  if dimsTimer then dimsTimer:stop() end
  dimsTimer = hs.timer.doAfter(2, function() hs.json.write(dims, DIMS_FILE, false, true) end)
end

local function thumbPathFor(path)
  local a = hs.fs.attributes(path)
  if not a then return nil end
  return THUMB_DIR .. "/" .. hs.hash.MD5(path .. ":" .. tostring(a.modification) .. ":" .. tostring(a.size)) .. ".jpg"
end

local thumbCache = {}
local function thumbURI(tp)
  local c = thumbCache[tp]
  if c then return c end
  local d = readFile(tp)
  if not d then return nil end
  c = "data:image/jpeg;base64," .. hs.base64.encode(d)
  thumbCache[tp] = c
  return c
end

local thumbQueue, queued, thumbBusy = {}, {}, false
local onThumbReady -- set below, once the panel exists

local function pumpThumbs()
  if thumbBusy then return end
  local job = table.remove(thumbQueue, 1)
  while job and fileExists(job.thumb) do job = table.remove(thumbQueue, 1) end
  if not job then return end
  thumbBusy = true
  local script = 'sips -g pixelWidth -g pixelHeight "$1" && sips -Z ' .. THUMB_PX ..
    ' -s format jpeg -s formatOptions 74 "$1" --out "$2" >/dev/null'
  M.thumbTask = hs.task.new("/bin/sh", function(code, out)
    thumbBusy = false
    queued[job.thumb] = nil
    local w, h = (out or ""):match("pixelWidth:%s*(%d+)"), (out or ""):match("pixelHeight:%s*(%d+)")
    if w and h then dims[job.thumb] = { tonumber(w), tonumber(h) }; saveDimsSoon() end
    if code == 0 and onThumbReady then onThumbReady(job) end
    pumpThumbs()
  end, { "-c", script, "sh", job.src, job.thumb })
  if not M.thumbTask:start() then thumbBusy = false end
end

local function queueThumb(src, tp)
  if not tp or queued[tp] or fileExists(tp) then return end
  queued[tp] = true
  table.insert(thumbQueue, { src = src, thumb = tp })
  pumpThumbs()
end

-- ---------------------------------------------------------------- screenshots folder

local function scanShots()
  local list = {}
  local ok, iter, dirObj = pcall(hs.fs.dir, M.shotDir)
  if ok and iter then
    for f in iter, dirObj do
      local ext = f:match("%.(%w+)$")
      if f:sub(1, 1) ~= "." and ext and SHOT_EXT[ext:lower()] then
        local p = M.shotDir .. "/" .. f
        local a = hs.fs.attributes(p)
        if a and a.mode == "file" then
          table.insert(list, { id = "shot:" .. f, kind = "shot", path = p, name = f, t = a.modification, size = a.size })
        end
      end
    end
  end
  table.sort(list, function(a, b) return a.t > b.t end)
  while #list > SHOT_MAX do table.remove(list) end
  shots = list
end

-- ---------------------------------------------------------------- items sent to the page

local currentItems = {}

local function buildItems()
  local list = {}
  for _, e in ipairs(history) do
    local it = { id = e.id, kind = e.kind, t = e.t, app = e.app, pinned = e.pinned == true, edited = e.edited == true }
    if e.kind == "text" then
      local text = safeText(e.text)
      it.text = utf8Cut(text, PREVIEW_CHARS)
      it.truncated = #it.text < #text
      it.len = utf8.len(text) or #text
      it.lines = select(2, text:gsub("\n", "")) + 1
      it.words = select(2, text:gsub("%S+", ""))
      table.insert(list, it)
    elseif e.kind == "image" and fileExists(e.path) then
      local a = hs.fs.attributes(e.path)
      it.size = a and a.size
      it.src = e.path
      it.thumb = thumbPathFor(e.path)
      table.insert(list, it)
    end
  end
  for _, s in ipairs(shots) do
    table.insert(list, { id = s.id, kind = "shot", t = s.t, name = s.name, size = s.size,
      src = s.path, thumb = thumbPathFor(s.path), pinned = false })
  end
  for _, it in ipairs(list) do
    local d = it.thumb and dims[it.thumb]
    if d then it.w, it.h = d[1], d[2] end
  end
  -- Newest first. (The old comparator compared pinned=nil on screenshots with pinned=false on text,
  -- never reached the time check and mixed the two lists.) Pinned items live under their own filter.
  table.sort(list, function(a, b)
    if a.t ~= b.t then return a.t > b.t end
    return a.id < b.id
  end)
  currentItems = list
  return list
end

-- ---------------------------------------------------------------- panel

local Panel = require("panel")
local panel -- created below
local sent = {} -- id -> thumb path already delivered to the page
local pushTimer

local function pushThumbs()
  if pushTimer then pushTimer:stop(); pushTimer = nil end
  local pending = {}
  for _, it in ipairs(currentItems) do
    if it.thumb and sent[it.id] ~= it.thumb then
      if fileExists(it.thumb) then table.insert(pending, it) else queueThumb(it.src, it.thumb) end
    end
  end
  local i = 1
  local function step()
    pushTimer = nil
    if not panel.visible then return end
    local batch, n = {}, 0
    while i <= #pending and n < 12 do
      local it = pending[i]; i = i + 1
      local uri = thumbURI(it.thumb)
      if uri then
        local d = dims[it.thumb]
        batch[it.id] = { u = uri, w = d and d[1], h = d and d[2] }
        sent[it.id] = it.thumb
        n = n + 1
      end
    end
    if n > 0 then panel:js("Clip.thumbs(" .. hs.json.encode(batch) .. ")") end
    if i <= #pending then pushTimer = hs.timer.doAfter(0.015, step) end
  end
  step()
end

local function pushItems(andOpen, selectId)
  local json = hs.json.encode({ items = buildItems(), now = os.time(), select = selectId })
  panel:js("Clip.setItems(" .. json .. ")" .. (andOpen and ";Clip.open()" or ""))
  pushThumbs()
end

onThumbReady = function()
  if panel and panel.visible then pushThumbs() end
end

-- ---------------------------------------------------------------- actions from the page

local ownChange = -1

local function writeToPasteboard(e)
  if e.kind == "text" then
    hs.pasteboard.setContents(e.text)
  else
    if not fileExists(e.path) then return false end
    if e.path:lower():match("%.png$") then
      local d = readFile(e.path)
      if not d then return false end
      hs.pasteboard.writeAllData({ ["public.png"] = d })
    else
      local img = hs.image.imageFromPath(e.path)
      if not img then return false end
      hs.pasteboard.writeObjects(img)
    end
  end
  ownChange = hs.pasteboard.changeCount()
  return true
end

local function bump(e, i)
  table.remove(history, i)
  e.t = os.time()
  table.insert(history, 1, e)
  save()
end

local function handle(p, msg)
  local a, id = msg.action, msg.id
  local e, idx = findEntry(id)
  if not e then e = findShot(id) end
  if not e then return end

  if a == "paste" then
    if not writeToPasteboard(e) then hs.alert.show("Öğe okunamadı", 1); return end
    if idx then bump(e, idx) end
    p:hide(true)
    Keep.after(0.15, function() hs.eventtap.keyStroke({ "cmd" }, "v", 0) end)
  elseif a == "copy" then
    -- Copy keeps the panel open so several items can be picked one after another; the list does not jump.
    if not writeToPasteboard(e) then p:js("Clip.toast('Öğe okunamadı')"); return end
    p:js("Clip.toast('Panoya kopyalandı')")
  elseif a == "edit" and idx and e.kind == "text" and type(msg.text) == "string" and msg.text:match("%S") then
    for i = #history, 1, -1 do
      if i ~= idx and history[i].kind == "text" and history[i].text == msg.text then
        e.pinned = e.pinned or history[i].pinned
        table.remove(history, i)
        if i < idx then idx = idx - 1 end
      end
    end
    e.text, e.edited = msg.text, true
    bump(e, idx)
    pushItems(false, e.id)
    p:js("Clip.toast('Güncellendi')")
  elseif a == "editImage" and (e.kind == "shot" or e.kind == "image") and e.path then
    -- open the image in Clipstia to crop / mark it up; saving there writes a new file
    p:hide(false)
    if Shot and Shot.editFile then Keep.after(0.2, function() Shot.editFile(e.path) end) end
  elseif a == "delete" and e.kind == "shot" then
    -- Screenshot files go to the Trash (recoverable), never straight to deletion.
    local name = e.path:match("[^/]+$")
    local base, ext = name:match("^(.*)(%.[^.]+)$")
    local dest, n = HOME .. "/.Trash/" .. name, 2
    while hs.fs.attributes(dest) do dest = HOME .. "/.Trash/" .. (base or name) .. " " .. n .. (ext or ""); n = n + 1 end
    if os.rename(e.path, dest) then
      scanShots()
      pushItems(false)
      p:js("Clip.toast('Çöp Sepeti\\'ne taşındı')")
    else
      p:js("Clip.toast('Silinemedi')")
    end
  elseif a == "delete" and idx then
    table.remove(history, idx)
    if e.kind == "image" and e.path then os.remove(e.path) end
    save()
    pushItems(false)
  elseif a == "pin" and idx then
    e.pinned = not e.pinned or nil
    save()
    pushItems(false)
  elseif a == "reveal" then
    if e.kind == "text" then
      local url = e.text:match("^%s*(https?://%S+)%s*$")
      if not url then return end
      p:hide(false)
      hs.urlevent.openURL(url)
    else
      p:hide(false)
      hs.execute("open -R " .. shellQuote(e.path))
    end
  end
end

panel = Panel.new({
  name = "clip", html = HTML_FILE, w = W, h = H,
  onMessage = handle,
  onShow = function() scanShots(); pushItems(true) end,
})
M.panel = panel

function M.toggle() panel:toggle() end

-- ---------------------------------------------------------------- pasteboard watcher

local imageQuietUntil, pauseUntil = 0, 0
-- Ignore every pasteboard change for a moment (used by helpers that borrow the pasteboard).
function M.pause(sec) pauseUntil = hs.timer.secondsSinceEpoch() + (sec or 0.5) end
-- Lightshot hands its capture over through the pasteboard; it is already saved to the screenshots folder.
function M.quietImages(sec) imageQuietUntil = hs.timer.secondsSinceEpoch() + (sec or 2) end

local function addEntry(e)
  for i, old in ipairs(history) do
    if (e.kind == "text" and old.text == e.text) or (e.kind == "image" and old.path == e.path) then
      e.pinned = old.pinned
      table.remove(history, i)
      break
    end
  end
  local app = hs.application.frontmostApplication()
  e.id, e.t, e.app = newId(), os.time(), app and app:name() or nil
  table.insert(history, 1, e)
  trim()
  save()
  if panel.visible then pushItems(false) end
end

local function captureImage()
  if hs.timer.secondsSinceEpoch() < imageQuietUntil then return end
  local data = hs.pasteboard.readDataForUTI("public.png")
  if not data or #data == 0 then
    local img = hs.pasteboard.readImage()
    if not img then return end
    local tmp = DATA_DIR .. "/incoming.png"
    if not img:saveToFile(tmp) then return end
    data = readFile(tmp)
    os.remove(tmp)
    if not data or #data == 0 then return end
  end
  local path = IMG_DIR .. "/" .. hs.hash.MD5(data) .. ".png"
  if not fileExists(path) and not writeFile(path, data) then return end
  addEntry({ kind = "image", path = path })
  queueThumb(path, thumbPathFor(path))
end

M.watcher = hs.pasteboard.watcher.new(function(text)
  if hs.pasteboard.changeCount() == ownChange then return end
  if hs.timer.secondsSinceEpoch() < pauseUntil then return end
  local types = hs.pasteboard.pasteboardTypes() or {}
  if PB.isSecret(types) or PB.frontAppIsSecret() then return end
  local hasImage = false
  for _, t in ipairs(types) do
    if IMAGE_TYPES[t] then hasImage = true end
  end
  if text and #text > TEXT_BYTES_MAX then return end
  if text and text:match("%S") then
    addEntry({ kind = "text", text = text })
  elseif hasImage then
    captureImage()
  end
end)
M.watcher:start()

-- ---------------------------------------------------------------- screenshots folder watcher + warm-up

local scanTimer
M.shotWatcher = hs.pathwatcher.new(M.shotDir, function()
  if scanTimer then scanTimer:stop() end
  scanTimer = hs.timer.doAfter(0.5, function()
    scanShots()
    for _, s in ipairs(shots) do queueThumb(s.path, thumbPathFor(s.path)) end
    if panel.visible then pushItems(false) end
  end)
end):start()

-- Build missing thumbnails in the background and drop ones nothing points to any more.
Keep.after(1, function()
  scanShots()
  local live = {}
  local function want(path)
    local tp = thumbPathFor(path)
    if tp then live[tp:match("[^/]+$")] = true; queueThumb(path, tp) end
  end
  for _, s in ipairs(shots) do want(s.path) end
  for _, e in ipairs(history) do if e.kind == "image" and e.path then want(e.path) end end
  for f in hs.fs.dir(THUMB_DIR) do
    if f:match("%.jpg$") and not live[f] then
      os.remove(THUMB_DIR .. "/" .. f)
      dims[THUMB_DIR .. "/" .. f] = nil
    end
  end
end)

save()
return M
