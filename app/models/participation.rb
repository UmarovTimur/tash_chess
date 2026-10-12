class Participation < ApplicationRecord
  belongs_to :tournament, touch: true
  belongs_to :player

  validates :player_id, uniqueness: { scope: :tournament_id, message: "is already a member of this tournament" }

  before_destroy :ensure_no_games_played, prepend: true

  def games_played?
    tournament.games.merge(player.games).exists?
  end

  private
    def ensure_no_games_played
      if games_played?
        errors.add(:base, "#{player.name} already has games in this tournament and can't be removed")
        throw :abort
      end
    end
end
