class Participation < ApplicationRecord
  belongs_to :tournament, touch: true
  belongs_to :player

  validates :player_id, uniqueness: { scope: :tournament_id }

  before_destroy :ensure_no_games_played, prepend: true

  # Games in rounds that are already fixed; planned round robin games are re-paired without the player.
  def games_played?
    tournament.fixed_games.merge(player.games).exists?
  end

  private
    def ensure_no_games_played
      if games_played?
        errors.add(:base, :games_played, name: player.name)
        throw :abort
      end
    end
end
