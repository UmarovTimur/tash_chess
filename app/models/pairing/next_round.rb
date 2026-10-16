# Pairs one more round from the games played so far, loosely following the FIDE Dutch system:
#
# * members are ranked by score (Swiss) or only by rating (re-planning a round robin);
# * inside a score group the top half meets the bottom half;
# * players meet as rarely as possible: a first meeting comes before a second one, and the same pair doesn't
#   meet in two rounds in a row when that can be avoided. So any number of rounds works, even more than
#   there are opponents. A pairing that would leave the next round without such a pairing is avoided too;
# * the bye goes to the lowest ranked of the players with the fewest byes (Swiss: a free point). When re-planning
#   a round robin, where the bye is just a rest, it goes to whoever has played most, so late entries catch up;
# * colors are balanced and alternated.
class Pairing::NextRound
  SEARCH_LIMIT = 20_000

  Entry = Struct.new(:player, :score, :rank, :meetings, :last_met, :colors, :byes) do
    # Compared by identity: the search does a lot of set arithmetic on entries, and the default Struct
    # equality would compare every field, meetings and colors included.
    def ==(other) = equal?(other)
    alias_method :eql?, :==
    def hash = object_id.hash

    def meetings_with(other)
      meetings[other.player.id]
    end

    def met_in_round?(other, number)
      last_met[other.player.id] == number
    end

    def games_played
      meetings.values.sum
    end

    def color_balance
      colors.count(:white) - colors.count(:black)
    end

    def played_colors
      colors.compact
    end

    # The color a player must get (FIDE absolute criteria), if any.
    def required_color
      last_two = played_colors.last(2)
      if color_balance <= -2 || last_two == %i[ black black ] then :white
      elsif color_balance >= 2 || last_two == %i[ white white ] then :black
      end
    end
  end

  attr_reader :tournament

  def initialize(tournament, by_score: true)
    @tournament = tournament
    @by_score = by_score
  end

  def call
    @number = tournament.rounds.maximum(:number).to_i + 1
    bye_entry, pairs = pair(build_entries)

    round = tournament.rounds.create!(number: @number)
    boards = pairs.sort_by { |a, b| [ -[ a.score, b.score ].max, -(a.score + b.score), [ a.rank, b.rank ].min ] }

    boards.each.with_index(1) do |(a, b), board|
      white, black = white_first?(a, b, board) ? [ a, b ] : [ b, a ]
      round.games.create!(board:, white_player: white.player, black_player: black.player)
    end
    round.games.create!(board: boards.size + 1, white_player: bye_entry.player, result: :bye) if bye_entry

    round
  end

  private
    def build_entries
      entries = tournament.players.reload.to_h do |player|
        [ player.id, Entry.new(player, 0.0, nil, Hash.new(0), {}, Array.new(@number - 1), 0) ]
      end

      tournament.games.includes(:round).each do |game|
        number = game.round.number
        white = entries[game.white_player_id]
        black = entries[game.black_player_id]
        next unless white

        if game.bye?
          white.byes += 1
          white.score += tournament.bye_points if @by_score
          next
        end
        next unless black

        [ [ white, black, :white ], [ black, white, :black ] ].each do |entry, opponent, color|
          entry.meetings[opponent.player.id] += 1
          entry.last_met[opponent.player.id] = [ entry.last_met[opponent.player.id].to_i, number ].max
          entry.colors[number - 1] = color
          entry.score += game.points_for(entry.player).to_f if @by_score
        end
      end

      entries.values
        .sort_by { |e| [ -e.score, -(e.player.fide_rating || 0), e.player.name, e.player.id ] }
        .each_with_index { |entry, index| entry.rank = index }
    end

    # Returns [bye_entry, pairs], trying the rules below from strictest to loosest:
    #
    # 1. +limit+: pairs may have met at most this many times (0 first, then 1, 2, ...);
    # 2. +fresh+: no pair from the previous round;
    # 3. +repeats+: as few pairs as possible that already met +limit+ times;
    # 4. +lookahead+: the next round can still be paired within +limit+.
    def pair(entries)
      most_meetings = entries.flat_map { |entry| entry.meetings.values }.max.to_i

      (0..most_meetings + 1).each do |limit|
        if limit.zero?
          found = attempt(entries, limit)
        else
          found = fewest_repeats(entries, limit, fresh: true) || fewest_repeats(entries, limit, fresh: false)
        end
        return found if found
      end
      raise "No pairing found for round #{@number}"
    end

    # Binary search for the smallest number of pairs meeting for the (limit + 1)-th time.
    def fewest_repeats(entries, limit, fresh:)
      low, high, best = 1, entries.size / 2, nil
      while low <= high
        middle = (low + high) / 2
        if (found = attempt(entries, limit, fresh:, repeats: middle))
          best, high = found, middle - 1
        else
          low = middle + 1
        end
      end
      best
    end

    # One pairing under the given rules, with the lookahead if the next round is planned and it can be kept.
    def attempt(entries, limit, fresh: false, repeats: nil)
      lookahead_options = tournament.rounds_count.to_i > @number ? [ true, false ] : [ false ]

      lookahead_options.each do |lookahead|
        @steps = 0
        bye_candidates(entries).each do |bye_entry|
          pairs = search(entries - [ bye_entry ], limit, fresh:, repeats:) do |candidate|
            !lookahead || next_round_pairable?(entries, bye_entry, candidate, limit)
          end
          return [ bye_entry, pairs ] if pairs
        end
      end
      nil
    end

    # Players who may get the bye, best choice first; nobody when the count is even.
    def bye_candidates(entries, extra_bye: nil)
      return [ nil ] if entries.size.even?

      byes = entries.to_h { |entry| [ entry, entry.byes + (entry == extra_bye ? 1 : 0) ] }
      fewest = entries.select { |entry| byes[entry] == byes.values.min }.reverse
      @by_score ? fewest : fewest.sort_by.with_index { |entry, index| [ -entry.games_played, index ] }
    end

    # Depth-first search: pair the highest ranked player with the best acceptable opponent, backtrack when stuck.
    # See #pair for the rules. A complete pairing is returned only if the block accepts it.
    def search(pool, limit, chosen = [], fresh: false, repeats: nil, &accept)
      return accept.call(chosen) ? chosen : nil if pool.empty?
      return nil if (@steps += 1) > SEARCH_LIMIT

      top, *rest = pool
      candidates_for(top, rest).each do |opponent|
        meetings = top.meetings_with(opponent)
        next if meetings > limit
        next if fresh && top.met_in_round?(opponent, @number - 1)

        repeats_left = repeats && meetings == limit ? repeats - 1 : repeats
        next if repeats_left&.negative?
        next if repeats_left && repeats_needed(rest - [ opponent ], limit) > repeats_left

        if (pairs = search(rest - [ opponent ], limit, chosen + [ [ top, opponent ] ], fresh:, repeats: repeats_left, &accept))
          return pairs
        end
      end
      nil
    end

    # Lower bound of the pairs meeting for the (limit + 1)-th time: a player with nobody left to meet fewer times
    # forces one, and such a pair takes care of at most two of them.
    def repeats_needed(pool, limit)
      stuck = pool.count { |entry| pool.none? { |other| !other.equal?(entry) && entry.meetings_with(other) < limit } }
      (stuck + 1) / 2
    end

    # Whether, after this round, everyone can be paired again with at most +limit+ meetings per pair.
    def next_round_pairable?(entries, bye_entry, pairs, limit)
      this_round = pairs.to_set { |a, b| [ a.player.id, b.player.id ].sort }
      meetings = ->(a, b) { a.meetings_with(b) + (this_round.include?([ a.player.id, b.player.id ].sort) ? 1 : 0) }

      bye_candidates(entries, extra_bye: bye_entry).any? { |next_bye| matchable?(entries - [ next_bye ], limit, meetings) }
    end

    # Plain perfect-matching check. Out of search budget counts as yes, so it never blocks a pairing.
    def matchable?(pool, limit, meetings)
      return true if pool.empty? || (@steps += 1) > SEARCH_LIMIT

      top, *rest = pool
      rest.any? { |other| meetings.(top, other) <= limit && matchable?(rest - [ other ], limit, meetings) }
    end

    # Orders opponents by: fewest meetings, not met last round, same score, compatible colors,
    # Dutch "top half vs bottom half" position. Only the position depends on who is still unpaired.
    def candidates_for(top, rest)
      same_score = rest.select { |entry| entry.score == top.score }
      ideal = (same_score.size + 1) / 2 - 1
      positions = same_score.each_with_index.to_h

      rest.each_with_index.sort_by { |entry, index|
        position = positions[entry]
        distance = position ? (position >= ideal ? (position - ideal) * 2 : (ideal - position) * 2 + 1) : index
        [ *static_key(top, entry), distance ]
      }.map(&:first)
    end

    def static_key(top, entry)
      (@static_keys ||= {})[[ top.rank, entry.rank ]] ||= [
        top.meetings_with(entry),
        top.met_in_round?(entry, @number - 1) ? 1 : 0,
        (top.score - entry.score).abs,
        top.required_color && top.required_color == entry.required_color ? 1 : 0
      ]
    end

    # +a+ is the higher ranked player of the pair.
    def white_first?(a, b, board)
      return a.required_color == :white if a.required_color && a.required_color != b.required_color
      return b.required_color == :black if b.required_color
      return a.color_balance < b.color_balance if a.color_balance != b.color_balance

      a.colors.reverse.zip(b.colors.reverse).each do |color_a, color_b|
        return color_a == :black if color_a && color_b && color_a != color_b
      end

      last_color = a.played_colors.last
      last_color ? last_color == :black : board.odd?
    end
end
