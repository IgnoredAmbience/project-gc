-- Series Data ---------------------------

local series = {
  default = {
    bookmarks = {},
    points_override = {},
    patterns = { "(%d+)" }
  },
  church_micro = {
    bookmarks = {
      ['1-499']     = 'b9597df5-b3c8-42ff-bab7-96a965e7f026',
      ['500-999']   = '3c39c50e-ee63-4832-a4a4-3f4d80bae0b4',
      ['1000-1499'] = '5bb0741d-96fe-4c1a-a31b-1027c0519244',
      ['1500-1999'] = '6b73a5ea-8b31-4d7d-9b55-2935692eebd6',
      ['2000-2499'] = '30175d87-5b18-4c48-81ef-7104dbe0468e',
      ['2500-2999'] = '89451dc6-2eac-458a-b3af-f1e7fc5455ba',
      ['3000-3499'] = 'c789285e-db46-4567-85ab-4646144f54b4',
      ['3500-3999'] = '3e094722-564a-4826-b099-28e35d45ec67',
      ['4000-4999'] = '76a3f34c-c78d-45be-8d30-f235fe533de7',
      ['5000-5999'] = '26398daf-be58-4ff6-bb8f-8dc371858635',
      ['6000-6999'] = '9218f7e0-2ccf-42bf-a90b-618a037d1ef3',
      ['7000-7999'] = 'e3b22fa8-934d-48c6-8d6e-b7960cee06ed',
      ['8000-8999'] = 'c1bdcdf3-8237-4bc2-a597-b0ecd45a69f9',
      ['archived']  = 'd8064b97-58f1-40cd-ab9e-4f5ff784a350'
    },
    points_override = {
      GC28KN6 = 1190, -- Bonus CM
      GC34P79 = 2123  -- Numbered in body
    },
    patterns = {
      "Chur?ch.-Micro.-(%d+)",
      "CM.-(%d+)",
      "Church[%s%p]*Nano.-(%d+)",
      "Church[%s%p]*Small.-(%d+)",
      "Church[%s%p]*Large.-(%d+)",
      "Church[%s%p]*Mirco.-(%d+)",
      "(%d+)%s*Church%s*Micro",
      "(%d+)" -- Fallback of last resort
    }
  }
}

-- General Functions -----------------------------

function MathRound(n)
  -- Rounds towards positive infinity
  return MathFloor(n + 0.5)
end

local function DateDiff(date1, date2)
  -- Returns whole number of days between dates as an integer
  local dayInSeconds = 86400
  return MathRound((date2.time - date1.time) / dayInSeconds)
end

local function TableAppend(first, second)
  -- In-place integer keys append of second to first
  for _, v in IPairs(second) do
    TableInsert(first, v)
  end
  return first
end

local function TableIter(table, f)
  -- In place map of f over items of table
  for k, v in Pairs(table) do
    f(k, v)
  end
end

local function TableSelect(table, f)
  -- Return a new Table containing entries of 'table' for which f returns true
  local r = {}
  TableIter(table, function(k, v) if f(k, v) then TableInsert(r, v) end end)
  return r
end

local function TableInvert(table)
  -- Returns copy of table with keys swapped with values.
  -- Useful for creating sets of values with constant checking time
  local inverted = {}
  TableIter(table, function(k, v) inverted[v] = k end)
  return inverted
end

-- Configuration ----------------------------------
local args=...
local profileName = args.profileName
local profileId = args.profileId

local function MakeConfig(initial, default)
  local new = initial
  for k,v in Pairs(default) do
    if Type(new[k]) == 'nil' then
      new[k] = v
    end
  end

  -- Copy over our series settings
  for k,v in Pairs(series[new.series]) do
    new[k] = v
  end

  for k,v in Pairs(new) do
    local prepend_to = StringMatch(k, '^pre_(.*)$')
    if prepend_to then
      new[prepend_to] = TableAppend(new[k], new[prepend_to])
    end
  end

  new.filter.bookmarks = new.bookmarks

  if new.case_insensitive then
    for i, v in IPairs(new.patterns) do
      new.patterns[i] = StringLower(v)
    end
  end

  return new
end

