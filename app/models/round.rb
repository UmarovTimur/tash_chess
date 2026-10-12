class Round < ApplicationRecord
  belongs_to :tournament, touch: true
  has_many :games, -> { order(:board) }, dependent: :delete_all, inverse_of: :round

  validates :number, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :tournament_id }

  def to_param
    number.to_s
  end

  def complete?
    games.none?(&:pending?)
  end

  def last?
    tournament.rounds.maximum(:number) == number
  end
end
