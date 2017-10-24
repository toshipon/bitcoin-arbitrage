require 'ruby_coincheck_client'

class CoincheckWrapper
  @_ticker = nil
  @_balance = nil

  def initialize key, secret
    @client = CoincheckClient.new(key, secret)
  end

  def service
    "Coincheck"
  end

  def ticker
    if @_ticker.nil?
      @_ticker = JSON.parse(@client.read_ticker.body)
    end
    @_ticker
  end

  def get_balance_btc
    balance['btc'].to_f
  end

  def has_btc? trading_amount
    get_balance_btc >= trading_amount
  end

  def get_balance_jpy
    balance['jpy'].to_f
  end

  def has_jpy? rate, trading_amount
    get_balance_jpy >= rate * trading_amount
  end

  def bid
    ticker['bid']
  end

  def ask
    ticker['ask']
  end

  def average_btc
    (bid + ask)/2
  end

  def sell ask, trading_amount
    @client.create_orders(rate: ask, amount: trading_amount, order_type: "sell")
  end

  def buy bid, trading_amount
    @client.create_orders(rate: bid, amount: trading_amount, order_type: "buy")
  end

  private

  def balance
    if @_balance.nil?
      @_balance = JSON.parse(@client.read_balance.body)
    end
    @_balance
  end
end
