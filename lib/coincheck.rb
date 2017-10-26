require "date"
require 'ruby_coincheck_client'

class CoincheckWrapper
  @_ticker = nil
  @_balance = nil

  def initialize key, secret, minute_to_expire
    @client = CoincheckClient.new(key, secret)
    @minute_to_expire = minute_to_expire
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

  def last
    ticker['last']
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
    resp = JSON.parse(@client.read_orders.body)
    if resp['success']
      resp['orders']
    else
      []
    end
  end

  def cancel_expired_orders
    count = 0
    pending_orders.each do |order|
      d = DateTime.parse(order['created_at'])
      if ((DateTime.now - d) * 24 * 60).to_i >= @minute_to_expire
        if cancel_order order['id']
          count += 1
        end
      end
    end
    count
  end

  def cancel_order id
    result = JSON.parse(@client.delete_orders(id: id).body)
    result['success']
  end

  private

  def balance
    if @_balance.nil?
      @_balance = JSON.parse(@client.read_balance.body)
    end
    @_balance
  end
end
