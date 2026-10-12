require "rails_helper"

RSpec.describe Pairing::Swiss do
  it "pairs the top half against the bottom half in round 1, alternating colors by board" do
    tournament = create_tournament(players: Player.all, rounds: 3)

    expect(tournament.start).to be(true)
    games = tournament.rounds.first.games.map { |game| [ game.board, game.white_player.nickname, game.black_player.nickname ] }
    expect(games).to eq([
      [ 1, "anna_k", "erikj" ],
      [ 2, "fatima", "boris" ],
      [ 3, "chenwei", "giorgi" ],
      [ 4, "hana", "daria" ]
    ])
  end

  it "makes winners meet winners in round 2, top half against bottom half" do
    tournament = create_tournament(players: Player.all, rounds: 3)
    tournament.start
    play_round(tournament.current_round)

    expect(tournament.pair_next_round).to be(true)
    top_boards = tournament.current_round.games.first(2).map { |game| game.players.map(&:nickname).sort }
    expect(top_boards).to eq([ %w[ anna_k chenwei ], %w[ boris daria ] ])
  end

  it "avoids rematches and keeps colors balanced over a full event" do
    players = create_players(12)
    tournament = create_tournament(players:, rounds: 7)
    tournament.start
    random = Random.new(42)

    7.times do |index|
      play_round(tournament.current_round) { %i[ white_won black_won draw ].sample(random:) }
      tournament.pair_next_round unless index == 6
    end

    pairs = tournament.games.where.not(result: :bye).map { |game| [ game.white_player_id, game.black_player_id ].sort }
    expect(pairs).to eq(pairs.uniq), "nobody met the same opponent twice"

    players.each do |player|
      whites = tournament.games.where(white_player: player).where.not(result: :bye).count
      blacks = tournament.games.where(black_player: player).count
      expect((whites - blacks).abs).to be <= 2, "#{player.name} has #{whites} whites and #{blacks} blacks"
    end
  end

  it "gives the bye to the lowest ranked player and never twice to the same player" do
    tournament = create_tournament(players: Player.where.not(id: players(:giorgi)), rounds: 5)
    tournament.start

    bye = tournament.current_round.games.find(&:bye?)
    expect(bye.white_player).to eq(players(:hana)), "the unrated player is seeded last"
    expect(bye.board).to eq(4)

    4.times do
      play_round(tournament.current_round)
      tournament.pair_next_round
    end

    bye_players = tournament.games.bye.map(&:white_player_id)
    expect(bye_players.size).to eq(5)
    expect(bye_players).to eq(bye_players.uniq)
  end

  it "pairs late entries from the next round" do
    tournament = create_tournament(players: Player.by_rating.first(6), rounds: 3)
    tournament.start
    play_round(tournament.current_round)
    tournament.participations.create!(player: players(:giorgi))
    tournament.participations.create!(player: players(:hana))

    tournament.pair_next_round

    expect(tournament.current_round.games.size).to eq(4)
    expect(tournament.current_round.games.flat_map(&:players)).to include(players(:hana))
  end
end
