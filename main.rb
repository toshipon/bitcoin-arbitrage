require 'dotenv/load'
require 'slack/incoming/webhooks'

require_relative 'lib/coincheck'
require_relative 'lib/zaif'
require_relative 'lib/bitflyer'

$msg = ""
def log msg
  $msg += "#{msg}\n"
end

def output
  unless ENV['SLACK_WEBHOOK_URL'].nil?
    Thread.new do
      slack = Slack::Incoming::Webhooks.new ENV['SLACK_WEBHOOK_URL']
      slack.post $msg
    end
  end
  puts $msg
  $msg = ""
end

def generate_stat c
  result = <<"EOS"
*#{c.service}*
   bid: #{c.bid}
   ask: #{c.ask}
   balance: #{c.get_balance_btc}BTC #{c.get_balance_jpy}JPY
   pending: #{c.pending_orders.size}
EOS
  result
end

def profit? trade_amount, bid, ask
  margin = ask - bid
  (trade_amount * margin).floor - ENV['MIN_VOLUME_JPY'].to_f >= 0
end

def trading bidc, askc, trade_amount
  if profit?(trade_amount, bidc.bid, askc.ask)
    log <<"EOS"
*#{bidc.service} => #{askc.service}*
Buying  #{trade_amount}BTC #{(bidc.bid*trade_amount).floor}JPY in #{bidc.service}
Selling #{trade_amount}BTC #{(askc.ask*trade_amount).floor}JPY in #{askc.service}
EOS

    if ENV['RUN_TRADING'] == 'on'
      unless bidc.has_jpy?(bidc.bid, trade_amount)
        log "*#{bidc.service} wallet doesn't have #{(bidc.bid*trade_amount).floor}JPY*"
        return
      end

      unless askc.has_btc?(trade_amount)
        log "*#{askc.service} wallet doesn't have #{trade_amount}BTC*"
        return
      end

      threads = []
      threads << Thread.new do
        bidc.buy(bidc.bid, trade_amount)
      end
      threads << Thread.new do
        askc.sell(askc.ask, trade_amount)
      end
      threads.each { |t| t.join }

      log "<!here> *Profit* #{((askc.ask-bidc.bid) * trade_amount).floor}JPY"
    end
  else
    log "*#{bidc.service} => #{askc.service}*: no enough profit #{((askc.ask-bidc.bid) * trade_amount).floor}JPY"
  end
end

def run
  trade_amount = ENV['TRADE_AMOUNT'].to_f
  log "Trading amount: #{trade_amount}BTC"
  log "Minimum volume: #{ENV['MIN_VOLUME_JPY']}JPY"

  log "================"

  clients = {
    # :zaif => ZaifWrapper.new(ENV['ZAIF_KEY'], ENV['ZAIF_SECRET']),
    :bitflyer => BitflyerWrapper.new(ENV['BITFLYER_KEY'], ENV['BITFLYER_SECRET']),
    :coincheck => CoincheckWrapper.new(ENV['COINCHECK_KEY'], ENV['COINCHECK_SECRET']),
  }

  threads = []
  clients.each_value do |client|
    threads << Thread.new do
      log generate_stat client
    end
  end
  threads.each { |t| t.join }

  total_btc = 0
  total_jpy = 0
  clients.each_value do |client|
    total_btc += client.get_balance_btc
    total_jpy += client.get_balance_jpy
  end
  total_assets = total_jpy + total_btc * clients[:coincheck].last
  log "Total: #{total_btc}BTC,  #{total_jpy}JPY, Assets: #{total_assets}JPY"

  log "================"

  threads = []
  clients.each do |bidk, bidc|
    clients.each do |askk, askc|
      if bidk != askk
        threads << Thread.new do
          trading bidc, askc, trade_amount
        end
      end
    end
  end
  threads.each { |t| t.join }

  log "================"
  output
end

if ENV['RUN_ON_HEROKU'].nil?
  loop do
    begin
      run
    rescue Exception => e
      puts e.message
    end
    sleep(3*1) # 5mins
  end
else
  run
end
