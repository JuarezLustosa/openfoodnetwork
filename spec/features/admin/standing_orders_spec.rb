require 'spec_helper'

feature 'Standing Orders' do
  include AuthenticationWorkflow
  include WebHelper

  context "as an enterprise user", js: true do
    let!(:user) { create_enterprise_user(enterprise_limit: 10) }
    let!(:shop) { create(:distributor_enterprise, owner: user) }
    let!(:customer) { create(:customer, enterprise: shop) }
    let!(:product) { create(:product, supplier: shop) }
    let!(:variant) { create(:variant, product: product, unit_value: '100', price: 12.00, option_values: []) }
    let!(:enterprise_fee) { create(:enterprise_fee, amount: 1.75) }
    let!(:order_cycle) { create(:simple_order_cycle, coordinator: shop, orders_open_at: 2.days.from_now, orders_close_at: 7.days.from_now) }
    let!(:outgoing_exchange) { order_cycle.exchanges.create(sender: shop, receiver: shop, variants: [variant], enterprise_fees: [enterprise_fee]) }
    let!(:schedule) { create(:schedule, order_cycles: [order_cycle]) }
    let!(:payment_method) { create(:payment_method, distributors: [shop]) }
    let!(:shipping_method) { create(:shipping_method, distributors: [shop]) }

    before { quick_login_as user }

    it "I can create a new standing order" do
      visit new_admin_standing_order_path(shop_id: shop.id)

      select2_select customer.email, from: 'customer_id'
      select2_select schedule.name, from: 'schedule_id'
      select2_select payment_method.name, from: 'payment_method_id'
      select2_select shipping_method.name, from: 'shipping_method_id'

      # No date filled out, so error returned
      expect{
        click_button('Save')
        expect(page).to have_content 'Oh no! I was unable to save your changes.'
      }.to_not change(StandingOrder, :count)

      expect(page).to have_content 'Begins at can\'t be blank'
      fill_in 'begins_at', with: Date.today.strftime('%F')

      # Date filled out, so submit should be successful
      expect{
        click_button('Save')
        expect(page).to have_content 'Saved'
      }.to change(StandingOrder, :count).by(1)

      standing_order = StandingOrder.last
      expect(standing_order.customer).to eq customer
      expect(standing_order.schedule).to eq schedule
      expect(standing_order.payment_method).to eq payment_method
      expect(standing_order.shipping_method).to eq shipping_method
    end

    it "I can select a product to the list and get a price estimate" do
      visit new_admin_standing_order_path(shop_id: shop.id)

      select2_select schedule.name, from: 'schedule_id'
      targetted_select2_search product.name, from: '#add_variant_id', dropdown_css: '.select2-drop'
      click_link 'Add'

      expect(page).to have_selector 'table#standing-line-items td.description', text: "#{product.name} - #{variant.full_name}"
      expect(page).to have_selector 'table#standing-line-items td.price', text: "$13.75"
    end
  end
end