--[[
Permitted config options:
Challenge fulfillment:
* sum: sum of points required for fulfillment (default: 0)
* count: Minimum number of cache finds to qualify (default: 0)
* days: Minimum number of days in which finds must be made in the period (default: 0)
* findWindow: Number of consecutive days in which finds must be made (0 for all-time, 1 for same day, 2 for consecutive days, etc) (default: 0)

Cache requirements:
* series: builtin cache series to use (default: 'default')
* add_bookmarks: [guid] additional bookmark lists of eligible caches
* add_patterns: [pattern] additional patterns used to retrieve points from cache name (prepended to existing, so checked first)
* add_points_override: { gccode -> points } Caches that have hardcoded points values
* case_insensitive: bool Whether patterns are case insensitive (default: true)
* filter: additional cache filter requirements (passed to PGC_GetFinds)
]]
local conf = MakeConfig(args.config, { sum = 0, count = 0, days = 0, findWindow = 0, series = 'default', case_insensitive = true,
                                       -- add_bookmarks = {}, add_patterns = {}, add_points_override = {}, -- commented out for efficiency
                                       filter = {} })

Print(conf)

-- Script-specific functions ---------------------------------

local function CachePoints(cache)
  local match
  if conf.points_override[cache.gccode] then
    match = conf.points_override[cache.gccode]
  else
    local name = (conf.case_insensitive and StringLower(cache.cache_name)) or cache.cache_name
    -- Rejoin numbers
    name = StringGsub(name, "(%d+),(%d+)", "%1%2")

    for i, pattern in IPairs(conf.patterns) do
      match = StringMatch(name, pattern)
      if match then
        if i > 1 and i == #(conf.patterns) then
          Print(StringFormat("Warning: used fallback pattern for %s: %s :: %d\n", cache.gccode, cache.cache_name, match))
        end
        break
      end
    end
  end

  local matchNum = ToNumber(match)
  if (not match) or (not matchNum) then
    Print(StringFormat("Warning, trouble parsing points from %s: %s\n", cache.gccode, cache.cache_name))
    return 0 -- Hopefully someone will notice if the cache has 0 points
  end

  return matchNum
end

-- PGC_GetFinds with additional filters:
-- * bookmarks:[guid] only fetch caches in this set of bookmark lists
local function GetFinds(profileId, params)
  params = params or {}
  params.filter = params.filter or {}

  local gccodes = params.filter.gccodes or {}
  if params.filter.bookmarks then
    for _, guid in Pairs(params.filter.bookmarks) do
      local list = PGC_GetBookmarklist(guid)
      TableAppend(gccodes, list)
    end
    params.filter.bookmarks = nil
  end

  -- 25 picked arbitrarily as maximum supported by PGC filters
  if #gccodes < 25 then
    params.filter.gccodes = gccodes
    gccodes = nil
  else
    params.filter.gccodes = nil
  end

  local caches = PGC_GetFinds(profileId, params)

  if gccodes then
    local gccodes_set = TableInvert(gccodes)
    return TableSelect(caches, function(k,v) return gccodes_set[v.gccode] end)
  else
    return caches
  end
end

---- Window Functions ------------------------


