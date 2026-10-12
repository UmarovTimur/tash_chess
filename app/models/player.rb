class Player < ApplicationRecord
  NICKNAME_FORMAT = /\A[\p{L}\p{N}_.\-]+\z/

  has_many :participations, dependent: :destroy
  has_many :tournaments, through: :participations
  has_many :white_games, class_name: "Game", foreign_key: :white_player_id, inverse_of: :white_player
  has_many :black_games, class_name: "Game", foreign_key: :black_player_id, inverse_of: :black_player

  normalizes :name, :nickname, with: ->(value) { value.squish }

  validates :name, presence: true, length: { maximum: 100 }
  validates :nickname, presence: true, length: { maximum: 30 }, uniqueness: { case_sensitive: false },
    format: { with: NICKNAME_FORMAT }
  validates :fide_rating, numericality: { only_integer: true, in: 1000..3000 }, allow_nil: true

  before_destroy :ensure_no_games_played, prepend: true

  scope :alphabetical, -> { order(:name, :nickname) }
  scope :by_rating, -> { order(arel_table[:fide_rating].desc.nulls_last, :name, :nickname) }
  scope :search, ->(query) {
    pattern = "%#{sanitize_sql_like(query.to_s.strip)}%"
    where("players.name ILIKE :pattern OR players.nickname ILIKE :pattern", pattern:)
  }

  def games
    Game.where(white_player: self).or(Game.where(black_player: self))
  end

  private
    def ensure_no_games_played
      if games.exists?
        errors.add(:base, :games_played, name:)
        throw :abort
      end
    end
end
