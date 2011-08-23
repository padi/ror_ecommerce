class CartItemCustomization
  include Mongoid::Document
  field :customization_id

  embedded_in :cart_item

  validates_presence_of :customization_id

  def customization
    Customization.where(['customizations.id = ?', customization_id])
  end
end