require 'spec_helper'

describe TransactionService::PaypalEvents do

  TokenStore = PaypalService::Store::Token
  PaymentStore = PaypalService::Store::PaypalPayment
  TransactionModel = ::Transaction
  PaypalAccountModel = ::PaypalAccount

  # Simulate TransactionService::Transactions.create but without calling to paypal payments API
  def create_test_transaction(opts)
    transaction = TransactionModel.new(
      community_id: opts[:community_id],
      listing_id: opts[:listing_id],
      listing_title: opts[:listing_title],
      listing_author_id: opts[:listing_author_id],
      starter_id: opts[:starter_id],
      unit_price: opts[:unit_price],
      listing_quantity: Maybe(opts)[:listing_quantity].or_else(1),
      payment_gateway: opts[:payment_gateway],
      payment_process: opts[:payment_process],
      commission_from_seller: Maybe(opts[:commission_from_seller]).or_else(0),
      automatic_confirmation_after_days: 14,
      minimum_commission: opts[:minimum_commission])

    conversation = transaction.build_conversation(
      community_id: opts[:community_id],
      listing_id: opts[:listing_id])

    conversation.participations.build(
      person_id: opts[:listing_author_id],
      is_starter: false,
      is_read: false)

    conversation.participations.build(
      person_id: opts[:starter_id],
      is_starter: true,
      is_read: true)

    if opts[:content].present?
      conversation.messages.build({
          content: opts[:content],
          sender_id: opts[:starter_id]})
    end

    transaction.save!
    transaction.reload
  end

  before(:each) do
    @cid = 3
    @payer = FactoryGirl.create(:payer)
    @listing = FactoryGirl.create(:listing,
                                  price: Money.new(45000, "EUR"),
                                  listing_shape_id: 123, # This is not used, but needed because the Entity value is mandatory
                                  transaction_process_id: 123) # This is not used, but needed because the Entity value is mandatory

    @paypal_account = PaypalAccountModel.create(person_id: @listing.author, community_id: @cid, email: "author@sharetribe.com", payer_id: "abcdabcd")

    @transaction_info = {
      payment_process: :preauthorize,
      payment_gateway: :paypal,
      community_id: @cid,
      starter_id: @payer.id,
      listing_id: @listing.id,
      listing_title: @listing.title,
      unit_price: @listing.price,
      listing_author_id: @listing.author_id,
      listing_quantity: 1,
      automatic_confirmation_after_days: 3,
      commission_from_seller: 10,
      minimum_commission: Money.new(20, "EUR")
    }

    @transaction_no_msg = create_test_transaction(@transaction_info)
    MarketplaceService::Transaction::Command.transition_to(@transaction_no_msg, "initiated")
    @conversation_no_msg = @transaction_no_msg.conversation

    @transaction_with_msg = create_test_transaction(@transaction_info.merge(content: "A test message"))
    MarketplaceService::Transaction::Command.transition_to(@transaction_with_msg, "initiated")
    @conversation_with_msg = @transaction_with_msg.conversation

    token_code_no_msg = SecureRandom.uuid
    TokenStore.create({
        community_id: @cid,
        token: token_code_no_msg,
        transaction_id: @transaction_no_msg.id,
        merchant_id: @transaction_no_msg.starter_id,
        receiver_id: @paypal_account.payer_id,
        item_name: @listing.title,
        item_quantity: 1,
        item_price: Money.new(45000, "EUR"),
        express_checkout_url: "htts://test.com/#{token_code_no_msg}"
      })

    token_code_with_msg = SecureRandom.uuid
    TokenStore.create({
        community_id: @cid,
        token: token_code_with_msg,
        transaction_id: @transaction_with_msg.id,
        merchant_id: @transaction_with_msg.starter_id,
        receiver_id: @paypal_account.payer_id,
        item_name: @listing.title,
        item_quantity: 1,
        item_price: Money.new(45000, "EUR"),
        express_checkout_url: "htts://test.com/#{token_code_with_msg}"
      })

    @token_no_msg = TokenStore.get(@cid, token_code_no_msg)
    @token_with_msg = TokenStore.get(@cid, token_code_with_msg)
  end


  context "#request_cancelled" do
    it "removes transaction associated with the cancelled token" do
      TransactionService::PaypalEvents.request_cancelled(:success, @token_no_msg)
      TransactionService::PaypalEvents.request_cancelled(:success, @token_with_msg)

      # Both transactions are deleted
      expect(TransactionModel.count).to eq(0)
      # and so are the conversations
      expect(Conversation.where(id: @conversation_no_msg).first).to be_nil
      expect(Conversation.where(id: @conversation_with_msg).first).to be_nil
    end

    it "calling with token that doesn't match a transaction is a no-op" do
      already_removed = @token_no_msg.merge({transaction_id: 987654321})
      TransactionService::PaypalEvents.request_cancelled(:success, already_removed)

      expect(Transaction.count).to eq(2)
    end
  end

  context "#payment_updated - initiated => authorized" do
    before(:each) do
      @authorized_payment = PaymentStore.create(@cid, @transaction_with_msg.id, {
          payer_id: "sduyfsudf",
          receiver_id: "98ysdf98ysdf",
          merchant_id: "asdfasdf",
          pending_reason: "authorization",
          order_id: SecureRandom.uuid,
          order_date: Time.now,
          order_total: Money.new(22000, "EUR"),
          authorization_id: SecureRandom.uuid,
          authorization_date: Time.now,
          authorization_total: Money.new(22000, "EUR"),
        })
    end

    it "transitions transaction to preauthorized state" do
      TransactionService::PaypalEvents.payment_updated(:success, @authorized_payment)

      tx = MarketplaceService::Transaction::Query.transaction(@transaction_with_msg.id)
      expect(tx[:status]).to eq("preauthorized")
    end

    it "is safe to call for non-existent transaction" do
      no_matching_tx = @authorized_payment.merge({transaction_id: 987654321 })
      TransactionService::PaypalEvents.payment_updated(:success, no_matching_tx)

      tx = MarketplaceService::Transaction::Query.transaction(@transaction_with_msg.id)
      expect(tx[:status]).to eq("initiated")
    end
  end

  context "#payment_updated - initiated => voided" do
    before(:each) do
      PaymentStore.create(@cid, @transaction_no_msg.id, {
          payer_id: "sduyfsudf",
          receiver_id: "98ysdf98ysdf",
          merchant_id: "asdfasdf",
          pending_reason: "authorization",
          order_id: SecureRandom.uuid,
          order_date: Time.now,
          order_total: Money.new(22000, "EUR"),
        })
      @voided_payment_no_msg = PaymentStore.update(community_id: @cid, transaction_id: @transaction_no_msg.id, data: {
          pending_reason: :none,
          payment_status: :voided
        })

      PaymentStore.create(@cid, @transaction_with_msg.id, {
          payer_id: "sduyfsudf",
          receiver_id: "98ysdf98ysdf",
          merchant_id: "asdfasdf",
          pending_reason: "authorization",
          order_id: SecureRandom.uuid,
          order_date: Time.now,
          order_total: Money.new(22000, "EUR"),
        })
      @voided_payment_with_msg = PaymentStore.update(community_id: @cid, transaction_id: @transaction_with_msg.id, data: {
          pending_reason: :none,
          payment_status: :voided
        })
    end

    it "removes the associated transaction" do
      TransactionService::PaypalEvents.payment_updated(:success, @voided_payment_no_msg)
      TransactionService::PaypalEvents.payment_updated(:success, @voided_payment_with_msg)

      # Both transactions are deleted
      expect(TransactionModel.count).to eq(0)
      # and so are the conversations
      expect(Conversation.where(id: @conversation_no_msg).first).to be_nil
      expect(Conversation.where(id: @conversation_with_msg).first).to be_nil
    end

    it "is safe to call for non-existent transaction" do
      no_matching_tx = @voided_payment_with_msg.merge({transaction_id: 987654321 })
      TransactionService::PaypalEvents.payment_updated(:success, no_matching_tx)

      expect(Transaction.count).to eq(2)
    end
  end

  context "#update_transaction_details" do
    before(:each) do
      @order_details = {
        status: "Confirmed",
        city: "city",
        country: "country",
        country_code: "CC",
        name: "name",
        phone: "123456",
        postal_code: "WX1GQ",
        state_or_province: "state",
        street1: "street1",
        street2: "street2"
      }

    end

    it "saves address details" do
      TransactionService::PaypalEvents.update_transaction_details(:success,
        @order_details.merge(transaction_id: @transaction_with_msg.id, community_id: @cid))

      expect(
        EntityUtils.model_to_hash(Transaction.find(@transaction_with_msg.id).shipping_address)
      ).to include(@order_details)
    end

    it "doesn't record shipping address with no fields" do
      TransactionService::PaypalEvents.update_transaction_details(:success,
        {}.merge(transaction_id: @transaction_with_msg.id, community_id: @cid))

      expect(Transaction.find(@transaction_with_msg.id).shipping_address).to be nil
    end

    it "doesn't record shipping address with only status field" do
      TransactionService::PaypalEvents.update_transaction_details(:success,
        {status: "None"}.merge(transaction_id: @transaction_with_msg.id, community_id: @cid))

      expect(Transaction.find(@transaction_with_msg.id).shipping_address).to be nil
    end
  end

  context "#payment_updated - preauthorized => voided" do
    before(:each) do
      PaymentStore.create(@cid, @transaction_with_msg.id, {
          payer_id: "sduyfsudf",
          receiver_id: "98ysdf98ysdf",
          merchant_id: "asdfasdf",
          pending_reason: "authorization",
          order_id: SecureRandom.uuid,
          order_date: Time.now,
          order_total: Money.new(22000, "EUR"),
        })

      @authorized_payment = PaymentStore.update(community_id: @cid, transaction_id: @transaction_with_msg.id, data: {
          payment_status: "pending",
          pending_reason: "authorization",
          authorization_id: "12345678",
          authorization_date: Time.now,
          authorization_total: Money.new(22000, "EUR")
        })

      TransactionService::PaypalEvents.payment_updated(:success, @authorized_payment)

      @voided_payment_with_msg = PaymentStore.update(community_id: @cid, transaction_id: @transaction_with_msg.id, data: {
          pending_reason: :none,
          payment_status: :voided
        })
    end

    it "on error transitions the associated transaction to errored" do
      TransactionService::PaypalEvents.payment_updated(:error, @voided_payment_with_msg)
      expect(TransactionModel.where(id: @transaction_with_msg.id).pluck(:current_state).first).to eq "errored"
    end
  end

  context "#payment_preauthorized -> expired" do
    before(:each) do
      PaymentStore.create(@cid, @transaction_with_msg.id, {
          payer_id: "sduyfsudf",
          receiver_id: "98ysdf98ysdf",
          merchant_id: "asdfasdf",
          pending_reason: "authorization",
          order_id: SecureRandom.uuid,
          order_date: Time.now,
          order_total: Money.new(22000, "EUR"),
        })

      @authorized_payment = PaymentStore.update(community_id: @cid, transaction_id: @transaction_with_msg.id, data: {
          payment_status: "pending",
          pending_reason: "authorization",
          authorization_id: "12345678",
          authorization_date: Time.now,
          authorization_total: Money.new(22000, "EUR")
        })

      TransactionService::PaypalEvents.payment_updated(:success, @authorized_payment)

      @expired_payment = PaymentStore.update(community_id: @cid, transaction_id: @transaction_with_msg.id, data: {
          payment_status: "expired",
          authorization_id: "12345678"
        })

    end

    it "transitions associated transaction to rejected on expiration" do
      TransactionService::PaypalEvents.payment_updated(:success, @expired_payment)

       expect(TransactionModel.where(id: @transaction_with_msg.id).pluck(:current_state).first).to eq "rejected"
      expect(TransactionTransition.where(transaction_id: @transaction_with_msg.id).pluck(:metadata)).to include({ "paypal_payment_status" => "expired" })
    end
  end

  context "#payment_updated preauthorized -> denied" do
    before(:each) do
      PaymentStore.create(@cid, @transaction_with_msg.id, {
          payer_id: "sduyfsudf",
          receiver_id: "98ysdf98ysdf",
          merchant_id: "asdfasdf",
          pending_reason: "authorization",
          order_id: SecureRandom.uuid,
          order_date: Time.now,
          order_total: Money.new(22000, "EUR"),
        })

      @authorized_payment = PaymentStore.update(community_id: @cid, transaction_id: @transaction_with_msg.id, data: {
          payment_status: "pending",
          pending_reason: "authorization",
          authorization_id: "12345678",
          authorization_date: Time.now,
          authorization_total: Money.new(22000, "EUR")
        })

      TransactionService::PaypalEvents.payment_updated(:success, @authorized_payment)

      @pending_ext_payment = PaymentStore.update(community_id: @cid, transaction_id: @transaction_with_msg.id, data: {
          payment_status: "pending",
          pending_reason: "multicurrency",
          authorization_id: "12345678"
        })

      TransactionService::PaypalEvents.payment_updated(:success, @pending_ext_payment)

      @denied_payment_with_msg = PaymentStore.update(community_id: @cid, transaction_id: @transaction_with_msg.id, data: {
          pending_reason: :none,
          payment_status: :denied
      })
    end

    it "on payment deny transitions the associated transaction to rejected" do
      TransactionService::PaypalEvents.payment_updated(:success, @denied_payment_with_msg)
      expect(TransactionModel.where(id: @transaction_with_msg.id).pluck(:current_state).first).to eq "rejected"
      expect(TransactionTransition.where(transaction_id: @transaction_with_msg.id).pluck(:metadata)).to include({ "paypal_payment_status" => "denied" })
    end
  end
end
