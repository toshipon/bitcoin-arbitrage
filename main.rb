require 'dotenv/load'
require 'zaif'
require 'ruby_coincheck_client'
require 'slack/incoming/webhooks'

# p zaif_client.get_info

def output title, r
  result = <<"EOS"
*#{title}*
   bid: #{r['bid']}
   ask: #{r['ask']}
EOS
  result
end

def profit? trade_amount, bid, ask
  margin = ask - bid
  (trade_amount * margin).floor > 0
end

def run
  trade_amount = ENV['TRADE_AMOUNT'].to_f
  zaif_client = Zaif::API.new(:api_key => ENV['ZAIF_KEY'], :api_secret => ENV['ZAIF_SECRET'])
  coincheck_client = CoincheckClient.new(ENV['COINCHECK_KEY'], ENV['COINCHECK_SECRET'])
  slack = Slack::Incoming::Webhooks.new ENV['SLACK_WEBHOOK_URL']

  slack.post "trading amount: #{trade_amount}BTC"

  zr = zaif_client.get_ticker("btc")
  slack.post output "Zaif BTC/JPY", zr

  cr = JSON.parse(coincheck_client.read_ticker.body)
  slack.post output "Coincheck BTC/JPY", cr

  if profit? trade_amount, zr['bid'], cr['ask']
    slack.post "Buying  #{trade_amount}BTC #{(zr['bid']*trade_amount).floor}JPY in Zaif"
    # zaif_client.bid("btc", zr['bid'], trade_amount)
    slack.post "Selling #{trade_amount}BTC #{(cr['ask']*trade_amount).floor}JPY in Coincheck"
    # coincheck_client.create_orders(rate: cr['ask'], amount: trade_amount, order_type: "sell")
    slack.post "Profit #{((cr['ask']-zr['bid']) * margin).floor}JPY"
  end

  if profit? trade_amount, cr['bid'], zr['ask']
    slack.post "Buying  #{trade_amount}BTC #{(cr['bid']*trade_amount).floor}JPY in Coincheck"
    # coincheck_client.create_orders(rate: zr['bid'], amount: trade_amount, order_type: "buy")
    slack.post "Selling #{trade_amount}BTC #{(zr['ask']*trade_amount).floor}JPY in Zaif"
    # zaif_client.ask("btc", zr['ask'], trade_amount)
    slack.post "@here *Profit* #{((zr['ask']-cr['bid']) * trade_amount).floor}JPY"
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
