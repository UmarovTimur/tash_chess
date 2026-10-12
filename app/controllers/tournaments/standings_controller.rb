class Tournaments::StandingsController < Tournaments::BaseController
  def show
    @standings = @tournament.standings
  end
end
