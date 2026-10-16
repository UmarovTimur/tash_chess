class AddWithdrawnAtToParticipations < ActiveRecord::Migration[8.1]
  def change
    add_column :participations, :withdrawn_at, :datetime
  end
end
