require 'bitflyer'

class BitflyerWrapper
  def initialize key, secret
    @private_client = Bitflyer.http_private_client(key, secret)
    @public_client = Bitflyer.http_public_client
  end

  def service
    "Bitflyer"
  end

  def ticker
    @public_client.ticker('BTC_JPY')
  end

  def has_btc? trading_amount
    @private_client.balance.each do |v|
      if v['currency_code'] == 'BTC'
        return v['amount'] >= trading_amount
      end
    end
    false
  end

  def has_jpy? rate, trading_amount
    @private_client.balance.each do |v|
      if v['currency_code'] == 'JPY'
        return v['amount'] >= rate * trading_amount
      end
    end
    false
  end

  def bid
    ticker['best_bid']
  end

  def ask
    ticker['best_ask']
  end

  def sell ask, trading_amount
    @private_client.send_child_order(
      product_code: 'BTC_JPY',
      child_order_type: 'LIMIT',
      side: 'SELL',
      price: ask,
      size: trading_amount
    )
  end

  def buy bid, trading_amount
    @private_client.send_child_order(
      product_code: 'BTC_JPY',
      child_order_type: 'LIMIT',
      side: 'BUY',
      price: bid,
      size: trading_amount
    )
  end
end
