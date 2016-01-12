module Spree
  module Stock
    class Package
      attr_reader :stock_location
      attr_accessor :shipping_rates

      def initialize(stock_location, unindexed_contents=[])
        @stock_location = stock_location
        @indexed_contents = {}
        @shipping_rates = Array.new
        index_contents(unindexed_contents)
      end

      def add(inventory_unit, state = :on_hand)
        add_unit(inventory_unit, state)
      end

      def add_multiple(inventory_units, state = :on_hand)
        inventory_units.each { |inventory_unit| add_unit(inventory_unit, state) }
      end

      def remove_first_item
        inventory_unit = @indexed_contents.first.first
        remove(inventory_unit)
      end

      def remove(inventory_unit)
        remove_unit(inventory_unit)
      end

      def contents
        @indexed_contents.values.flatten
      end

      # Fix regression that removed package.order.
      # Find it dynamically through an inventory_unit.
      def order
        contents.detect {|item| !!item.try(:inventory_unit).try(:order) }.try(:inventory_unit).try(:order)
      end

      def weight
        contents.sum(&:weight)
      end

      def on_hand
        contents.select(&:on_hand?)
      end

      def backordered
        contents.select(&:backordered?)
      end

      def awaiting_feed
        contents.select(&:awaiting_feed?)
      end

      def find_item(inventory_unit, state = nil)
        indexed_contents_for(inventory_unit).detect { |i| (!state || i.state.to_s == state.to_s) }
      end

      def quantity(state = nil)
        matched_contents = state.nil? ? contents : contents.select { |c| c.state.to_s == state.to_s }
        matched_contents.map(&:quantity).sum
      end

      def empty?
        quantity == 0
      end

      def currency
        #TODO calculate from first variant?
      end

      def shipping_categories
        contents.map { |item| item.variant.shipping_category }.compact.uniq
      end

      def shipping_methods
        shipping_categories.map(&:shipping_methods).reduce(:&).to_a
      end

      def inspect
        contents.map do |content_item|
          "#{content_item.variant.name} #{content_item.state}"
        end.join(' / ')
      end

      def to_shipment
        contents.each do |content_item|
          content_item.inventory_unit.state = content_item.state.to_s
        end

        Spree::Shipment.new(
          stock_location: stock_location,
          shipping_rates: shipping_rates,
          inventory_units: contents.map(&:inventory_unit)
        )
      end

      private

      def index_contents(unindexed_contents)
        unindexed_contents.each do |content_item|
          inventory_unit = content_item.inventory_unit
          next if find_item(inventory_unit)
          indexed_contents_for(inventory_unit) << content_item
        end
      end

      def indexed_contents_for(inventory_unit)
        @indexed_contents[inventory_unit] ||= []
        @indexed_contents[inventory_unit]
      end

      def add_unit(inventory_unit, state)
        return if find_item(inventory_unit)
        indexed_contents_for(inventory_unit) << ContentItem.new(inventory_unit, state)
      end

      def remove_unit(inventory_unit)
        item = find_item(inventory_unit)
        @indexed_contents[inventory_unit] -= [item] if item
        @indexed_contents.delete(inventory_unit) if @indexed_contents[inventory_unit].empty?
        item
      end
    end
  end
end
