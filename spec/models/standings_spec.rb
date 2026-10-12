require "rails_helper"

RSpec.describe Standings do
  context "in a round robin" do
    let(:tournament) do
      create_tournament(system: :round_robin, rounds: nil, players: [ players(:anna), players(:boris), players(:chen), players(:daria) ])
    end

    before { tournament.start }

    def play_all(&)
      tournament.rounds.each { |round| play_round(round, &) }
    end

    it "counts points, wins, draws and losses" do
      play_all do |game|
        if game.players.include?(players(:anna))
          game.white_player == players(:anna) ? :white_won : :black_won
        else
          :draw
        end
      end

      row = tournament.standings[players(:anna)]
      expect(row.points).to eq(3.0)
      expect([ row.wins, row.draws, row.losses ]).to eq([ 3, 0, 0 ])
      expect(row.rank).to eq(1)

      others = tournament.standings.rows.drop(1)
      expect(others).to all(have_attributes(points: 1.0, rank: 2)), "equal players share the rank"
    end

    it "breaks ties with Sonneborn-Berger" do
      winners = {
        %w[ anna_k boris ] => nil, %w[ anna_k chenwei ] => "anna_k", %w[ anna_k daria ] => "anna_k",
        %w[ boris chenwei ] => "boris", %w[ boris daria ] => "daria", %w[ chenwei daria ] => "chenwei"
      }
      play_all do |game|
        winner = winners.fetch(game.players.map(&:nickname).sort)
        winner.nil? ? :draw : (game.white_player.nickname == winner ? :white_won : :black_won)
      end

      rows = tournament.standings.rows
      expect(rows.map { |row| row.player.nickname }).to eq(%w[ anna_k boris daria chenwei ])
      expect(rows.map(&:points)).to eq([ 2.5, 1.5, 1.0, 1.0 ])
      expect(rows.map(&:sonneborn_berger)).to eq([ 2.75, 2.25, 1.5, 1.0 ]), "Daria beat Boris (1.5), Chen beat Daria (1.0)"
      expect(rows.map(&:rank)).to eq([ 1, 2, 3, 4 ])
    end

    it "shows pending games in round cells without points" do
      row = tournament.standings[players(:anna)]

      expect(row.points).to eq(0.0)
      expect(row.cells.first.pending).to be(true)
      expect(row.games_played).to eq(0)
    end
  end

  context "in a Swiss" do
    it "scores a bye as one point" do
      swiss = create_tournament(players: [ players(:anna), players(:boris), players(:chen) ], rounds: 2)
      swiss.start
      play_round(swiss.current_round)

      bye_row = swiss.standings[players(:chen)]
      expect(bye_row.points).to eq(1.0)
      expect(bye_row.cells.first).to be_bye
      expect(bye_row.byes).to eq(1)
    end
  end
end
