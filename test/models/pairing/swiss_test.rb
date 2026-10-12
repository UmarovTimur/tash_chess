require "test_helper"

class Pairing::SwissTest < ActiveSupport::TestCase
  test "first round pairs the top half against the bottom half, alternating colors by board" do
    tournament = create_tournament(players: Player.all, rounds: 3)
    assert tournament.start

    games = tournament.rounds.first.games.map { |game| [ game.board, game.white_player.nickname, game.black_player.nickname ] }
    assert_equal [
      [ 1, "anna_k", "erikj" ],
      [ 2, "fatima", "boris" ],
      [ 3, "chenwei", "giorgi" ],
      [ 4, "hana", "daria" ]
    ], games
  end

  test "winners meet winners in round two" do
    tournament = create_tournament(players: Player.all, rounds: 3)
    tournament.start
    play_round(tournament.current_round)

    assert tournament.pair_next_round
    top_boards = tournament.current_round.games.first(2).map { |game| game.players.map(&:nickname).sort }
    assert_equal [ %w[ anna_k chenwei ], %w[ boris daria ] ], top_boards, "top half of the 1-point group meets the bottom half"
  end

  test "no rematches and balanced colors across a full event" do
    players = create_players(12)
    tournament = create_tournament(players:, rounds: 7)
    tournament.start
    random = Random.new(42)

    7.times do |index|
      play_round(tournament.current_round) { %i[ white_won black_won draw ].sample(random:) }
      tournament.pair_next_round unless index == 6
    end

    pairs = tournament.games.where.not(result: :bye).map { |game| [ game.white_player_id, game.black_player_id ].sort }
    assert_equal pairs.size, pairs.uniq.size, "nobody met the same opponent twice"

    players.each do |player|
      whites = tournament.games.where(white_player: player).where.not(result: :bye).count
      blacks = tournament.games.where(black_player: player).count
      assert_operator (whites - blacks).abs, :<=, 2, "#{player.name} has #{whites} whites and #{blacks} blacks"
    end
  end

  test "odd field gives the bye to the lowest ranked player, never twice to the same player" do
    tournament = create_tournament(players: Player.where.not(id: players(:giorgi)), rounds: 5)
    tournament.start

    bye = tournament.current_round.games.find(&:bye?)
    assert_equal players(:hana), bye.white_player, "unrated player is seeded last"
    assert_equal 4, bye.board

    4.times do
      play_round(tournament.current_round)
      tournament.pair_next_round
    end

    bye_players = tournament.games.bye.map(&:white_player_id)
    assert_equal 5, bye_players.size
    assert_equal bye_players.size, bye_players.uniq.size
  end

  test "late entry is paired from the next round" do
    tournament = create_tournament(players: Player.by_rating.first(6), rounds: 3)
    tournament.start
    play_round(tournament.current_round)
    tournament.participations.create!(player: players(:giorgi))
    tournament.participations.create!(player: players(:hana))

    tournament.pair_next_round
    assert_equal 4, tournament.current_round.games.size
    assert_includes tournament.current_round.games.flat_map(&:players), players(:hana)
  end
end
