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

  def get_balance_btc
    balance['btc']
  end

  def has_btc? trading_amount
    get_balance_btc >= trading_amount
  end

  def get_balance_jpy
    balance['jpy']
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

  def pending_orders
    resp = @client.get_active_orders(:currency_pair => 'btc_jpy')
    if resp['active_orders']
      resp['active_orders']
    else
      []
    end
  end

  private

  def balance
    if @_balance.nil?
      @_balance = @client.get_info['deposit']
    end
    @_balance
  end
end
