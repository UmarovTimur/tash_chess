require "test_helper"

class Pairing::RoundRobinTest < ActiveSupport::TestCase
  test "matches the FIDE Berger table for 6 players" do
    expected = [
      %w[ 1-6 2-5 3-4 ], %w[ 6-4 5-3 1-2 ], %w[ 2-6 3-1 4-5 ], %w[ 6-5 1-4 2-3 ], %w[ 3-6 4-2 5-1 ]
    ]
    schedule = Pairing::RoundRobin.berger_schedule(6).map { |pairs| pairs.map { |w, b| "#{w + 1}-#{b + 1}" } }

    assert_equal expected, schedule
  end

  test "everybody meets everybody exactly once with balanced colors" do
    [ 4, 8, 12, 16 ].each do |size|
      schedule = Pairing::RoundRobin.berger_schedule(size)
      pairs = schedule.flatten(1).map(&:sort)

      assert_equal size * (size - 1) / 2, pairs.uniq.size
      assert_equal pairs.size, pairs.uniq.size
      schedule.each { |round| assert_equal (0...size).to_a, round.flatten.sort }

      colors = Hash.new { |hash, key| hash[key] = [] }
      schedule.each { |round| round.each { |white, black| colors[white] << :w; colors[black] << :b } }
      colors.each_value do |sequence|
        assert_operator (sequence.count(:w) - sequence.count(:b)).abs, :<=, 1
        assert_operator sequence.chunk_while { |a, b| a == b }.map(&:size).max, :<=, 2, "no color three times in a row"
      end
    end
  end

  test "starting a round robin pairs all rounds with boards" do
    tournament = create_tournament(system: :round_robin, rounds: nil, players: Player.all)
    assert tournament.start

    assert_equal 7, tournament.reload.rounds_count
    assert_equal 7, tournament.rounds.count
    tournament.rounds.each do |round|
      assert_equal [ 1, 2, 3, 4 ], round.games.map(&:board)
      assert_equal 8, round.games.flat_map(&:players).uniq.size
    end
    assert_equal players(:anna), tournament.rounds.first.games.first.white_player, "top seed starts on board 1"
  end

  test "with an odd number of players one player rests each round" do
    tournament = create_tournament(system: :round_robin, rounds: nil, players: Player.by_rating.first(5))
    assert tournament.start

    assert_equal 5, tournament.rounds.count
    tournament.rounds.each do |round|
      byes = round.games.select(&:bye?)
      assert_equal 1, byes.size
      assert_equal 3, byes.first.board, "bye is listed after the two real boards"
    end
    assert_equal 5, tournament.games.bye.map(&:white_player_id).uniq.size, "each player rests exactly once"
    assert_equal 0, tournament.bye_points
  end
end
