class CreatePlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :players do |t|
      t.string :name, null: false
      t.string :nickname, null: false
      t.integer :fide_rating

      t.timestamps
    end

    add_index :players, "lower(nickname)", unique: true, name: "index_players_on_lower_nickname"
    add_check_constraint :players, "fide_rating BETWEEN 1000 AND 3000", name: "players_fide_rating_range"
  end
end
