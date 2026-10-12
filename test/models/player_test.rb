require "test_helper"

class PlayerTest < ActiveSupport::TestCase
  test "valid without a FIDE rating" do
    assert Player.new(name: "New Player", nickname: "newbie").valid?
  end

  test "requires name and nickname" do
    player = Player.new
    assert_not player.valid?
    assert_includes player.errors[:name], "can't be blank"
    assert_includes player.errors[:nickname], "can't be blank"
  end

  test "nickname is unique regardless of case and whitespace" do
    player = Player.new(name: "Copycat", nickname: "  ANNA_K ")
    assert_not player.valid?
    assert_includes player.errors[:nickname], "has already been taken"
  end

  test "database rejects duplicate nicknames too" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      Player.new(name: "Copycat", nickname: "Boris").save!(validate: false)
    end
  end

  test "nickname must not contain spaces" do
    player = Player.new(name: "Spacey", nickname: "two words")
    assert_not player.valid?
    assert player.errors[:nickname].any?
  end

  test "FIDE rating must be within a realistic range" do
    assert_not Player.new(name: "Low", nickname: "low", fide_rating: 400).valid?
    assert_not Player.new(name: "High", nickname: "high", fide_rating: 3500).valid?
    assert Player.new(name: "Okay", nickname: "okay", fide_rating: 1400).valid?
  end

  test "search matches name or nickname case-insensitively" do
    assert_equal [ players(:anna) ], Player.search("KOWAL").to_a
    assert_equal [ players(:chen) ], Player.search("chenw").to_a
  end

  test "can be deleted when only registered in a tournament" do
    tournament = create_tournament(players: [ players(:anna), players(:boris) ])

    assert_difference -> { Player.count } => -1, -> { tournament.participations.count } => -1 do
      assert players(:anna).destroy
    end
  end

  test "can't be deleted after playing games" do
    tournament = create_tournament(players: [ players(:anna), players(:boris) ], rounds: 1)
    assert tournament.start

    assert_no_difference -> { Player.count } do
      assert_not players(:anna).destroy
    end
    assert_match "already played", players(:anna).errors.full_messages.to_sentence
  end
end
