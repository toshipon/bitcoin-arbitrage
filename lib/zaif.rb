require 'zaif'

class ZaifWrapper
  @_ticker = nil
  @_balance = nil

  def initialize key, secret
    @client = Zaif::API.new(:api_key => key, :api_secret => secret)
  end

  def service
    "Zaif"
  end

  def ticker
    if @_ticker.nil?
      @_ticker = @client.get_ticker("btc")
    end
    @_ticker
  end

  def has_btc? trading_amount
    balance['btc'] >= trading_amount
  end

  def has_jpy? rate, trading_amount
    balance['jpy'] >= rate * trading_amount
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

  private

  def balance
    if @_balance.nil?
      @_balance = @client.get_info['deposit']
    end
    @_balance
  end
end
