# Generates every round of a round robin up front using the FIDE Berger tables.
# Members are seeded by rating; with an odd count the last seed is an empty slot and
# whoever meets it rests that round.
class Pairing::RoundRobin
  attr_reader :tournament

  def initialize(tournament)
    @tournament = tournament
  end

  # Returns rounds as lists of [white_seed, black_seed] index pairs for +size+ (even) slots.
  def self.berger_schedule(size)
    last = size - 1
    half = size / 2

    (0...last).map do |round_index|
      circle = (0...last).map { |k| (round_index * half + k) % last }
      first_pair = round_index.even? ? [ circle[0], last ] : [ last, circle[0] ]
      [ first_pair ] + (1...half).map { |i| [ circle[i], circle[last - i] ] }
    end
  end

  def call
    slots = tournament.players.by_rating.to_a
    slots << nil if slots.size.odd?

    self.class.berger_schedule(slots.size).each.with_index(1) do |pairs, number|
      round = tournament.rounds.create!(number:)
      games = pairs.map { |white, black| [ slots[white], slots[black] ] }
      byes, real_games = games.partition { |pair| pair.include?(nil) }

      real_games.each.with_index(1) do |(white, black), board|
        round.games.create!(board:, white_player: white, black_player: black)
      end
      byes.each do |pair|
        round.games.create!(board: real_games.size + 1, white_player: pair.compact.first, result: :bye)
      end
    end

    tournament.update!(rounds_count: slots.size - 1)
  end
end
