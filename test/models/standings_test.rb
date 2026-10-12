require "test_helper"

class StandingsTest < ActiveSupport::TestCase
  setup do
    @tournament = create_tournament(system: :round_robin, rounds: nil, players: [ players(:anna), players(:boris), players(:chen), players(:daria) ])
    @tournament.start
  end

  test "counts points, wins, draws and losses" do
    play_all { |game| game.white_player == players(:anna) || game.black_player == players(:anna) ? anna_wins(game) : :draw }

    row = @tournament.standings[players(:anna)]
    assert_equal 3.0, row.points
    assert_equal [ 3, 0, 0 ], [ row.wins, row.draws, row.losses ]
    assert_equal 1, row.rank

    others = @tournament.standings.rows.drop(1)
    assert others.all? { |other| other.points == 1.0 && other.rank == 2 }, "equal players share the rank"
  end

  test "Sonneborn-Berger breaks ties" do
    winners = {
      %w[ anna_k boris ] => nil, %w[ anna_k chenwei ] => "anna_k", %w[ anna_k daria ] => "anna_k",
      %w[ boris chenwei ] => "boris", %w[ boris daria ] => "daria", %w[ chenwei daria ] => "chenwei"
    }
    play_all do |game|
      winner = winners.fetch(game.players.map(&:nickname).sort)
      winner.nil? ? :draw : (game.white_player.nickname == winner ? :white_won : :black_won)
    end

    rows = @tournament.standings.rows
    assert_equal %w[ anna_k boris daria chenwei ], rows.map { |row| row.player.nickname }
    assert_equal [ 2.5, 1.5, 1.0, 1.0 ], rows.map(&:points)
    assert_equal [ 2.75, 2.25, 1.5, 1.0 ], rows.map(&:sonneborn_berger), "Daria beat Boris (1.5), Chen beat Daria (1.0)"
    assert_equal [ 1, 2, 3, 4 ], rows.map(&:rank)
  end

  test "pending games show in round cells without points" do
    row = @tournament.standings[players(:anna)]

    assert_equal 0.0, row.points
    assert row.cells.first.pending
    assert_equal 0, row.games_played
  end

  test "Swiss bye is worth a point" do
    swiss = create_tournament(players: [ players(:anna), players(:boris), players(:chen) ], rounds: 2)
    swiss.start
    play_round(swiss.current_round)

    bye_row = swiss.standings[players(:chen)]
    assert_equal 1.0, bye_row.points
    assert bye_row.cells.first.bye?
    assert_equal 1, bye_row.byes
  end

  private
    def play_all(&)
      @tournament.rounds.each { |round| play_round(round, &) }
    end

    def anna_wins(game)
      game.white_player == players(:anna) ? :white_won : :black_won
    end
end
