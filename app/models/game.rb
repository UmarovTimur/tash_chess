class Game < ApplicationRecord
  RESULT_LABELS = { "white_won" => "1–0", "draw" => "½–½", "black_won" => "0–1" }.freeze

  belongs_to :round, touch: true
  belongs_to :white_player, class_name: "Player"
  belongs_to :black_player, class_name: "Player", optional: true

  enum :result, { pending: "pending", white_won: "white_won", black_won: "black_won", draw: "draw", bye: "bye" },
    default: :pending, validate: true

  validates :board, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :round_id }
  validates :black_player, presence: true, unless: :bye?
  validate :bye_result_matches_pairing

  delegate :tournament, to: :round

  def result_label
    RESULT_LABELS.fetch(result, "")
  end

  def players
    [ white_player, black_player ].compact
  end

  def played?
    !pending? && !bye?
  end

  def points_for(player)
    case result
    when "white_won" then player == white_player ? 1.0 : 0.0
    when "black_won" then player == black_player ? 1.0 : 0.0
    when "draw" then 0.5
    when "bye" then tournament.bye_points.to_f
    end
  end

  private
    def bye_result_matches_pairing
      if black_player_id.nil? && !bye?
        errors.add(:result, :bye_locked)
      elsif black_player_id.present? && bye?
        errors.add(:result, :bye_not_allowed)
      end
    end
end
