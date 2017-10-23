require 'dotenv/load'
require 'zaif'
require 'ruby_coincheck_client'
require 'slack/incoming/webhooks'

def output msg
  if ENV['RUN_ON_HEROKU'].nil?
    p msg
  else
    slack = Slack::Incoming::Webhooks.new ENV['SLACK_WEBHOOK_URL']
    slack.post msg
  end
end

def generate_stat title, r
  result = <<"EOS"
*#{title}*
   bid: #{r['bid']}
   ask: #{r['ask']}
EOS
  result
end

def profit? trade_amount, bid, ask
  margin = ask - bid
  (trade_amount * margin).floor - ENV['MIN_VOLUME_JPY'].to_f > 0
end

def has_jpy_in_zaif? c, rate, trading_amount
  c.get_info['deposit']['jpy'] >= rate * trading_amount
end

def has_btc_in_cc? c, trading_amount
  JSON.parse(c.read_balance.body)['btc'].to_f >= trading_amount
end

def has_jpy_in_cc? c, rate, trading_amount
  JSON.parse(c.read_balance.body)['jpy'].to_f >= rate * trading_amount
end

def has_btc_in_zaif? c, trading_amount
  c.get_info['deposit']['btc'] >= trading_amount
end

def run
  trade_amount = ENV['TRADE_AMOUNT'].to_f
  zaif_client = Zaif::API.new(:api_key => ENV['ZAIF_KEY'], :api_secret => ENV['ZAIF_SECRET'])
  coincheck_client = CoincheckClient.new(ENV['COINCHECK_KEY'], ENV['COINCHECK_SECRET'])

  output "Trading amount: #{trade_amount}BTC"
  output "Minimum valume: #{ENV['MIN_VOLUME_JPY']}JPY"

  zr = zaif_client.get_ticker("btc")
  output generate_stat "Zaif BTC/JPY", zr

  cr = JSON.parse(coincheck_client.read_ticker.body)
  output generate_stat "Coincheck BTC/JPY", cr

  if profit?(trade_amount, zr['bid'], cr['ask']) &&
      has_jpy_in_zaif?(zaif_client, zr['bid'], trade_amount) &&
      has_btc_in_cc?(coincheck_client, trade_amount)
    output "Buying  #{trade_amount}BTC #{(zr['bid']*trade_amount).floor}JPY in Zaif"
    # zaif_client.bid("btc", zr['bid'], trade_amount)
    output "Selling #{trade_amount}BTC #{(cr['ask']*trade_amount).floor}JPY in Coincheck"
    # coincheck_client.create_orders(rate: cr['ask'], amount: trade_amount, order_type: "sell")
    output "Profit #{((cr['ask']-zr['bid']) * margin).floor}JPY"
  end

  if profit?(trade_amount, cr['bid'], zr['ask']) &&
      has_jpy_in_cc?(coincheck_client, cr['bid'], trade_amount) &&
      has_btc_in_zaif?(zaif_client, trade_amount)
    output "Buying  #{trade_amount}BTC #{(cr['bid']*trade_amount).floor}JPY in Coincheck"
    # coincheck_client.create_orders(rate: zr['bid'], amount: trade_amount, order_type: "buy")
    output "Selling #{trade_amount}BTC #{(zr['ask']*trade_amount).floor}JPY in Zaif"
    # zaif_client.ask("btc", zr['ask'], trade_amount)
    output "<!here> *Profit* #{((zr['ask']-cr['bid']) * trade_amount).floor}JPY"
  end
end

if ENV['RUN_ON_HEROKU'].nil?
  loop do
    run
    sleep(5)
  end
else
  run
end