local function Window(size, opts)
  local this
  local data = {}
  local index = 1

  -- Special case if we don't care about windows...
  local indefiniteWindow = (size < 1)
  size = MathMax(1, size)

  local results = { nearestBest = { sum = 0, dayCount = 0, findCount = 0 } }

  local previousDate = nil
  local dateFormat = Date.Format("yyyy-mm-dd")

  -- Configurable options
  -- Checking parameters
  local minSum       = 0
  local minDayCount  = 0
  local minFindCount = 0
  local sumField = 'difficulty'

  -- check all intermediate windows with a cache find when adjusting period
  local checkAll = false

  -- Function passed table of days for window to be checked
  local checkFunction
  local updateSumFunction

  local function resetIndex(index)
    data[index].sum = 0
    data[index].dayCount = 0
    while TableRemove(data[index]) do end
  end

  local function check()
    local rv = checkFunction(this)
    if rv then TableInsert(results, rv) end
  end

  local function increment(days)
    if indefiniteWindow then return end

    if days < 0 then
      Print("Invalid date difference detected: ", days)
      Print(prevDate, visitdate)
    end

    -- Slide window by required amount of days (upto size)
    local checkWindow = true
    for day = 1, MathMin(days, size) do
      -- Move on the index before the check, the index element points to the beginning of the window
      index = (index % size) + 1
      if checkWindow then
        -- Check window on first loop, or always if checkAll set
        check()
        checkWindow = checkAll
      end
      resetIndex(index)
      -- Index now points to the end of the window
    end
  end

  local function constructResultTableEntry(this)
    return returnVal
  end

  -- Checks window meets conditions, and copies current state to result table if so
  -- data is a table passed into the function, corresponding to the data local variable
  -- Side effect: Records current 'nearestBest' window based on sum
  local function defaultCheckFunction(this)
    local sum = 0         -- Sum of metric being calculated
    local dayCount = 0    -- # of days in window with finds
    local findCount = 0   -- # of finds in window

    local returnVal = nil

    -- Collect period summary
    for _, d in this:IDays() do
      sum = sum + d.sum
      findCount = findCount + #d
      dayCount = dayCount + d.dayCount
    end

    -- If qualifies, do the heavy lifting of copying to results table
    if sum >= minSum and findCount >= minFindCount and dayCount >= minDayCount then
      returnVal = { sum = sum, dayCount = dayCount, findCount = findCount }
      for _, d in this:IDays() do
        for _, c in IPairs(d) do
          TableInsert(returnVal, c)
        end
      end
    end

    if returnVal == nil and #(this.results) == 0 and sum > this.results.nearestBest.sum then
      local nb = { sum = sum, dayCount = dayCount, findCount = findCount }
      for _, d in this:IDays() do
        for _, c in IPairs(d) do
          TableInsert(nb, c)
        end
      end
      this.results.nearestBest = nb
    end

    return returnVal
  end

  local function defaultUpdateSumFunction(this, day, cache)
    day.sum = day.sum + cache[sumField]
  end

  -- Public Functions ----

  -- For use inside of callback functions
  -- Iterates through each day in data, starting at current index
  local function IDays()
    local function f(init, var)
      if var == size then
        return nil, nil
      else
        return (var + 1), data[((init + var - 1) % size) + 1]
      end
    end
    return f, index, 0
  end

  local function is_indefinite_window()
    return indefiniteWindow
  end

  local function sort_results()
    TableSort(results, function (r1, r2)
      return r1.sum > r2.sum
    end)
  end

  -- check() must be called after final run
  local function add_cache(cache)
    local visitDate = dateFormat:parse(cache.visitdate)

    -- Initialise previousDate on first run
    if not previousDate then previousDate = visitDate end
    local diff = DateDiff(previousDate, visitDate)

    increment(diff)
    TableInsert(data[index], cache)
    if diff > 0 then
      if indefiniteWindow then
        data[index].dayCount = data[index].dayCount + 1
      else
        data[index].dayCount = 1
      end
    end
    updateSumFunction(this, data[index], cache)

    previousDate = visitDate
  end

  local function add_caches(caches)
    for _, cache in IPairs(caches) do
      add_cache(cache)
    end
    check()
    sort_results()
  end

  -- Init ----
  minSum = opts.minSum or minSum
  minDayCount = opts.minDayCount or minDayCount
  minFindCount = opts.minFindCount or minFindCount
  sumField = opts.sumField or sumField
  checkAll = opts.checkAll or checkAll
  checkFunction = opts.checkFunction or defaultCheckFunction
  updateSumFunction = opts.updateSumFunction or defaultUpdateSumFunction

  for i = 1, size do
    TableInsert(data, { sum = 0, dayCount = 0 } )
  end

  this = { IDays = IDays, is_indefinite_window = is_indefinite_window,
           sort_results = sort_results, results = results, add_cache = add_cache, add_caches = add_caches }
  return this
end

-- Output functions -------------------------------------

local types = {
  ["Traditional Cache"]                      = "http://www.geocaching.com/images/wpttypes/sm/2.gif",
  ["Multi-cache"]                            = "http://www.geocaching.com/images/wpttypes/sm/3.gif",
  ["Virtual Cache"]                          = "http://www.geocaching.com/images/wpttypes/sm/4.gif",
  ["Letterbox Hybrid"]                       = "http://www.geocaching.com/images/wpttypes/sm/5.gif",
  ["Event Cache"]                            = "http://www.geocaching.com/images/wpttypes/sm/6.gif",
  ["Cache In Trash Out Event"]               = "http://www.geocaching.com/images/wpttypes/sm/13.gif",
  ["Mega-Event Cache"]                       = "http://www.geocaching.com/images/wpttypes/sm/mega.gif",
  ["Lost and Found Event Cache"]             = "http://www.geocaching.com/images/wpttypes/sm/3653.gif",
  ["Groundspeak Lost and Found Celebration"] = "http://www.geocaching.com/images/wpttypes/sm/3774.gif",
  ["Groundspeak Block Party"]                = "http://www.geocaching.com/images/wpttypes/sm/4738.gif",
  ["Giga-Event Cache"]                       = "http://www.geocaching.com/images/wpttypes/sm/giga.gif",
  ["Unknown Cache"]                          = "http://www.geocaching.com/images/wpttypes/sm/8.gif",
  ["Groundspeak HQ"]                         = "http://www.geocaching.com/images/wpttypes/sm/3773.gif",
  ["Project APE Cache"]                      = "http://www.geocaching.com/images/wpttypes/sm/9.gif",
  ["Webcam Cache"]                           = "http://www.geocaching.com/images/wpttypes/sm/11.gif",
  ["Earthcache"]                             = "http://www.geocaching.com/images/wpttypes/sm/earthcache.gif",
  ["GPS Adventures Exhibit"]                 = "http://www.geocaching.com/images/wpttypes/sm/1304.gif",
  ["Wherigo Cache"]                          = "http://www.geocaching.com/images/wpttypes/sm/wherigo.gif",
  ["Benchmark"]                              = "http://www.geocaching.com/images/wpttypes/sm/27.gif",
  ["Locationless (Reverse) Cache"]           = "http://www.geocaching.com/images/wpttypes/sm/12.gif"
}

