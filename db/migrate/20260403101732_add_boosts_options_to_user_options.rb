# frozen_string_literal: true

class AddBoostsOptionsToUserOptions < ActiveRecord::Migration[7.2]
  def change
    unless column_exists?(:user_options, :boost_notifications_level)
      add_column :user_options, :boost_notifications_level, :integer, default: 1, null: false
    end
  end
end
