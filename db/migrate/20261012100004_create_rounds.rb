class CreateRounds < ActiveRecord::Migration[8.1]
  def change
    create_table :rounds do |t|
      t.references :tournament, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.integer :number, null: false

      t.timestamps
    end

    add_index :rounds, [ :tournament_id, :number ], unique: true
  end
end
