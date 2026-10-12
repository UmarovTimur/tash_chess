require "rails_helper"

RSpec.describe Tournament do
  let(:four_players) { Player.by_rating.first(4) }

  it "needs a number of rounds for Swiss but not for round robin" do
    expect(Tournament.new(name: "Swiss", pairing_system: :swiss)).not_to be_valid
    expect(Tournament.new(name: "RR", pairing_system: :round_robin)).to be_valid
  end

  describe "#start" do
    it "needs at least two members" do
      tournament = create_tournament(players: [ players(:anna) ])

      expect(tournament.start).to be(false)
      expect(tournament.reload).to be_registration
      expect(tournament.errors).to be_of_kind(:base, :not_enough_members)
    end

    it "refuses a Swiss with more rounds than possible opponents" do
      tournament = create_tournament(players: four_players, rounds: 4)

      expect(tournament.start).to be(false)
      expect(tournament.errors.where(:rounds_count, :too_many_rounds).first.options[:maximum]).to eq(3)
    end

    it "locks the pairing system" do
      tournament = create_tournament(players: four_players, rounds: 3)
      tournament.start

      expect(tournament.update(pairing_system: :round_robin)).to be(false)
    end

    it "keeps members with games from leaving" do
      tournament = create_tournament(players: four_players, rounds: 3)
      tournament.start

      expect(tournament.participations.first.destroy).to be(false)
    end
  end

  describe "#pair_next_round" do
    it "needs every result of the current round" do
      tournament = create_tournament(players: four_players, rounds: 3)
      tournament.start

      expect(tournament.pair_next_round).to be(false)
      play_round(tournament.current_round)
      expect(tournament.pair_next_round).to be(true)
      expect(tournament.rounds.count).to eq(2)
    end

    it "stops at the planned number of rounds, then the tournament can finish" do
      tournament = create_tournament(players: four_players, rounds: 1)
      tournament.start
      play_round(tournament.current_round)

      expect(tournament.can_pair_next_round?).to be(false)
      expect(tournament.finish).to be(true)
      expect(tournament.reload).to be_finished
    end
  end

  describe "#reset" do
    it "removes pairings only before any result" do
      tournament = create_tournament(players: four_players, rounds: 3)
      tournament.start
      game = tournament.current_round.games.first
      expect(tournament.can_reset?).to be(true)

      game.update!(result: :draw)
      expect(tournament.reset).to be(false)

      game.update!(result: :pending)
      expect(tournament.reset).to be_truthy
      expect(tournament.reload).to be_registration
      expect(tournament.rounds.count).to eq(0)
    end
  end

  describe "#remove_last_round" do
    it "returns to registration when the only round is deleted" do
      tournament = create_tournament(players: four_players, rounds: 3)
      tournament.start

      expect(tournament.remove_last_round).to be_truthy
      expect(tournament.reload).to be_registration
    end
  end

  describe "#destroy" do
    it "deletes a tournament with results but keeps the players" do
      tournament = create_tournament(players: four_players, rounds: 3)
      tournament.start
      play_round(tournament.current_round)

      expect { tournament.destroy! }
        .to change(Tournament, :count).by(-1)
        .and change(Game, :count).by(-2)
        .and change(Participation, :count).by(-4)
        .and(not_change(Player, :count))
    end
  end
end
