-- Inofficial BERGFÜRST Extension (de.bergfuerst.com) for MoneyMoney
-- Fetches balances from BERGFÜRST Website and returns them as securities
--
-- Copyright (c) 2019 Nico Lindemann
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

WebBanking{version     = 1.00,
           url         = "https://de.bergfuerst.com",
           services    = {"BERGFÜRST Account"},
           description = "Fetches balances from BERGFÜRST Website and returns them as securities"}

function SupportsBank (protocol, bankCode)
  return protocol == ProtocolWebBanking and bankCode == "BERGFÜRST Account"
end

function InitializeSession (protocol, bankCode, username, username2, password, username3)
  -- Login.
  connection = Connection()

  local headers = {}
  headers["X-Requested-With"] = "XMLHttpRequest"
  
  html = HTML(connection:get("https://de.bergfuerst.com/login"))
  html:xpath("(//input[@name='_username'])[1]"):attr("value", username)
  html:xpath("(//input[@name='_password'])[1]"):attr("value", password)
  
  local method, url, postContent, postContentType = html:xpath("(//input[@value='Login'])[1]"):click()
  
  connection:request(method, url, postContent, postContentType, headers)
end

function ListAccounts (knownAccounts)
  -- Return array of accounts.
  local account = {
    name = "Bergfürst",
    accountNumber = "Main",
    currency = "EUR",
    portfolio = true,
    type = "AccountTypePortfolio"
  }
  return {account}
end

function RefreshAccount (account, since)
  html = HTML(connection:get("https://de.bergfuerst.com/meine-investments"))

  local totalInterestAmount = tonumber((html:xpath("//*[@id='top']/div[2]/div/div[1]/div[3]/p[2]/strong"):get(1):text():sub(1, -5):gsub(",", ".")))
  local balance = tonumber((html:xpath("//*[@id='top']/div[2]/div/div[1]/div[2]/p[2]/strong"):get(1):text():sub(1, -5):gsub("%.", ""):gsub(",", ".")))

  local securities = {}
  local investments = html:xpath("//table[contains(@class, 'table-overview')]/tbody/tr[contains(@class, 'cursor-pointer')]")
  
  investments:each(function (index, element)
    local amount = tonumber((element:xpath("./td[2]/text()[1]"):text():sub(1, -5):gsub(",", ".")))
    local longInterestString = trim((html:xpath("//*[@id='" ..  element:attr("href"):sub(2) .. "']//div[contains(@class, 'table-details-container')]"):get(1):text():sub(-700)))
    local euroSignLocation = longInterestString:find("€")
    
    if (euroSignLocation == 6) then
      longInterestString = trim((longInterestString:sub(1, euroSignLocation)))
      longInterestString = longInterestString:sub(1, longInterestString:len() - 2)
      interestAmount = tonumber((longInterestString:gsub(",", ".")))
    else
      local shortInterestString = trim((html:xpath("//*[@id='" ..  element:attr("href"):sub(2) .. "']//div[contains(@class, 'table-details-container')]"):get(1):text():sub(-10)))
      interestAmount = tonumber((trim(shortInterestString:sub(1, shortInterestString:len() - 4)):gsub(",", ".")))
    end

    securities[index] = {}
    securities[index].userdata = {}

    table.insert(securities[index].userdata, { key = "Laufzeit", value = (element:xpath("./td[4]/text()[1]"):text()) })
    table.insert(securities[index].userdata, { key = "Zinssatz (p.a.)", value = (element:xpath("./td[3]/text()[1]"):text()) })    
    table.insert(securities[index].userdata, { key = "Zinsertrag", value = MM.localizeAmount(interestAmount, "EUR") })

    securities[index].name = element:xpath("./td[1]/strong"):get(1):text()
    securities[index].market = "BERGFÜRST"
    securities[index].currency = "EUR"

    if (amount ~= nil and interestAmount ~= nil) then
      securities[index].amount = (amount + interestAmount)
    elseif (amount ~= nil) then
      securities[index].amount = amount
    else
      securities[index].amount = 0
    end
  end)

  local fullBalance = balance + totalInterestAmount

  return {balance=fullBalance, securities=securities}
end

function EndSession ()
  -- Logout.
end

function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end