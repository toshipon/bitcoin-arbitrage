require 'ruby_coincheck_client'

class CoincheckWrapper
  def initialize key, secret
    @client = CoincheckClient.new(key, secret)
  end

  def service
    "Coincheck"
  end

  def ticker
    JSON.parse(@client.read_ticker.body)
  end

  def has_btc? trading_amount
    JSON.parse(@client.read_balance.body)['btc'].to_f >= trading_amount
  end

  def has_jpy? rate, trading_amount
    JSON.parse(@client.read_balance.body)['jpy'].to_f >= rate * trading_amount
  end

  def bid
    ticker['bid']
  end

  def ask
    ticker['ask']
  end

  def sell ask, trading_amount
    @client.create_orders(rate: ask, amount: trade_amount, order_type: "sell")
  end

  def buy bid, trading_amount
    @client.create_orders(rate: bid, amount: trading_amount, order_type: "buy")
  end
end
