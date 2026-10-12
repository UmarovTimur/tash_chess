class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.references :round, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.integer :board, null: false
      t.references :white_player, null: false, foreign_key: { to_table: :players }
      t.references :black_player, foreign_key: { to_table: :players }
      t.string :result, null: false, default: "pending"

      t.timestamps
    end

    add_index :games, [ :round_id, :board ], unique: true
    add_check_constraint :games, "board > 0", name: "games_board_positive"
    add_check_constraint :games, "result IN ('pending', 'white_won', 'black_won', 'draw', 'bye')", name: "games_result_valid"
    add_check_constraint :games, "(black_player_id IS NULL) = (result = 'bye')", name: "games_bye_has_no_opponent"
    add_check_constraint :games, "white_player_id <> black_player_id", name: "games_distinct_players"
  end
end
