require 'bitflyer'

class BitflyerWrapper
  @@minute_to_expire = 1 # Cancel order in 1min
  @_ticker = nil
  @_balance = nil

  def initialize key, secret
    @private_client = Bitflyer.http_private_client(key, secret)
    @public_client = Bitflyer.http_public_client
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
        return v['amount']
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
        return v['amount']
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
      minute_to_expire: @@minute_to_expire
    )
  end

  def buy bid, trading_amount
    @private_client.send_child_order(
      product_code: 'BTC_JPY',
      child_order_type: 'LIMIT',
      side: 'BUY',
      price: bid,
      size: trading_amount,
      minute_to_expire: @@minute_to_expire
    )
  end

  private

  def balance
    if @_balance.nil?
      @_balance = @private_client.balance
    end
    @_balance
  end
end
