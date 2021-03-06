class TournamentsController < ApplicationController
  before_filter :find_tournament, :only => [:show, :edit, :update]
  # GET /tournaments
  # GET /tournaments.json
  def index
    @tournaments = Tournament.all.sort! {|a,b| a.starttime <=> b.starttime }
    @upcoming_tournaments = Tournament.upcoming
    @past_tournaments = Tournament.past
    @current_tournaments = Tournament.current
    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @tournaments }
    end
  end

  # GET /tournaments/1
  # GET /tournaments/1.json
  def show
    # countdown
    time_diff = (@tournament.starttime - Time.now)
    @hours = (time_diff / 3600).floor #to_i to catch nil cases
    partial_hour = (time_diff / 3600) - (time_diff / 3600).floor
    @minutes = (partial_hour * 60).floor
    partial_minute = (partial_hour * 60) - (partial_hour * 60).floor
    @seconds = (partial_minute * 60).round

    default_image = "https://cdn2.iconfinder.com/data/icons/huge-basic-vector-icons-part-3-3/512/awards_award_star_gold_medal-512.png"
    @image = (@tournament.asset.url if @tournament.asset.url != "/assets/original/missing.png") || @tournament.asset.url || default_image

    @registered_num = @tournament.judge_registrations.length + @tournament.competitors.length
    # sort rounds by first bracket start time
    # sort brackets chronologically
    for division in @tournament.divisions
      for round in division.rounds
        round.brackets.sort! {|a,b| a.starttime <=> b.starttime} unless round.brackets.all? {|b| b.starttime.nil? }
      end
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @tournament }
    end
  end

  # GET /tournaments/new
  # GET /tournaments/new.json
  def new
    @tournament = Tournament.new
    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @tournament }
    end
  end

  # GET /tournaments/1/edit
  def edit
  end

  # POST /tournaments
  # POST /tournaments.json
  def create
    @tournament = Tournament.new(params[:tournament])
    @tournament.organizer = current_user.as_organizer
    varsity = @tournament.divisions.build(:name => "Novice LD")
    novice = @tournament.divisions.build(:name => "Varsity LD")
    build_default_rounds(varsity)
    build_default_rounds(novice)
    adjust_for_time_zone

    # TODO: Eventually change division default names as we expand

    respond_to do |format|
      if @tournament.save
        format.html { redirect_to @tournament, notice: 'Tournament was successfully created by organizer ' + @tournament.organizer.user.name }
        format.json { render json: @tournament, status: :created, location: @tournament }
      else
        format.html { render action: "new" }
        format.json { render json: @tournament.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /tournaments/1
  # PUT /tournaments/1.json
  def update
    respond_to do |format|
      if @tournament.update_attributes(params[:tournament])
        adjust_for_time_zone
        brackets_adjust
        @tournament.save
        format.html { redirect_to @tournament, notice: 'Tournament was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "show" }
        format.json { render json: @tournament.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /tournaments/1
  # DELETE /tournaments/1.json
  def destroy
    @tournament = Tournament.find(params[:id])
    @tournament.destroy

    respond_to do |format|
      format.html { redirect_to tournaments_url }
      format.json { head :no_content }
    end
  end

  private
  def find_tournament
    @tournament = Tournament.find(params[:id])
  end

  def build_default_rounds(div)
    3.times do
      div.rounds.build(:kind => "Unpowered Prelim")
    end
    2.times do
      div.rounds.build(:kind => "Powered Prelim")
    end
    div.rounds.build(:kind => "Octofinals")
    div.rounds.build(:kind => "Quarterfinals")
    div.rounds.build(:kind => "Semifinals")
    div.rounds.build(:kind => "Finals")
  end

  def adjust_for_time_zone
    utc_diff = Time.now.in_time_zone(current_user.time_zone).utc_offset
    utc_start = @tournament.starttime
    utc_end = @tournament.endtime
    @tournament.starttime = utc_start - utc_diff
    @tournament.endtime = utc_end - utc_diff
  end

  def brackets_adjust
    for division in @tournament.divisions
      for round in division.rounds
            round.brackets.each do |bracket|
              bracket.get_UTC_starttime
              adjusted_starttime = bracket.starttime_adjusted_for_time_zone(current_user.time_zone)
              bracket.starttime = adjusted_starttime
            end
          end
    end
  end
end
