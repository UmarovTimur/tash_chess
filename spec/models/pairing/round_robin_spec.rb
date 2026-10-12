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

  describe "starting a round robin" do
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
end
