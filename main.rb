require 'dotenv/load'
require 'zaif'
require 'ruby_coincheck_client'
require 'slack/incoming/webhooks'

# zaif_client.bid("btc", 30760, 0.0001)
# zaif_client.ask("btc", 30320, 0.0001)
# p zaif_client.get_info

def output r
  p "   bid: #{r['bid']}"
  p "   ask: #{r['ask']}"
  # p "   high: #{r['high']}"
  # p "   low: #{r['low']}"
end

def profit? trade_amount, bid, ask, fee
  margin = bid * (1 - fee) - ask
  (trade_amount * margin).floor > 0
end

def run
  trade_amount = ENV['TRADE_AMOUNT'].to_f
  p "trading amount: #{trade_amount}"
  zaif_client = Zaif::API.new(:api_key => ENV['ZAIF_KEY'], :api_secret => ENV['ZAIF_SECRET'])
  coincheck_client = CoincheckClient.new(ENV['COINCHECK_KEY'], ENV['COINCHECK_SECRET'])
  slack = Slack::Incoming::Webhooks.new ENV['SLACK_WEBHOOK_URL']

  zr = zaif_client.get_ticker("btc")
  p "Zaif BTC/JPY"
  output zr

  cr = JSON.parse(coincheck_client.read_ticker.body)
  p "Coincheck BTC/JPY"
  output cr

  p "========================"

  if profit? trade_amount, zr['bid'], cr['ask'], -0.01
    slack.post "Buying  #{trade_amount}BTC #{(zr['bid']*trade_amount).floor(2)}JPY in Zaif"
    # zaif_client.bid("btc", zr['bid'], trade_amount)
    slack.post  "Selling #{trade_amount}BTC #{(cr['ask']*trade_amount).floor(2)}JPY in Coincheck"
    # coincheck_client.create_orders(rate: cr['ask'], amount: trade_amount, order_type: "sell")
  end

  if profit? trade_amount, cr['bid'], zr['ask'], 0
    slack.post  "Buying  #{trade_amount}BTC #{(cr['bid']*trade_amount).floor(2)}JPY in Coincheck"
    # coincheck_client.create_orders(rate: zr['bid'], amount: trade_amount, order_type: "buy")
    slack.post  "Selling #{trade_amount}BTC #{(zr['ask']*trade_amount).floor(2)}JPY in Zaif"
    # zaif_client.ask("btc", zr['ask'], trade_amount)
  end
end

if ENV['RUN_ON_HEROKU'].nil?
  loop do
    run
    sleep(1)
  end
else
  run
end
