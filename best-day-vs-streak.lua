-- When you find this cache your Best Day (the highest number of caches that you found on a day) must be smaller than your Longest Streak (the number of consecutive days of finding caches).

-- General Functions -----------------------------

local DateFormat = Date.Format("yyyy-mm-dd")

function MathRound(n)
  -- Rounds towards positive infinity
  return MathFloor(n + 0.5)
end

local function DateDiff(date1, date2)
  -- Returns whole number of days between dates as an integer
  local dayInSeconds = 86400
  return MathRound((date2.time - date1.time) / dayInSeconds)
end

-- Configuration ----------------------------------
local args=...
local profileName = args.profileName
local profileId = args.profileId
local conf = args.config or {}

local bestStreak = 0
local currentStreak = 0
local bestDay = 0
local currentDay = 0

local function checkFun(streak, day)
  return streak > day
end

-- Table of { date, bestStreak, bestDay } tables, one for each time the cacher qualifies/disqualifies themselves.
local eligibleBoundaries = {}

local caches = PGC_GetFinds(profileId, { fields = { 'gccode', 'visitdate' }, order = 'OLDESTFIRST' })

local foundDate = nil
local badFind = false
local foundBestStreak = 0
local foundBestDay = 0

local prevDate = DateFormat:parse("1980-01-01")
local prevCheck = false
for idx, cache in IPairs(caches) do
  local date = DateFormat:parse(cache.visitdate)
  local diff = DateDiff(prevDate, date)

  if diff == 0 then
    currentDay = currentDay + 1
  elseif diff == 1 then
    currentDay = 1
    currentStreak = currentStreak + 1
  elseif diff > 1 then
    currentDay = 1
    currentStreak = 1
  else
    Print("Negative date diff! Something is wrong!\n")
    currentDay = 1
    currentStreak = 1
  end

  if currentDay > bestDay then bestDay = currentDay end
  if currentStreak > bestStreak then bestStreak = currentStreak end

  local check = checkFun(bestStreak, bestDay)
  if (check and not prevCheck) or ((not check) and prevCheck) or (idx == #caches) then
    TableInsert(eligibleBoundaries, { date = cache.visitdate, bestStreak = bestStreak, bestDay = bestDay, check = check })
  end

  if cache.gccode == conf.gccode then
    foundDate = cache.visitdate
    badFind = not check
    foundBestStreak = bestStreak
    foundBestDay = bestDay
  end

  prevCheck = check
  prevDate = date
end

local ok = (foundDate and not badFind) or (not foundDate and prevCheck)

local blurb
if foundDate then
  blurb = StringFormat("%s found this cache on %s. At this point they were %seligible, their best streak was %d and best day was %d.",
                       profileName, foundDate, (badFind and "in") or "", foundBestStreak, foundBestDay)
else
  blurb = StringFormat("%s has not previously found this cache and is%s currently eligible to log this challenge.",
                       profileName, (prevCheck and "") or " not")
end
local blurb2 = "The table below lists dates at which eligibility to log this cache starts and stops. The cache may only be logged during an eligible period."
local tableHtml = "<table><tr style='font-weight:bold'><td>Date</td><td>Best Streak</td><td>Best Day</td><td/></tr>"
local tableLog = "Date\t\t\tBest Streak\tBest Day\tEligible?\n"

local html = {"<h2>", blurb, "</h2><h3>", blurb2, "</h3>", tableHtml}
local log = {blurb, "\n", blurb2, "\n\n", tableLog}

for _, day in IPairs(eligibleBoundaries) do
  if day.check then
    TableInsert(html, '<tr style="background: #98fb98;">')
  else
    TableInsert(html, '<tr style="background: #f08080;">')
  end

  TableInsert(html, StringFormat("<td>%s</td><td>%d</td><td>%d</td>", day.date, day.bestStreak, day.bestDay))
  TableInsert(log, StringFormat("%s\t%d\t\t\t%d\t\t", day.date, day.bestStreak, day.bestDay))

  if day.check then
    TableInsert(html, '<td><img src="http://www.geocaching.com/images/logtypes/2.png" alt=":)" title=":)" /></td>')
    TableInsert(log, '[:)]')
  else
    TableInsert(html, '<td><img src="http://www.geocaching.com/images/logtypes/3.png" alt=":(" title=":(" /></td>')
    TableInsert(log, '[:(]')
  end
  TableInsert(html, '</tr>')
  TableInsert(log, '\n')
end
TableInsert(html, '</table>')

return { ok = ok, html = TableConcat(html), log = TableConcat(log) }