function cacheHeaderHtml(dstTbl, additionalFields)
  TableInsert(dstTbl, '<tr><td/><td>GC Code</td><td>Name</td>')
  for _,fld in IPairs(additionalFields) do
    TableInsert(dstTbl, StringFormat('<td>%s</td>', fld))
  end
  TableInsert(dstTbl, '</tr>\n')
end

function cacheHtml(cache, dstTbl, additionalFields)
  TableInsert(dstTbl, '<tr>')
  TableInsert(dstTbl, StringFormat('<td><img src="%s" /></td>', types[cache.type]))
  TableInsert(dstTbl, StringFormat('<td><a href="http://coord.info/%s"> %s</a></td>', cache.gccode, cache.gccode))
  TableInsert(dstTbl, StringFormat('<td>%s</td>', cache.cache_name))
  for _,fld in IPairs(additionalFields) do
    TableInsert(dstTbl, StringFormat('<td>%s</td>', cache[fld]))
  end
  TableInsert(dstTbl, '</tr>\n')
end

function cacheLog(cache, dstTbl, additionalFields)
  TableInsert(dstTbl, StringFormat('[url=http://coord.info/%s]%s[/url] %s (%s) ', cache.gccode, cache.gccode, cache.cache_name, cache.type))
  for _, fld in IPairs(additionalFields) do
    TableInsert(dstTbl, cache[fld])
    TableInsert(dstTbl, ' ')
  end
  TableInsert(dstTbl, '\n')
end

------------------------------------------------------------


local caches = GetFinds(profileId, { fields = { 'gccode', 'cache_name', 'type', 'visitdate' }, order = 'OLDESTFIRST', filter = conf.filter})
TableIter(caches, function (k, v) v.points = CachePoints(v) end)

local window = Window(conf.findWindow, { minSum = conf.sum, minDayCount = conf.days, minFindCount = conf.count, sumField = 'points' })
window.add_caches(caches)
local results = window.results

local ok = false
local logLines = {}
local htmlLines = {}

if #results > 0 then
  for i, r in IPairs(results) do
    ok = true
    local msg = StringFormat('Over %d days, %s found %d Church Micro caches totalling %d points:\n', r.dayCount, profileName, r.findCount, r.sum)

    if i == 1 then
      TableInsert(logLines, msg)
    end

    TableInsert(htmlLines, msg)
    TableInsert(htmlLines, '<table>')
    cacheHeaderHtml(htmlLines, {'Points', 'Found'})
    for _, cache in IPairs(r) do
      if i == 1 then cacheLog(cache, logLines, {'points', 'visitdate'}) end
      cacheHtml(cache, htmlLines, {'points', 'visitdate'})
    end
    TableInsert(htmlLines, '</table><br/>')
  end
else
  local r = results.nearestBest
  local msg = StringFormat('%s does not qualify, but the nearest period to satisfying the challenge was %d Church Micro caches totalling %d points over %d days:\n', profileName, r.findCount, r.sum, r.dayCount)

  TableInsert(htmlLines, msg)
  TableInsert(htmlLines, '<table>')
  cacheHeaderHtml(htmlLines, {'Points', 'Found'})
  for _, cache in IPairs(r) do
    cacheHtml(cache, htmlLines, {'points', 'visitdate'})
  end
  TableInsert(htmlLines, '</table><br/>')
end

return { ok = ok, log = TableConcat(logLines), html = TableConcat(htmlLines) }
