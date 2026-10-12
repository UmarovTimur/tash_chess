ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    def create_tournament(system: :swiss, rounds: 5, players: Player.all)
      Tournament.create!(name: "Test open", pairing_system: system, rounds_count: rounds, players: players.to_a)
    end

    def create_players(count)
      Array.new(count) { |i| Player.create!(name: "Player #{i + 1}", nickname: "p#{i + 1}", fide_rating: 2400 - i * 25) }
    end

    # Enters results for every pending game of the round; the block picks the result (higher-rated wins by default).
    def play_round(round)
      round.games.reload.each do |game|
        next if game.bye?

        result = block_given? ? yield(game) : (game.white_player.fide_rating.to_i >= game.black_player.fide_rating.to_i ? :white_won : :black_won)
        game.update!(result:)
      end
    end
  end
end
