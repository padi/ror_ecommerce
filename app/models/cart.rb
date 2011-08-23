class Cart
  include Mongoid::Document
  #field :updated_at, type: DateTime
  include Mongoid::Timestamps::Updated

  field :user_id, type: Integer
  field :customer_id, type: Integer
  embeds_many :cart_items

  #before_save :set_updated_at
  #validates_presence_of :updated_at

  def user
    customer_id ? User.where(['users.id = ?', customer_id]) : nil
  end


  # Adds all the item prices (not including taxes) that are currently in the shopping cart
  #
  # @param [none]
  # @return [Float] This is a float in decimal form and represents the price of all the items in the cart
  def sub_total
    shopping_cart_items.inject(0) {|sum, item| item.total + sum} #.includes(:variant)
  end

  def shopping_cart_items
    cart_items.select{|item| item.shopping_cart_item? }
  end

  def shopping_cart_items=(items)
    items.each {|item| item.item_type_id = ItemType::SHOPPING_CART_ID}
    #item.active = true
    cart_items=(items)
  end

  def saved_cart_items
    cart_items.select{|item| item.save_for_later_item? }
  end

  def saved_cart_items=(items)
    items.each {|item| item.item_type_id = ItemType::SAVE_FOR_LATER_ID}
    cart_items=(item)
  end


  def wish_list_items
    cart_items.select{|item| item.wish_list_item? }
  end

  def wish_list_items=(items)
    items.each {|item| item.item_type_id = ItemType::WISH_LIST_ID}
    cart_items=(item)
  end

  # Call this method when you are checking out with the current cart items
  # => these will now be order.order_items
  # => the order can only add items if it is 'in_progress'
  #
  # @param [Order] order to insert the shopping cart variants into
  # @return [order]  return order because teh order returned has a diffent quantity
  def add_items_to_checkout(order)
    if order.in_progress?
      #items = Hash[shopping_cart_items.map { |item| [item.variant_id, {item.id => item.quantity}] }]
      items = shopping_cart_items.inject({}) do |h, item|
        if h[item.variant_id]
          h[item.variant_id] = h[item.variant_id] + item.quantity
        else
          h[item.variant_id] = item.quantity
        end
        h
      end
      order = items_to_add_or_destroy(items, order)
    end
    order
  end



  def add_variant(variant_id, customer, qty = 1, cart_item_type_id = ItemType::SHOPPING_CART_ID)
    items = shopping_cart_items.select{|i| i.variant_id == variant_id } #.find_all_by_variant_id(variant_id)
    variant = Variant.find(variant_id)
    unless variant.sold_out?
      if items.size < 1
        cart_item = self.cart_items.create(variant_id: variant_id,
                                      #user_id: customer.id,
                                      item_type_id: cart_item_type_id,
                                      quantity: qty#,#:price      => variant.price
                                      )
      else
        cart_item = items.first
        update_shopping_cart(cart_item,customer, qty)
      end
    else
      if items.size < 1
          self.cart_items.create(variant_id: variant_id,
                                        #user_id:      customer.id,
                                        item_type_id: ItemType::SAVE_FOR_LATER_ID,
                                        quantity:     qty
                                        )
      else
        self.cart_items.where(:variant_id => variant_id).update_all(:item_type_id => ItemType::SAVE_FOR_LATER_ID)
      end
    end
    cart_item
  end

  def remove_variant(variant_id)
    citems = self.cart_items.each {|ci| ci.inactivate! if variant_id.to_i == ci.variant_id }
    return citems
  end
  # Call this method when you want to associate the cart with a user
  #
  # @param [User]
  def save_user(u)  # u is user object or nil
    if u && self.user_id != u.id
      self.user_id = u.id
      self.save
    end
  end


  # Call this method when you want to mark the items in the order as purchased
  #   The CartItem will not delete.  Instead the item_type changes to purchased
  #
  # @param [Order]
  def mark_items_purchased(order)
    #self.cart_items.each {|item| item.mark_shopping_item_purchased! } if !order.variant_ids.empty?
    #self.cart_items.update_all(:item_type_id => ItemType::PURCHASED_ID)
   # self.shopping_cart_items.each{|i| i[:item_type_id] = ItemType::PURCHASED_ID }#(:item_type_id => ItemType::PURCHASED_ID)
    self.shopping_cart_items.each do |i|
      i.mark_shopping_item_purchased! if order.variant_ids.include?(i.variant_id)
    end #(:item_type_id => ItemType::PURCHASED_ID)

    self.save
  end

  private

  #def set_updated_at
  #  updated_at = Time.now
  #end

  def update_shopping_cart(cart_item,customer, qty = 1)
    if customer
      self.shopping_cart_items.detect{|i| i == cart_item}.update_attributes(quantity: (cart_item.quantity + qty), user_id: customer.id)
    else
      self.shopping_cart_items.detect{|i| i == cart_item}.update_attributes(quantity: (cart_item.quantity + qty))
    end
  end

  def items_to_add_or_destroy(items_in_cart, order)
    #destroy_any_order_item_that_was_removed_from_cart
    order.order_items.delete_if {|order_item| !items_in_cart.keys.any?{|variant_id| variant_id == order_item.variant_id } }
   # order.order_items.delete_all #destroy(order_item.id)
    items = order.order_items.inject({}) {|h, item| h[item.variant_id].nil? ? h[item.variant_id] = [item.id]  : h[item.variant_id] << item.id; h}
    items_in_cart.each_pair do |variant_id, qty_in_cart|
      variant = Variant.find(variant_id)
      if items[variant_id].nil?
        order.add_items( variant , qty_in_cart)
      elsif qty_in_cart - items[variant_id].size > 0
        order.add_items( variant , qty_in_cart - items[variant_id].size)
      elsif qty_in_cart - items[variant_id].size < 0
        order.remove_items( variant , qty_in_cart )
      end
    end
    order
  end
