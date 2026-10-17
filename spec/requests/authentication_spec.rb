require "rails_helper"

RSpec.describe "Authentication" do
  def login(name, password)
    { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(name, password) }
  end

  def stub_login(name, password)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("BASIC_AUTH_USERNAME").and_return(name)
    allow(ENV).to receive(:[]).with("BASIC_AUTH_PASSWORD").and_return(password)
  end

  context "with a login set" do
    before { stub_login("arbiter", "secret") }

    it "asks for it" do
      get root_path

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["WWW-Authenticate"]).to eq(%(Basic realm="Tash Chess"))
      expect(response.body).to eq("Нужны логин и пароль.")
    end

    it "refuses a wrong username or password" do
      get root_path, headers: login("arbiter", "wrong")
      expect(response).to have_http_status(:unauthorized)

      get root_path, headers: login("someone", "secret")
      expect(response).to have_http_status(:unauthorized)
    end

    it "lets the right login in" do
      get root_path, headers: login("arbiter", "secret")
      expect(response).to have_http_status(:success)

      post players_path, params: { player: { name: "Magnus Test", nickname: "magnus" } }, headers: login("arbiter", "secret")
      expect(response).to redirect_to(player_path(Player.find_by!(nickname: "magnus")))
    end

    it "explains in the chosen language" do
      cookies[:locale] = "en"
      get root_path

      expect(response.body).to eq("A username and password are required.")
    end

    it "keeps the health check open" do
      get rails_health_check_path
      expect(response).to have_http_status(:success)
    end
  end

  context "without a login set" do
    before { stub_login(nil, "") }

    it "stays open outside production" do
      get root_path
      expect(response).to have_http_status(:success)
    end

    it "refuses everyone in production" do
      allow(Rails.env).to receive(:production?).and_return(true)

      get root_path
      expect(response).to have_http_status(:unauthorized)

      get root_path, headers: login("", "")
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
