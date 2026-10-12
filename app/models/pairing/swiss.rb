# Pairs the next round of a Swiss tournament, loosely following the FIDE Dutch system:
#
# * members are ranked by score, then rating;
# * inside a score group the top half meets the bottom half;
# * nobody meets the same opponent twice and nobody gets a second bye, as long as that is possible;
# * colors are balanced and alternated.
class Pairing::Swiss
  SEARCH_LIMIT = 20_000

  Entry = Struct.new(:player, :score, :rank, :opponent_ids, :colors, :had_bye) do
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

  def initialize(tournament)
    @tournament = tournament
  end

  def call
    entries = build_entries
    bye_entry, pairs = pair(entries)

    round = tournament.rounds.create!(number: tournament.rounds.size + 1)
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
      players = tournament.players.reload.to_a
      games = tournament.games.includes(:round).to_a
      rounds_played = tournament.rounds.size
      entries = players.to_h do |player|
        [ player.id, Entry.new(player, 0.0, nil, [], Array.new(rounds_played), false) ]
      end

      games.each do |game|
        index = game.round.number - 1
        white = entries[game.white_player_id]
        black = entries[game.black_player_id]

        if game.bye?
          white.had_bye = true
          white.score += tournament.bye_points
          next
        end

        white.opponent_ids << game.black_player_id
        black.opponent_ids << game.white_player_id
        white.colors[index] = :white
        black.colors[index] = :black
        white.score += game.points_for(white.player)
        black.score += game.points_for(black.player)
      end

      entries.values
        .sort_by { |e| [ -e.score, -(e.player.fide_rating || 0), e.player.name, e.player.id ] }
        .each_with_index { |entry, index| entry.rank = index }
    end

    # Returns [bye_entry, pairs]. Tries the strict rules first and relaxes them only when nothing fits.
    def pair(entries)
      @steps = 0
      bye_candidates = entries.size.odd? ? entries.reverse : [ nil ]
      fresh_bye_candidates = bye_candidates.reject { |entry| entry&.had_bye }
      fresh_bye_candidates = bye_candidates if fresh_bye_candidates.empty?

      fresh_bye_candidates.each do |bye_entry|
        pairs = match(entries - [ bye_entry ], allow_rematches: false)
        return [ bye_entry, pairs ] if pairs
      end

      @steps = 0
      bye_entry = fresh_bye_candidates.first
      [ bye_entry, match(entries - [ bye_entry ], allow_rematches: true) ]
    end

    def match(pool, allow_rematches:)
      search(pool, allow_rematches)
    end

    # Depth-first search: pair the highest ranked player with the best acceptable opponent, backtrack when stuck.
    def search(pool, allow_rematches)
      return [] if pool.empty?
      return nil if (@steps += 1) > SEARCH_LIMIT

      top, *rest = pool
      candidates_for(top, rest).each do |opponent|
        next if !allow_rematches && top.opponent_ids.include?(opponent.player.id)

        if (pairs = search(rest - [ opponent ], allow_rematches))
          return [ [ top, opponent ], *pairs ]
        end
      end
      nil
    end

    # Orders opponents by: no rematch, same score, compatible colors, Dutch "top half vs bottom half" position.
    def candidates_for(top, rest)
      same_score = rest.select { |entry| entry.score == top.score }
      ideal = (same_score.size + 1) / 2 - 1

      rest.each_with_index.sort_by { |entry, index|
        position = same_score.index(entry)
        distance = position ? (position >= ideal ? (position - ideal) * 2 : (ideal - position) * 2 + 1) : index
        rematch = top.opponent_ids.include?(entry.player.id) ? 1 : 0
        color_clash = top.required_color && top.required_color == entry.required_color ? 1 : 0

        [ rematch, (top.score - entry.score).abs, color_clash, distance ]
      }.map(&:first)
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
