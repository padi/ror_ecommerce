class CartItem
  include Mongoid::Document
  field :item_type_id,  type: Integer#, default: ItemType::SHOPPING_CART_ID
  field :variant_id,    type: Integer
  field :quantity,      type: Integer
  field :active,        type: Boolean, default: true
  #field :updated_at,    type: DateTime

  embeds_many :cart_item_customizations
  embedded_in :cart

  before_save :inactivate_zero_quantity

  validates_presence_of :quantity, :variant_id, :item_type_id

  QUANTITIES = [1,2,3,4,5]

  def mark_shopping_item_purchased!
    self.item_type_id = ItemType::PURCHASED_ID
  end

  #def item_type_id=(type_id)
    #self.item_type_id = (type_id.class.to_s == 'Fixnum') ? type_id : type_id.id
  #end

  def variant=(var)
    self.variant_id = var.id
    var
  end

  def variant
    #variant_id ? Variant.where(['variants.id = ?', variant_id]) : nil
    @variant ||= Variant.find(variant_id) if variant_id
  end

  #def avatar=(avatar)
  #  avatar.update_attributes(:user_id => self.id)
  #end
  # Call this method to soft delete an item in the cart
  #
  # @param [none]
  # @return [Boolean]
  def inactivate!
    self.active = false
    save
  end

  # Call this if you need to know the unit price of an item
  #
  # @param [none]
  # @return [Float] price of the variant in the cart
  def price
    @variant ||= Variant.find(variant_id)
    @variant.price
  end

  # Call this method if you need the price of an item before taxes
  #
  # @param [none]
  # @return [Float] price of the variant in the cart times quantity
  def total
    self.price * self.quantity
  end

  # Call this method to determine if an item is in the shopping cart and active
  #
  # @param [none]
  # @return [Boolean]
  def shopping_cart_item?
    item_type_id == ItemType::SHOPPING_CART_ID && active?
  end

  def save_for_later_item?
    item_type_id == ItemType::SAVE_FOR_LATER_ID && active?
  end

  def wish_list_item?
    item_type_id == ItemType::WISH_LIST_ID && active?
  end

  private

    def inactivate_zero_quantity
     # self.active = false if quantity == 0
    end
end

=begin
class CartItem < ActiveRecord::Base
  belongs_to :item_type
  belongs_to :user
  belongs_to :cart
  belongs_to :variant

  QUANTITIES = [1,2,3,4]

  before_save :inactivate_zero_quantity

  # Call this if you need to know the unit price of an item
  #
  # @param [none]
  # @return [Float] price of the variant in the cart
  def price
    self.variant.price
  end

  # Call this method if you need the price of an item before taxes
  #
  # @param [none]
  # @return [Float] price of the variant in the cart times quantity
  def total
    self.price * self.quantity
  end

  # Call this method to soft delete an item in the cart
  #
  # @param [none]
  # @return [Boolean]
  def inactivate!
    self.update_attributes(:active => false)
  end

  # Call this method to determine if an item is in the shopping cart and active
  #
  # @param [none]
  # @return [Boolean]
  def shopping_cart_item?
    item_type_id == ItemType::SHOPPING_CART_ID && active?
  end

  #def self.mark_items_purchased(cart, order)
  #  CartItem.update_all("item_type_id = #{ItemType::PURCHASED_ID}", "id IN (#{cart.shopping_cart_item_ids.join(',')}) AND variant_id IN (#{order.variant_ids.join(',')})")
  #end

  private

    def inactivate_zero_quantity
      active = false if quantity == 0
    end
end
=end