class CreateTournaments < ActiveRecord::Migration[8.1]
  def change
    create_table :tournaments do |t|
      t.string :name, null: false
      t.string :location
      t.date :starts_on
      t.string :pairing_system, null: false, default: "swiss"
      t.integer :rounds_count
      t.string :status, null: false, default: "registration"

      t.timestamps
    end

    add_index :tournaments, :status
    add_check_constraint :tournaments, "pairing_system IN ('swiss', 'round_robin')", name: "tournaments_pairing_system_valid"
    add_check_constraint :tournaments, "status IN ('registration', 'in_progress', 'finished')", name: "tournaments_status_valid"
    add_check_constraint :tournaments, "rounds_count IS NULL OR rounds_count > 0", name: "tournaments_rounds_count_positive"
  end
end
