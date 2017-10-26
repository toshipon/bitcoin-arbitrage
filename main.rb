require 'dotenv/load'
require 'slack/incoming/webhooks'

require_relative 'lib/coincheck'
require_relative 'lib/zaif'
require_relative 'lib/bitflyer'

$init_assets = 0
$msg = ""

def log msg
  $msg += msg
end

def output
  unless ENV['SLACK_WEBHOOK_URL'].nil?
    slack = Slack::Incoming::Webhooks.new ENV['SLACK_WEBHOOK_URL']
    slack.post $msg
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
      profit = ((askc.ask-bidc.bid) * trade_amount).floor

      unless bidc.has_jpy?(bidc.bid, trade_amount)
        log "  *#{bidc.service} wallet doesn't have #{(bidc.bid*trade_amount).floor}JPY*, profit: #{profit}JPY\n"
        return
      end

      unless askc.has_btc?(trade_amount)
        log "  *#{askc.service} wallet doesn't have #{trade_amount}BTC*, profit: #{profit}JPY\n"
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

      log "<!here> *Profit* #{profit}JPY\n"
    end
  else
    log "*#{bidc.service} => #{askc.service}*: no enough profit #{((askc.ask-bidc.bid) * trade_amount).floor}JPY\n"
  end
end

def run
  trade_amount = ENV['TRADE_AMOUNT'].to_f
  log "Trading amount: #{trade_amount}BTC\n"
  log "Minimum volume: #{ENV['MIN_VOLUME_JPY']}JPY\n"

  log "================\n"

  clients = {
    # :zaif => ZaifWrapper.new(ENV['ZAIF_KEY'], ENV['ZAIF_SECRET'], ENV['MINUTE_TO_EXPIRE'].to_f),
    :bitflyer => BitflyerWrapper.new(ENV['BITFLYER_KEY'], ENV['BITFLYER_SECRET'], ENV['MINUTE_TO_EXPIRE'].to_f),
    :coincheck => CoincheckWrapper.new(ENV['COINCHECK_KEY'], ENV['COINCHECK_SECRET'], ENV['MINUTE_TO_EXPIRE'].to_f),
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
  if $init_assets == 0
    $init_assets = total_assets
  end
  log <<"EOS"
*Total:*
  #{total_btc.floor(6)}BTC, #{total_jpy.floor}JPY
*Assets:* #{total_assets.floor}JPY (#{(total_assets - $init_assets).floor})
EOS

  log "================\n"

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

  threads = []
  clients.each_value do |client|
    threads << Thread.new do
      cnt = client.cancel_expired_orders
      if cnt > 0
        log "*#{client.service}* #{cnt} order(s) canceled\n"
      end
    end
  end
  threads.each { |t| t.join }

  log "================\n"

  output
end

if ENV['RUN_ON_HEROKU'].nil?
  loop do
    begin
      run
    rescue Exception => e
      log e.message
      log e.backtrace
      output
    end
    sleep(1) # 1sec
  end
else
  run
end
