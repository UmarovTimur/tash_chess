# Current tournament table. Ranking: points, then tie-breaks
# (Swiss: Buchholz, Sonneborn-Berger, wins; round robin: Sonneborn-Berger, wins).
class Standings
  include Enumerable

  Cell = Data.define(:points, :opponent, :color, :pending) do
    def bye? = opponent.nil?
  end

  Row = Struct.new(:player, :points, :wins, :draws, :losses, :byes, :buchholz, :sonneborn_berger, :cells, :rank) do
    def games_played = wins + draws + losses

    def points_before(round_number)
      cells.first(round_number - 1).compact.sum { |cell| cell.points.to_f }
    end
  end

  attr_reader :tournament

  def initialize(tournament)
    @tournament = tournament
  end

  def each(&)
    rows.each(&)
  end

  def rows
    @rows ||= rank(calculate)
  end

  def [](player)
    rows_by_player_id[player.id]
  end

  def rounds_count
    [ tournament.rounds.size, tournament.rounds_count.to_i ].max
  end

  private
    def rows_by_player_id
      @rows_by_player_id ||= rows.index_by { |row| row.player.id }
    end

    def calculate
      rows = tournament.players.reload.to_h do |player|
        [ player.id, Row.new(player, 0.0, 0, 0, 0, 0, 0.0, 0.0, Array.new(rounds_count)) ]
      end
      opponents = Hash.new { |hash, key| hash[key] = [] }

      tournament.games.includes(:round).each do |game|
        index = game.round.number - 1
        white = rows[game.white_player_id]
        black = rows[game.black_player_id]

        if game.bye?
          white.points += tournament.bye_points
          white.byes += 1
          white.cells[index] = Cell.new(points: tournament.bye_points, opponent: nil, color: nil, pending: false)
        elsif game.pending?
          white.cells[index] = Cell.new(points: nil, opponent: black.player, color: :white, pending: true)
          black.cells[index] = Cell.new(points: nil, opponent: white.player, color: :black, pending: true)
        else
          [ [ white, black, :white ], [ black, white, :black ] ].each do |row, opponent, color|
            points = game.points_for(row.player)
            row.points += points
            case points
            when 1 then row.wins += 1
            when 0 then row.losses += 1
            else row.draws += 1
            end
            row.cells[index] = Cell.new(points:, opponent: opponent.player, color:, pending: false)
            opponents[row.player.id] << [ opponent, points ]
          end
        end
      end

      rows.each_value do |row|
        row.buchholz = opponents[row.player.id].sum { |opponent, _| opponent.points }
        row.sonneborn_berger = opponents[row.player.id].sum { |opponent, points| opponent.points * points }
      end
      rows.values
    end

    def rank(rows)
      sorted = rows.sort_by { |row| [ *sort_key(row), row.player.name.downcase, row.player.nickname.downcase ] }
      sorted.each_with_index do |row, index|
        previous = sorted[index - 1] if index.positive?
        row.rank = previous && sort_key(previous) == sort_key(row) ? previous.rank : index + 1
      end
    end

    def sort_key(row)
      if tournament.swiss?
        [ -row.points, -row.buchholz, -row.sonneborn_berger, -row.wins ]
      else
        [ -row.points, -row.sonneborn_berger, -row.wins ]
      end
    end
end
