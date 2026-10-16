require "rails_helper"

RSpec.describe Pairing::RoundRobin do
  describe ".berger_schedule" do
    it "matches the FIDE Berger table for 6 players" do
      schedule = described_class.berger_schedule(6).map { |pairs| pairs.map { |white, black| "#{white + 1}-#{black + 1}" } }

      expect(schedule).to eq([
        %w[ 1-6 2-5 3-4 ], %w[ 6-4 5-3 1-2 ], %w[ 2-6 3-1 4-5 ], %w[ 6-5 1-4 2-3 ], %w[ 3-6 4-2 5-1 ]
      ])
    end

    [ 4, 8, 12, 16 ].each do |size|
      context "with #{size} players" do
        subject(:schedule) { described_class.berger_schedule(size) }

        it "pairs everybody with everybody exactly once" do
          pairs = schedule.flatten(1).map(&:sort)

          expect(pairs.size).to eq(size * (size - 1) / 2)
          expect(pairs).to eq(pairs.uniq)
          schedule.each { |round| expect(round.flatten.sort).to eq((0...size).to_a) }
        end

        it "balances colors and never gives a color three times in a row" do
          colors = Hash.new { |hash, key| hash[key] = [] }
          schedule.each { |round| round.each { |white, black| colors[white] << :w; colors[black] << :b } }

          colors.each_value do |sequence|
            expect((sequence.count(:w) - sequence.count(:b)).abs).to be <= 1
            expect(sequence.chunk_while { |a, b| a == b }.map(&:size).max).to be <= 2
          end
        end
      end
    end
  end

  describe ".schedule" do
    it "repeats the cycle with colors reversed when there are more rounds than one cycle" do
      cycle = described_class.berger_schedule(4)
      schedule = described_class.schedule(4, 7)

      expect(schedule.first(3)).to eq(cycle)
      expect(schedule[3, 3]).to eq(cycle.map { |pairs| pairs.map(&:reverse) })
      expect(schedule[6]).to eq(cycle.first)
    end
  end

  describe "starting a round robin" do
    it "plays as many rounds as set, here a double round robin" do
      tournament = create_tournament(system: :round_robin, rounds: 6, players: Player.by_rating.first(4))
      tournament.start

      expect(tournament.rounds.count).to eq(6)
      games = tournament.games.where.not(result: :bye).group_by { |game| [ game.white_player_id, game.black_player_id ].sort }
      expect(games.size).to eq(6)
      expect(games.values).to all(satisfy { |pair| pair.size == 2 && pair.map(&:white_player_id).uniq.size == 2 }),
        "every pair meets twice, once with each color"
    end

    it "pairs all rounds with board numbers" do
      tournament = create_tournament(system: :round_robin, rounds: nil, players: Player.all)

      expect(tournament.start).to be(true)
      expect(tournament.reload.rounds_count).to eq(7)
      expect(tournament.rounds.count).to eq(7)
      tournament.rounds.each do |round|
        expect(round.games.map(&:board)).to eq([ 1, 2, 3, 4 ])
        expect(round.games.flat_map(&:players).uniq.size).to eq(8)
      end
      expect(tournament.rounds.first.games.first.white_player).to eq(players(:anna)), "top seed starts on board 1"
    end

    it "lets one player rest each round when the count is odd" do
      tournament = create_tournament(system: :round_robin, rounds: nil, players: Player.by_rating.first(5))
      tournament.start

      expect(tournament.rounds.count).to eq(5)
      tournament.rounds.each do |round|
        byes = round.games.select(&:bye?)
        expect(byes.size).to eq(1)
        expect(byes.first.board).to eq(3), "the bye is listed after the two real boards"
      end
      expect(tournament.games.bye.map(&:white_player_id).uniq.size).to eq(5), "each player rests exactly once"
      expect(tournament.bye_points).to eq(0)
    end
  end

  describe "during the tournament" do
    let(:tournament) { create_tournament(system: :round_robin, rounds: nil, players: Player.by_rating.first(4)) }

    before do
      tournament.start
      play_round(tournament.rounds.first)
    end

    it "points the current round at the first round still waiting for results" do
      expect(tournament.current_round.number).to eq(2)
      expect(tournament.fixed_rounds_count).to eq(2)
    end

    it "includes a late entry in the rounds that haven't started" do
      round_two = tournament.rounds.second.games.map { |game| [ game.white_player_id, game.black_player_id ] }

      tournament.enroll([ players(:hana) ])
      tournament.update!(rounds_count: 6)

      expect(tournament.rounds.count).to eq(6)
      expect(tournament.rounds.first(2).map { |round| round.games.flat_map(&:players) }.flatten).not_to include(players(:hana))
      expect(tournament.rounds.second.games.map { |game| [ game.white_player_id, game.black_player_id ] }).to eq(round_two),
        "the round being played stays as it is"
      opponents = tournament.games.where.not(result: :bye).select { |game| game.players.include?(players(:hana)) }
      expect(opponents.flat_map(&:players).uniq).to contain_exactly(players(:hana), *Player.by_rating.first(4))
    end

    it "continues the Berger cycles when only the number of rounds changes" do
      planned = tournament.rounds.map { |round| round.games.map { |game| [ game.white_player_id, game.black_player_id ] } }

      tournament.update!(rounds_count: 6)

      rounds = tournament.rounds.reload.map { |round| round.games.map { |game| [ game.white_player_id, game.black_player_id ] } }
      expect(rounds.first(3)).to eq(planned)
      expect(rounds.drop(3)).to eq(planned.map { |pairs| pairs.map(&:reverse) })
    end

    it "lets a member without games in the started rounds leave" do
      tournament.enroll([ players(:hana) ])
      participation = tournament.participations.find_by!(player: players(:hana))

      expect(tournament.unenroll(participation)).to be(true)
      expect(tournament.games.reload.flat_map(&:players)).not_to include(players(:hana))
      expect(tournament.unenroll(tournament.participations.first)).to be(false), "members of the started rounds stay"
    end

    it "can't cut the rounds being played" do
      expect(tournament.update(rounds_count: 1)).to be(false)
      expect(tournament.errors).to be_of_kind(:rounds_count, :less_than_paired)
    end

    it "shows only started rounds in the standings" do
      cells = tournament.standings[players(:anna)].cells

      expect(cells.first.points).to be_present
      expect(cells.second.pending).to be(true)
      expect(cells.third).to be_nil
    end
  end
end
