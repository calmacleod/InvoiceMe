require "test_helper"

class HorizonGameSyncIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
    @season = seasons(:current)
    @connection = HorizonConnection.create!(authorization_code: "fictional-code")
  end

  test "a sync can be queued, reviewed, and discarded without fetching during page views" do
    assert_enqueued_with(job: HorizonGameSyncJob) do
      post horizon_game_syncs_path, params: { horizon_connection_id: @connection.id, season_id: @season.id }
    end
    sync = HorizonGameSync.last
    assert_redirected_to horizon_game_sync_path(sync)
    get horizon_game_sync_path(sync)
    assert_response :success
    assert_inertia_component "games/HorizonSync"
    sync.update!(status: "ready", completed_at: Time.current)
    delete horizon_game_sync_path(sync)
    assert_equal "discarded", sync.reload.status
  end

  test "a user cannot view or apply another user's sync" do
    sync = HorizonGameSync.create!(season: @season, user: users(:two), horizon_connection: @connection, status: "ready", completed_at: Time.current)
    get horizon_game_sync_path(sync)
    assert_response :not_found
    post apply_horizon_game_sync_path(sync)
    assert_response :not_found
  end
end
