class Tournaments::BaseController < ApplicationController
  before_action :set_tournament

  private
    def set_tournament
      @tournament = Tournament.find(params[:tournament_id])
    end
end
