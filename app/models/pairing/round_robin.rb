# Round robin ("everyone plays everyone") using the FIDE Berger tables, all rounds paired up front.
# Members are seeded by rating; with an odd count the last seed is an empty slot and whoever meets it rests.
# With more rounds than one cycle needs, the cycle repeats with colors reversed.
class Pairing::RoundRobin
  attr_reader :tournament

  def initialize(tournament)
    @tournament = tournament
  end

  # Rounds as lists of [white_seed, black_seed] index pairs for +size+ (even) slots.
  def self.berger_schedule(size)
    last = size - 1
    half = size / 2

    (0...last).map do |round_index|
      circle = (0...last).map { |k| (round_index * half + k) % last }
      first_pair = round_index.even? ? [ circle[0], last ] : [ last, circle[0] ]
      [ first_pair ] + (1...half).map { |i| [ circle[i], circle[last - i] ] }
    end
  end

  # +rounds+ rounds of Berger cycles one after another, colors reversed in every second cycle.
  def self.schedule(size, rounds)
    cycle = berger_schedule(size)

    Array.new(rounds) do |index|
      pairs = cycle[index % cycle.size]
      (index / cycle.size).odd? ? pairs.map(&:reverse) : pairs
    end
  end

  # Rounds needed for everyone to meet everyone once.
  def self.cycle_length(members_count)
    members_count.even? ? members_count - 1 : members_count
  end

  def call
    planned_rounds.each.with_index(1) { |pairs, number| create_round(number, pairs) }
  end

  # The members or the number of rounds changed during the tournament. Rounds already in play stay as they are and
  # the later ones are paired again: the Berger cycles simply continue when the members are the same, otherwise
  # each round is paired so that players meet as rarely as possible.
  def replan
    kept = tournament.fixed_rounds_count
    tournament.rounds.where("number > ?", kept).destroy_all
    tournament.rounds.reset

    planned = planned_rounds
    if follows_plan?(planned.first(kept))
      planned.drop(kept).each.with_index(kept + 1) { |pairs, number| create_round(number, pairs) }
    else
      (kept + 1..tournament.rounds_count).each { Pairing::NextRound.new(tournament, by_score: false).call }
    end
  end

  private
    def slots
      @slots ||= tournament.players.by_rating.to_a.then { |players| players.size.odd? ? players + [ nil ] : players }
    end

    def planned_rounds
      self.class.schedule(slots.size, tournament.rounds_count).map do |pairs|
        pairs.map { |white, black| [ slots[white], slots[black] ] }
      end
    end

    def follows_plan?(planned)
      played = tournament.rounds.includes(:games).first(planned.size)
      played.size == planned.size && planned.zip(played).all? do |pairs, round|
        pairing_ids(pairs) == round.games.to_set { |game| [ game.white_player_id, game.black_player_id ] }
      end
    end

    def pairing_ids(pairs)
      pairs.to_set { |white, black| white && black ? [ white.id, black.id ] : [ (white || black).id, nil ] }
    end

    def create_round(number, pairs)
      round = tournament.rounds.create!(number:)
      byes, games = pairs.partition { |pair| pair.include?(nil) }

      games.each.with_index(1) do |(white, black), board|
        round.games.create!(board:, white_player: white, black_player: black)
      end
      byes.each { |pair| round.games.create!(board: games.size + 1, white_player: pair.compact.first, result: :bye) }
    end
end
