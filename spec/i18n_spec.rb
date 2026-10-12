require "rails_helper"

RSpec.describe "Translations" do
  plural_forms = %w[ zero one two few many other ]

  # Flattened key paths; a hash made only of plural forms counts as one key, since languages need different forms.
  flatten = lambda do |hash, prefix = nil|
    hash.flat_map do |key, value|
      path = [ prefix, key ].compact.join(".")
      value.is_a?(Hash) && (value.keys - plural_forms).any? ? flatten.(value, path) : [ path ]
    end
  end
  keys_in = ->(locale) { flatten.(YAML.load_file(Rails.root.join("config/locales/#{locale}.yml")).fetch(locale.to_s)).sort }

  it "use Russian by default, with English available" do
    expect(I18n.default_locale).to eq(:ru)
    expect(I18n.available_locales).to eq(%i[ ru en ])
  end

  it "define the same keys in Russian and English" do
    expect(keys_in.(:ru)).to eq(keys_in.(:en))
  end

  it "use Russian plural forms" do
    I18n.with_locale(:ru) do
      expect([ 1, 3, 5, 11, 21 ].map { |count| I18n.t("tournaments.summary.rounds", count:) })
        .to eq([ "1 тур", "3 тура", "5 туров", "11 туров", "21 тур" ])
    end
  end

  it "translate validation errors" do
    tournament = create_tournament(players: [ players(:anna) ])
    tournament.start

    I18n.with_locale(:ru) do
      expect(tournament.errors.full_messages).to eq([ "Чтобы начать турнир, нужно минимум 2 участника" ])
    end
    I18n.with_locale(:en) do
      expect(tournament.errors.full_messages).to eq([ "At least 2 members are needed to start the tournament" ])
    end
  end
end