end

=begin
class Cart < ActiveRecord::Base
  belongs_to  :user
  has_many    :cart_items
  has_many    :shopping_cart_items,       :conditions => ['cart_items.active = ? AND
                                                          cart_items.item_type_id = ?', true, ItemType::SHOPPING_CART_ID],
                                          :class_name => 'CartItem'


  has_many    :saved_cart_items,          :conditions => ['cart_items.active = ? AND
                                                          cart_items.item_type_id = ?', true, ItemType::SAVE_FOR_LATER_ID],
                                          :class_name => 'CartItem'
  has_many    :wish_list_items,           :conditions => ['cart_items.active = ? AND
                                                          cart_items.item_type_id = ?', true, ItemType::WISH_LIST_ID],
                                          :class_name => 'CartItem'

  has_many    :purchased_items,           :conditions => ['cart_items.active = ? AND
                                                          cart_items.item_type_id = ?', true, ItemType::PURCHASED_ID],
                                          :class_name => 'CartItem'

  has_many    :deleted_cart_items,        :conditions => ['cart_items.active = ?', false], :class_name => 'CartItem'

  accepts_nested_attributes_for :shopping_cart_items

  # Adds all the item prices (not including taxes) that are currently in the shopping cart
  #
  # @param [none]
  # @return [Float] This is a float in decimal form and represents the price of all the items in the cart
  def sub_total
    shopping_cart_items.inject(0) {|sum, item| item.total + sum} #.includes(:variant)
  end

  # Call this method when you are checking out with the current cart items
  # => these will now be order.order_items
  # => the order can only add items if it is 'in_progress'
  #
  # @param [Order] order to insert the shopping cart variants into
  # @return [order]  return order because teh order returned has a diffent quantity
  def add_items_to_checkout(order)
    if order.in_progress?
      items = shopping_cart_items.inject({}) do |h, item|
        h[item.variant_id] = item.quantity
        h
      end
      order = items_to_add_or_destroy(items, order)
    end
    order
  end

  # Call this method when you want to add an item to the shopping cart
  #
  # @param [Integer, #read] variant id to add to the cart
  # @param [User, #read] user that is adding something to the cart
  # @param [Integer, #optional] ItemType id that is being added to the cart
  # @return [CartItem] return the cart item that is added to the cart
  def add_variant(variant_id, customer, qty = 1, cart_item_type_id = ItemType::SHOPPING_CART_ID)
    items = shopping_cart_items.find_all_by_variant_id(variant_id)
    variant = Variant.find(variant_id)
    unless variant.sold_out?
      if items.size < 1
        cart_item = shopping_cart_items.create(:variant_id   => variant_id,
                                      :user         => customer,
                                      :item_type_id => cart_item_type_id,
                                      :quantity     => qty#,#:price      => variant.price
                                      )
      else
        cart_item = items.first
        update_shopping_cart(cart_item,customer, qty)
      end
    else
      cart_item = saved_cart_items.create(:variant_id   => variant_id,
                                    :user         => customer,
                                    :item_type_id => ItemType::SAVE_FOR_LATER_ID,
                                    :quantity     => qty#,#:price      => variant.price
                                    ) if items.size < 1

    end
    cart_item
  end

  # Call this method when you want to remove an item from the shopping cart
  #   The CartItem will not delete.  Instead it is just inactivated
  #
  # @param [Integer, #read] variant id to add to the cart
  # @return [CartItem] return the cart item that is added to the cart
  def remove_variant(variant_id)
    citems = self.cart_items.each {|ci| ci.inactivate! if variant_id.to_i == ci.variant_id }
    return citems
  end

  # Call this method when you want to associate the cart with a user
  #
  # @param [User]
  def save_user(u)  # u is user object or nil
    if u && self.user_id != u.id
      self.user_id = u.id
      self.save
    end
  end

  # Call this method when you want to mark the items in the order as purchased
  #   The CartItem will not delete.  Instead the item_type changes to purchased
  #
  # @param [Order]
  def mark_items_purchased(order)
    CartItem.update_all("item_type_id = #{ItemType::PURCHASED_ID}",
                        "id IN (#{(self.cart_item_ids + self.shopping_cart_item_ids).uniq.join(',')}) AND variant_id IN (#{order.variant_ids.join(',')})") if !order.variant_ids.empty?
  end

  private
  def update_shopping_cart(cart_item,customer, qty = 1)
    if customer
      self.shopping_cart_items.find(cart_item.id).update_attributes(:quantity => (cart_item.quantity + qty), :user_id => customer.id)
    else
      self.shopping_cart_items.find(cart_item.id).update_attributes(:quantity => (cart_item.quantity + qty))
    end
  end

  def items_to_add_or_destroy(items_in_cart, order)
    #destroy_any_order_item_that_was_removed_from_cart
    order.order_items.delete_if {|order_item| !items_in_cart.keys.any?{|variant_id| variant_id == order_item.variant_id } }
   # order.order_items.delete_all #destroy(order_item.id)
    items = order.order_items.inject({}) {|h, item| h[item.variant_id].nil? ? h[item.variant_id] = [item.id]  : h[item.variant_id] << item.id; h}
    items_in_cart.each_pair do |variant_id, qty_in_cart|
      variant = Variant.find(variant_id)
      if items[variant_id].nil?
        order.add_items( variant , qty_in_cart)
      elsif qty_in_cart - items[variant_id].size > 0
        order.add_items( variant , qty_in_cart - items[variant_id].size)
      elsif qty_in_cart - items[variant_id].size < 0
        order.remove_items( variant , qty_in_cart )
      end
    end
    order
  end
end
=end