class CreateParticipations < ActiveRecord::Migration[8.1]
  def change
    create_table :participations do |t|
      t.references :tournament, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :player, null: false, foreign_key: true

      t.timestamps
    end

    add_index :participations, [ :tournament_id, :player_id ], unique: true
  end
end
