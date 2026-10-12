class Tournament < ApplicationRecord
  MAX_ROUNDS = 30

  enum :pairing_system, { swiss: "swiss", round_robin: "round_robin" }, validate: true
  enum :status, { registration: "registration", in_progress: "in_progress", finished: "finished" }, default: :registration

  # Deleted in SQL (games cascade from rounds): members with games refuse to be destroyed one by one.
  has_many :participations, dependent: :delete_all
  has_many :players, through: :participations
  has_many :rounds, -> { order(:number) }, dependent: :delete_all, inverse_of: :tournament
  has_many :games, through: :rounds

  normalizes :name, :location, with: ->(value) { value.squish.presence }

  validates :name, presence: true, length: { maximum: 120 }
  validates :location, length: { maximum: 120 }
  validates :rounds_count, presence: true, if: :swiss?
  validates :rounds_count, numericality: { only_integer: true, in: 1..MAX_ROUNDS }, allow_nil: true
  validate :pairing_system_unchanged_after_start, :rounds_count_covers_played_rounds, on: :update

  before_save -> { self.rounds_count = nil }, if: -> { round_robin? && registration? }

  broadcasts_refreshes

  scope :ordered, -> { in_order_of(:status, %w[ in_progress registration finished ]).order(starts_on: :desc, created_at: :desc) }

  def self.pairing_system_label(system)
    system.to_s == "round_robin" ? "Round robin" : "Swiss"
  end

  def pairing_system_label
    self.class.pairing_system_label(pairing_system)
  end

  # Swiss pairing-allocated byes score like a win; in a round robin the odd player just rests.
  def bye_points
    swiss? ? 1 : 0
  end

  def members_editable?
    registration? || (swiss? && in_progress?)
  end

  def current_round
    rounds.last
  end

  def all_games_complete?
    !games.pending.exists?
  end

  def can_pair_next_round?
    swiss? && in_progress? && rounds.size < rounds_count && all_games_complete?
  end

  def can_finish?
    in_progress? && rounds.any? && all_games_complete?
  end

  def can_reset?
    in_progress? && !games.where.not(result: %w[ pending bye ]).exists?
  end

  def start
    if !registration?
      errors.add(:base, "Tournament has already started")
    elsif participations.count < 2
      errors.add(:base, "At least 2 members are needed to start the tournament")
    elsif swiss? && rounds_count > max_swiss_rounds
      errors.add(:rounds_count, "is too high for #{participations.count} members (maximum is #{max_swiss_rounds})")
    end
    return false if errors.any?

    transaction do
      in_progress!
      round_robin? ? Pairing::RoundRobin.new(self).call : Pairing::Swiss.new(self).call
    end
    true
  end

  def pair_next_round
    unless can_pair_next_round?
      errors.add(:base, "The next round can be paired only when every result of the current round is entered")
      return false
    end

    transaction { Pairing::Swiss.new(self).call }
    touch
    true
  end

  def finish
    unless can_finish?
      errors.add(:base, "The tournament can be finished only when every result is entered")
      return false
    end

    finished!
  end

  # Throws away all pairings and goes back to registration. Allowed only before any game is played.
  def reset
    unless can_reset?
      errors.add(:base, "Pairings can be reset only before any result is entered")
      return false
    end

    transaction do
      rounds.destroy_all
      update!(status: :registration, rounds_count: swiss? ? rounds_count : nil)
    end
  end

  def remove_last_round
    round = current_round
    unless swiss? && in_progress? && round
      errors.add(:base, "Only the latest round of a running Swiss tournament can be deleted")
      return false
    end

    transaction do
      round.destroy!
      rounds.reset
      rounds.empty? ? registration! : touch
    end
  end

  def standings
    Standings.new(self)
  end

  private
    # Without rematches, n members can play at most n - 1 rounds (n rounds when n is odd, because of the bye).
    def max_swiss_rounds
      count = participations.count
      count.even? ? count - 1 : count
    end

    def pairing_system_unchanged_after_start
      if pairing_system_changed? && !registration?
        errors.add(:pairing_system, "can't be changed after the tournament has started")
      end
    end

    def rounds_count_covers_played_rounds
      if swiss? && rounds_count.present? && rounds_count < rounds.size
        errors.add(:rounds_count, "can't be less than the #{rounds.size} rounds already paired")
      end
    end
end
