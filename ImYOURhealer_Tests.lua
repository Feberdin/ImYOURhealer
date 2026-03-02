--[[
ImYOURhealer_Tests

Purpose:
- Lightweight unit tests for core helper functions.
- Intended to run in-game via /imyh selftest (wired in main file).

Input/Output:
- Input: exposed helper API from ImYOURhealer.lua.
- Output: Chat result indicating pass/fail.

Invariant:
- This file must never break addon startup if API export is unavailable.

Debug tip:
- If tests fail, run /imyh debug on and repeat /imyh selftest.
]]

if type(_G.ImYOURhealerTestAPI) ~= "table" then
    return
end

local api = _G.ImYOURhealerTestAPI

local function assertEquals(actual, expected, label)
    if actual ~= expected then
        return false, string.format("%s expected '%s' got '%s'", label, tostring(expected), tostring(actual))
    end
    return true, ""
end

local function runTests()
    local ok, err

    ok, err = assertEquals(api.normalizeName("Hauptmann Skarloc"), "hauptmannskarloc", "normalizeName")
    if not ok then
        return false, err
    end

    ok, err = assertEquals(api.buildRunKey("The Steamvault", 2, 77), "The Steamvault#2#77", "buildRunKey")
    if not ok then
        return false, err
    end

    ok, err = assertEquals(api.isHeroicDifficulty(2, ""), true, "isHeroicDifficulty by id")
    if not ok then
        return false, err
    end

    ok, err = assertEquals(api.isHeroicDifficulty(nil, "Heroisch"), true, "isHeroicDifficulty by string")
    if not ok then
        return false, err
    end

    return true, ""
end

local passed, reason = runTests()
_G.ImYOURhealerTests = {
    passed = passed,
    reason = reason,
}
