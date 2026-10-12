class PlayersController < ApplicationController
  before_action :set_player, only: %i[ show edit update destroy ]

  def index
    @query = params[:query].to_s.strip
    @players = Player.alphabetical
    @players = @players.search(@query) if @query.present?
  end

  def show
    @tournaments = @player.tournaments.ordered
  end

  def new
    @player = Player.new
    @tournament = Tournament.find_by(id: params[:tournament_id])
  end

  def edit
  end

  def create
    @player = Player.new(player_params)
    @tournament = Tournament.find_by(id: params[:tournament_id])

    if @player.save
      if @tournament&.members_editable?
        @tournament.participations.create!(player: @player)
        redirect_to @tournament, notice: "#{@player.name} was added and joined the tournament."
      else
        redirect_to @player, notice: "#{@player.name} was added."
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @player.update(player_params)
      redirect_to @player, notice: "#{@player.name} was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @player.destroy
      redirect_to players_path, notice: "#{@player.name} was removed.", status: :see_other
    else
      redirect_to @player, alert: @player.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private
    def set_player
      @player = Player.find(params[:id])
    end

    def player_params
      params.expect(player: %i[ name nickname fide_rating ])
    end
end
