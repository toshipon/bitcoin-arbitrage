require "date"
require 'bitflyer'

class BitflyerWrapper
  @_ticker = nil
  @_balance = nil

  def initialize key, secret, minute_to_expire
    @private_client = Bitflyer.http_private_client(key, secret)
    @public_client = Bitflyer.http_public_client
    @minute_to_expire = minute_to_expire
  end

  def service
    "Bitflyer"
  end

  def ticker
    if @_ticker.nil?
      @_ticker = @public_client.ticker('BTC_JPY')
    end
    @_ticker
  end

  def get_balance_btc
    balance.each do |v|
      if v['currency_code'] == 'BTC'
        return v['available']
      end
    end
    0
  end

  def has_btc? trading_amount
    get_balance_btc >= trading_amount
  end

  def get_balance_jpy
    balance.each do |v|
      if v['currency_code'] == 'JPY'
        return v['available']
      end
    end
    0
  end

  def has_jpy? rate, trading_amount
    get_balance_jpy >= rate * trading_amount
  end

  def bid
    ticker['best_bid']
  end

  def ask
    ticker['best_ask']
  end

  def average_btc
    (bid + ask)/2
  end

  def sell ask, trading_amount
    @private_client.send_child_order(
      product_code: 'BTC_JPY',
      child_order_type: 'LIMIT',
      side: 'SELL',
      price: ask,
      size: trading_amount,
      minute_to_expire: @minute_to_expire
    )
  end

  def buy bid, trading_amount
    @private_client.send_child_order(
      product_code: 'BTC_JPY',
      child_order_type: 'LIMIT',
      side: 'BUY',
      price: bid,
      size: trading_amount,
      minute_to_expire: @minute_to_expire
    )
  end

  def pending_orders
    resp = @private_client.child_orders(
      product_code: 'BTC_JPY',
      child_order_state: 'ACTIVE'
    )
    if resp.kind_of?(Array)
      resp
    else
      []
    end
  end

  def cancel_expired_orders
    count = 0
    pending_orders.each do |order|
      d = DateTime.parse(order['child_order_date'])
      if ((DateTime.now - d) * 24 * 60).to_i >= @minute_to_expire
        if cancel_order order['child_order_id']
          count += 1
        end
      end
    end
    count
  end

  def cancel_order id
    @private_client.cancel_child_order(product_code: 'BTC_JPY', child_order_id: id)
  end

  private

  def balance
    if @_balance.nil?
      @_balance = @private_client.balance
    end
    @_balance
  end
end
