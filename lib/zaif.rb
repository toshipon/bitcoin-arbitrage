require 'zaif'

class ZaifWrapper
  def initialize key, secret
    @client = Zaif::API.new(:api_key => key, :api_secret => secret)
  end

  def service
    "Zaif"
  end

  def ticker
    @client.get_ticker("btc")
  end

  def has_btc? trading_amount
    @client.get_info['deposit']['btc'] >= trading_amount
  end

  def has_jpy? rate, trading_amount
    @client.get_info['deposit']['jpy'] >= rate * trading_amount
  end

  def sell ask, trading_amount
    @client.create_orders(rate: ask, amount: trade_amount, order_type: "sell")
  end

  def buy bid, trading_amount
    @client.create_orders(rate: bid, amount: trading_amount, order_type: "buy")
  end
end
